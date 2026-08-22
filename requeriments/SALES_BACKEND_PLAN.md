# Sales backend plan

## Observed Retaily flow

1. Cashier selects products from one store, quantities, per-line discount, customer, delivery, payment status (`CASH` or `CREDIT`), sale type (`IN_SHOP` or `FOR_DELIVER`), and sequence type (`CF`, `VF`, or `DV`).
2. The client calculates total, tax, discount, and delivery, then submits the full transaction.
3. Legacy backend increments the sequence, inserts `sale` and `sale_line` records, subtracts store inventory, and inserts payments unless it is credit.
4. A sale is `open` when paid total is below amount, `close` when it is fully paid, and `cancelled` when `status = RETURN`; cancelling restores sold quantities.

## Implementation steps

1. Add tenant-protected `/api/sales` routes behind the existing `:tenant_api` pipeline. Obtain the schema only with `TenantContext.tenant!/0`; never accept a tenant from request data.
2. Add a `Sales` context, request changesets, and PostgreSQL queries for: create sale, list/filter sales, add payment, and cancel sale. Use `Decimal` for all money and validate non-empty lines, positive quantities/payments, allowed statuses/types, and non-negative delivery/discount.
3. In `create_sale`, use one `Repo.transaction` with the tenant prefix: lock/update the requested sequence, insert the sale header and immutable line snapshots, atomically decrement each `(product_id, store_id)` inventory row only when enough quantity exists, then insert payments. Derive all header totals from accepted lines on the server; do not trust client totals, price, tax, login, or store.
4. Resolve the cashier from `current_scope`; verify the selected store belongs to that cashier. Load products, customer, sequence, and inventory from the same tenant schema. Return the created sale, lines, payments, calculated balance/status, and issued sequence.
5. In `add_payment`, lock the sale, reject cancelled sales and payments that exceed its outstanding balance, insert the payment, and return the recalculated balance/status. In `cancel_sale`, lock the sale and its lines, make cancellation idempotent, restore inventory once, and mark it returned in the same transaction.
6. Add list/detail queries scoped to the tenant and store authorization, with date range, customer, cashier, and invoice-status filters. Calculate `total_paid`, `due_balance`, and invoice status in PostgreSQL; preload lines, product display data, customer, and payments without N+1 queries.
7. Add the minimal migration safeguards: foreign keys from sale lines/payments to sale and lines to product, unique inventory `(product_id, store_id)`, indexes for `sale_paid.sale_id` and `sale_line.sale_id`, and a unique sequence rule appropriate to the business (at least `(sequence_type, sequence)`).

## Data-backed tests

Use dedicated Triplex test schemas and seed only the referenced Retaily rows. Every stock-changing test records inventory before checkout and verifies the expected quantity after checkout/cancellation.

1. **Paid discounted delivery sale (`363886`):** store `2`, customer `30218` (SCOLNY REYES), cashier `walex`, product `19463`, quantity `1`, unit `3200`, discount `110`, delivery `200`, and `CASH 3290`. Assert one header/line/payment, closed balance, and inventory decreases by `1`.
2. **Credit/open sale (`363873`):** customer `26623`, product `19203`, quantity `1`, unit `240`, discount `40`, no initial payment. Assert the open balance and inventory decrease; add `CASH 200` and assert closure without a further stock change.
3. **Multiple lines (`363885`):** customer `24181`, lines `(8679, 1, 1800, 200, 1600)` and `(19383, 1, 230, 0, 230)`, with `CASH 1830`. Assert server-derived amount/discount, one closed sale, and each product inventory decreases by `1`.
4. **Cancellation/restock:** cancel the delivery sale, assert `RETURN`/cancelled state and restoration of its pre-sale inventory; repeat cancellation and assert stock, lines, and payments are unchanged.
5. **Insufficient stock and rollback:** request `19463` quantity `13` when the seed quantity is `12`; assert no sequence, sale, line, payment, or inventory change. Also reject `19385`, seeded at `-144`.
6. **Tenant and store isolation:** no bearer scope returns `401`; a second tenant cannot see seeded sales; a cashier without store `2` cannot create or list its sales.
7. **Simple paid checkout:** cashier `walex` sells product `19383` to customer `30218` for `CASH 230`; assert the closed invoice, payment, line, and one-unit inventory decrease.
8. **Ten-product, multi-day credit collection:** create a credit sale for customer `30218` with ten real `educa` store-2 products, quantities `5` through `14`. Record inventory before/after each line, then settle `25155` through `CASH 10000`, `CC 8000`, and `CASH 7155`; assign three test-database payment dates and assert the final invoice is closed.
9. **July 2026 cancellation fixture (`363261`):** recreate the July 31 `VEN00000024473` pattern for customer `30190`: products `19509`, `19378`, `8694`, and `19553`, original discounts, delivery `300`, and payment `4200`. Assert every inventory decrease before cancellation and restoration after cancellation.

## Focused improvement proposal

Replace the legacy per-row commits and client-trusted totals with a single tenant-scoped PostgreSQL transaction using row locks and `Decimal`. This prevents partial sales, duplicate sequence use, overselling under concurrent checkouts, cross-store access, and cancellation restocks happening more than once.
