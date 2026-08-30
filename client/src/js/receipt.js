// Receipt data is deliberately assembled from the persisted invoice response.
// Rendering and transport remain separate: the native ESC/POS adapter receives
// this complete, database-free payload.
const value = (input) => Number(input || 0);

// Sale totals are authoritative. Older sale lines do not retain their own
// tax amount, so distribute the persisted invoice tax only for display. The
// final line receives the rounding remainder, ensuring printed line tax adds
// up exactly to the invoice tax rather than creating a second total.
function lineTaxes(lines, invoiceTax) {
  const storedTax = lines.reduce((sum, line) => sum + value(line.tax_amount), 0);
  const missing = lines.filter((line) => value(line.tax_amount) <= 0);
  const total = missing.reduce((sum, line) => sum + value(line.total_amount), 0);
  const remainingTax = Math.max(invoiceTax - storedTax, 0);
  let allocated = 0;
  return lines.map((line, index) => {
    const stored = value(line.tax_amount);
    if (stored > 0) return stored;
    if (!remainingTax || !total) return 0;
    const isLastMissing = line === missing[missing.length - 1];
    const tax = isLastMissing
      ? Number((remainingTax - allocated).toFixed(2))
      : Number((remainingTax * value(line.total_amount) / total).toFixed(2));
    allocated += tax;
    return tax;
  });
}

function dateTime(input) {
  if (!input) return "";
  const date = new Date(String(input).replace(" ", "T"));
  if (Number.isNaN(date.getTime())) return "";
  const datePart = new Intl.DateTimeFormat("en-GB", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  }).format(date);
  const timePart = new Intl.DateTimeFormat("en-US", {
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  }).format(date);
  return `${datePart} ${timePart}`;
}

export function buildReceiptData(invoice, { company, store, sequences = [], language, t, copy = false } = {}) {
  const sequence = sequences.find((entry) => entry.code === invoice.sequence_type);
  const labels = {
    receipt: t("receipt.receipt"),
    copy: t("receipt.copy"),
    invoice: t("ui.invoice"),
    fiscal_sequence: t("receipt.fiscalSequence"),
    rnc: t("receipt.rnc"),
    date: t("ui.date"),
    store: t("ui.store"),
    customer: t("ui.customer"),
    document: t("receipt.document"),
    cashier: t("ui.salesPerson"),
    sku: t("receipt.sku"),
    quantity: t("receipt.quantity"),
    unit_price: t("invoice.unitPrice"),
    discount: t("total.discount"),
    tax: t("receipt.tax"),
    subtotal: t("total.subtotal"),
    delivery: t("checkout.delivery"),
    total: t("ui.total"),
    paid: t("ui.paid"),
    balance: t("ui.pendingBalance"),
    change: t("checkout.change"),
    memo: t("receipt.memo"),
    thank_you: t("receipt.thankYou"),
    item_header: t("receipt.itemHeader"),
    savings: t("receipt.savings"),
    items: t("total.items"),
    cash: t("checkout.cash"),
    card: t("checkout.card"),
    credit: t("checkout.credit"),
  };
  const payments = (invoice.payments || []).map((payment) => ({
    method:
      payment.type === "CC"
        ? labels.card
        : payment.type === "CASH"
          ? labels.cash
          : payment.type,
    amount: value(payment.amount),
  }));
  const totalDiscount = value(invoice.discount);
  const lineDiscount = (invoice.lines || []).reduce((sum, line) => sum + value(line.discount), 0);
  const globalDiscount = value(invoice.global_discount ?? Math.max(totalDiscount - lineDiscount, 0));
  const lines = invoice.lines || [];
  const taxes = lineTaxes(lines, value(invoice.tax_amount));
  return {
    number: invoice.sequence || String(invoice.id),
    sequence_description: sequence?.name || "",
    language,
    copy,
    labels,
    company: company?.name || "",
    company_id: company?.rnc || "",
    store: store?.name || "",
    store_address: store?.address || "",
    store_slogan: store?.slogan || "",
    date_time: dateTime(invoice.date_create),
    customer: invoice.client?.name || "",
    customer_document: invoice.client?.document_id || "",
    cashier: invoice.salesperson?.name || invoice.login || "",
    memo: invoice.additional_info || "",
    items: lines.map((line, index) => ({
      name: line.product?.name || "",
      sku: line.product?.code || "",
      qty: value(line.quantity),
      price: value(line.amount),
      discount: value(line.discount),
      tax: taxes[index],
      total: value(line.total_amount),
    })),
    subtotal: value(invoice.sub),
    tax: value(invoice.tax_amount),
    discount: globalDiscount,
    line_discount: lineDiscount,
    discount_total: totalDiscount,
    delivery: value(invoice.delivery_charge),
    total: value(invoice.amount),
    payments,
    paid: value(invoice.total_paid),
    balance: Math.max(value(invoice.due_balance), 0),
    change: value(invoice.change_amount),
  };
}
