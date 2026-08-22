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

Load `data/retaily_db_data.sql` into a dedicated test tenant/schema (or extract its referenced rows), then cover:

1. **Paid discounted delivery sale:** create the equivalent of sale `363886`: store `2`, customer `30218` (SCOLNY REYES), cashier `walex`, `DV`, `CASH`, `FOR_DELIVER`, product `19463`, quantity `1`, unit `3200`, discount `110`, line total `3090`, delivery `200`, amount `3290`, and cash payment `3290`. Assert one header/line/payment, balance `0`, closed status, and inventory for `(19463, 2)` changes from `12` to `11`.
2. **Credit/open sale:** reproduce sale `363873`: store `2`, customer `26623`, product `19203`, quantity `1`, unit `240`, discount `40`, line total/amount `200`, status `CREDIT`, and no initial payment. Assert open balance `200`, no payment rows, and inventory `(19203, 2)` changes from `265` to `264`; then add a `CASH` payment of `200` and assert closed balance `0`.
3. **Multiple lines and discount total:** reproduce sale `363885`: store `2`, customer `24181`, lines `(8679, 1, 1800, 200, 1600)` and `(19383, 1, 230, 0, 230)`, amount `1830`, discount `200`, payment `CASH 1830`. Assert server-derived line/header totals and one closed sale.
4. **Cancellation/restock:** cancel the newly created sale from test 1, assert its cancelled/returned status and that `(19463, 2)` returns to `12`; repeat the request and assert neither stock nor payments/lines change again.
5. **Insufficient stock and rollback:** request product `19463` at store `2` with quantity `13` (seed quantity is `12`). Assert validation failure and no sequence increment, sale, line, payment, or inventory change. Also reject product `19385` at store `2`, whose seeded quantity is `-144`.
6. **Tenant and store isolation:** call the routes without a bearer tenant scope and expect `401`; under a second tenant, assert the Retaily IDs above are invisible. Within the seeded tenant, a cashier not assigned to store `2` must not create, list, pay, or cancel its sales.

## Focused improvement proposal

Replace the legacy per-row commits and client-trusted totals with a single tenant-scoped PostgreSQL transaction using row locks and `Decimal`. This prevents partial sales, duplicate sequence use, overselling under concurrent checkouts, cross-store access, and cancellation restocks happening more than once.
