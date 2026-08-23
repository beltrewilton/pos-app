import * as printer from "./printer.js";
import { API_BASE_URL, activeProducts, addSalePayment, adjustInventory, cancelSale, createCustomer, createProductOrder, createSale, customers, inventoryQuantities, inventorySummary, productOrders, receiveProductOrder, saleDetails, salesReport } from "./api.js";
import { createPos } from "./pos.js";
import { onLanguageChange, t, translateDocument } from "./i18n.js";
import { createLanguageSwitcher } from "./language-switcher.js";

const printerStatus = document.querySelector("#printer-status");
const printButton = document.querySelector("#print-test");
const printStatus = document.querySelector("#print-status");
const checkoutFlow = document.querySelector("#checkout-flow");
const checkoutStatus = document.querySelector("#checkout-status");
const catalogPanel = document.querySelector(".catalog-panel");
const appShell = document.querySelector("#app-shell");
const startCheckoutButton = document.querySelector("#start-checkout");
const productGrid = document.querySelector("#product-grid");
const productStatus = document.querySelector("#products-status");
const productSearch = document.querySelector("#product-search");
const productSentinel = document.querySelector("#products-sentinel");
const customersScreen = document.querySelector("#customers-screen");
const customersTableBody = document.querySelector("#customers-table-body");
const customersStatus = document.querySelector("#customers-status");
const customerSearch = document.querySelector("#customer-search");
const customerDialog = document.querySelector("#customer-dialog");
const customerForm = document.querySelector("#customer-form");
const customerFormStatus = document.querySelector("#customer-form-status");
const invoiceReport = document.querySelector("#invoice-report");
const invoiceReportFixed = document.querySelector(".invoice-report-fixed");
const invoiceTableBody = document.querySelector("#invoice-table-body");
const invoiceReportStatus = document.querySelector("#invoice-report-status");
const invoiceSearch = document.querySelector("#invoice-search");
const invoiceSentinel = document.querySelector("#invoice-sentinel");
const invoiceFilters = document.querySelector("#invoice-filters");
const invoiceDateFrom = document.querySelector("#invoice-date-from");
const invoiceDateTo = document.querySelector("#invoice-date-to");
const invoiceDateRangeTrigger = document.querySelector("#invoice-date-range-trigger");
const invoiceDateRangeDialog = document.querySelector("#invoice-date-range-dialog");
const invoiceCalendarGrid = document.querySelector("#invoice-calendar-grid");
const invoiceCancelDialog = document.querySelector("#invoice-cancel-dialog");
const orderTitle = document.querySelector("#order-title");
const clearCustomerButton = document.querySelector("#clear-customer");
const languageSwitcher = createLanguageSwitcher(document.querySelector("#language-switcher"));
const storeId = 2;
const pos = createPos({
  cartElement: document.querySelector("#cart"),
  totalTrigger: document.querySelector("#grand-total"),
  totalElement: document.querySelector("#total"),
  totalBeforeDiscountElement: document.querySelector("#total-before-discount"),
  subtotalElement: document.querySelector("#subtotal"),
  discountElement: document.querySelector("#discount"),
  taxElement: document.querySelector("#tax"),
  itemCountElement: document.querySelector("#items-count"),
  emptyElement: document.querySelector("#cart-empty"),
  clearButton: document.querySelector("#clear-order"),
  chargeButton: document.querySelector("#print-test"),
  checkoutButton: startCheckoutButton,
  productGrid,
  discountDialog: document.querySelector("#discount-dialog"),
  discountForm: document.querySelector("#discount-form"),
  discountTypeButtons: document.querySelectorAll("[data-discount-type]"),
  discountInput: document.querySelector("#discount-input"),
  discountInputLabel: document.querySelector("#discount-input-label"),
  discountHelp: document.querySelector("#discount-help"),
  discountProductImage: document.querySelector("#discount-product-image"),
  discountProductName: document.querySelector("#discount-product-name"),
  discountPreviewAmount: document.querySelector("#discount-preview-amount"),
  discountPreviewDiscount: document.querySelector("#discount-preview-discount"),
  discountPreviewTotal: document.querySelector("#discount-preview-total"),
  clearDialog: document.querySelector("#clear-order-dialog"),
  clearConfirmButton: document.querySelector("#confirm-clear-order"),
  t,
});

let cursor = null;
let hasMore = true;
let loading = false;
let products = [];
let checkoutStage = "customer";
let selectedCustomer = null;
let customerSearchTimer;
let completedReceipt = null;
let invoiceCursor = null;
let invoiceHasMore = true;
let invoiceLoading = false;
let invoices = [];
let invoiceSearchTimer;
let invoicePendingCancellation = null;
let calendarMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
let calendarRange = { from: "", to: "" };
let invoiceStatusFilter = "";
let expandedInvoiceId = null;
const invoiceDetails = new Map();
let invoiceSort = { key: "sequence", direction: "desc" };
const inventoryScreen = document.querySelector("#inventory-screen");
const ordersScreen = document.querySelector("#orders-screen");
const purchaseOrderScreen = document.querySelector("#purchase-order-screen");
const inventoryTableBody = document.querySelector("#inventory-table-body");
const ordersTableBody = document.querySelector("#orders-table-body");
const inventorySearchInput = document.querySelector("#inventory-search");
const inventoryStatus = document.querySelector("#inventory-status");
const inventorySummaryGrid = document.querySelector("#inventory-summary");
const ordersStatus = document.querySelector("#orders-status");
let inventoryEntries = [], purchaseOrders = [], selectedOrder = null;
let editingInventoryProductId = null;
let inventorySort = { key: "last_update", direction: "desc" };
let inventoryFilter = "";
let purchaseOrderSort = { key: "last_updated", direction: "desc" };

function updateInvoiceStickyOffset() {
  invoiceReport.style.setProperty("--invoice-fixed-height", `${invoiceReportFixed.offsetHeight}px`);
}

new ResizeObserver(updateInvoiceStickyOffset).observe(invoiceReportFixed);
document.querySelectorAll(".operations-fixed").forEach((fixed) => new ResizeObserver(() => fixed.closest(".operations-screen").style.setProperty("--operations-fixed-height", `${fixed.offsetHeight}px`)).observe(fixed));

function updateCustomerPicker() {
  orderTitle.textContent = selectedCustomer?.name || t("customer.pick");
  orderTitle.title = selectedCustomer?.name || "";
  orderTitle.setAttribute("aria-label", selectedCustomer ? t("customer.change") : t("customer.pick"));
  clearCustomerButton.hidden = !selectedCustomer;
}

// A completed sale starts a completely new order. Keep this in one place so no
// customer, payment, delivery, or invoice choice leaks into the next sale.
function resetCompletedOrder() {
  selectedCustomer = null;
  updateCustomerPicker();

  const choice = document.querySelector("#customer-picker");
  const details = document.querySelector("#customer-details");
  choice.textContent = t("customer.pick");
  details.hidden = true;
  details.textContent = "";
  document.querySelector("#customer-continue").disabled = true;

  const creditToggle = document.querySelector("#credit-toggle");
  creditToggle.setAttribute("aria-pressed", "false");
  creditToggle.dataset.variant = "outline";
  creditToggle.disabled = true;
  document.querySelector("#payment-inputs").hidden = false;
  document.querySelector("#payment-lines").replaceChildren();
  document.querySelector("#payment-balance").textContent = "";
  document.querySelector("#payment-change").hidden = true;
  document.querySelector("#payment-change").textContent = "";
  document.querySelector("#payment-choice").textContent = "—";

  const deliveryToggle = document.querySelector("#delivery-toggle");
  deliveryToggle.setAttribute("aria-pressed", "false");
  deliveryToggle.dataset.variant = "outline";
  document.querySelector("#delivery-options").hidden = true;
  document.querySelector("#delivery-options").replaceChildren();
  document.querySelector("#delivery-summary").hidden = true;
  document.querySelectorAll("[data-sequence]").forEach((button) => {
    button.dataset.variant = button.dataset.sequence === "CF" ? "default" : "secondary";
  });

  checkoutStatus.textContent = "";
  pos.clear();
}

function customerRow(customer) {
  const row = document.createElement("tr");
  row.className = "table-row";
  const values = [customer.name || "—", customer.celphone || "—", customer.email || "—"];
  values.forEach((value) => { const cell = document.createElement("td"); cell.className = "table-cell"; cell.textContent = value; row.appendChild(cell); });
  const action = document.createElement("td"); action.className = "table-cell customer-action";
  const choose = document.createElement("button"); choose.className = "btn"; choose.type = "button"; choose.dataset.variant = "outline"; choose.dataset.size = "sm"; choose.dataset.customerId = customer.id; choose.textContent = t("customer.choose"); choose.setAttribute("aria-label", `${t("customer.choose")}: ${customer.name || ""}`); action.appendChild(choose); row.appendChild(action);
  return row;
}

async function loadCustomers() {
  customersStatus.textContent = t("customer.loading");
  customersTableBody.replaceChildren();
  try {
    const page = await customers(customerSearch.value.trim());
    customersTableBody.replaceChildren(...page.entries.map(customerRow));
    if (!page.entries.length) customersStatus.textContent = t("customer.empty");
    else customersStatus.textContent = "";
    customersTableBody.querySelectorAll("[data-customer-id]").forEach((button) => {
      button.addEventListener("click", () => selectCustomer(page.entries.find((customer) => String(customer.id) === button.dataset.customerId)));
    });
  } catch (error) {
    console.error(error); customersStatus.textContent = t("customer.error");
  }
}

let customerReturn = "pos";
function openCustomers(returnTo = "pos") {
  customerReturn = returnTo;
  catalogPanel.dataset.view = "customers";
  customersScreen.hidden = false;
  loadCustomers();
  requestAnimationFrame(() => document.querySelector("#customers-title").focus());
}

function closeCustomers() {
  customersScreen.hidden = true;
  if (catalogPanel.dataset.view === "customers") delete catalogPanel.dataset.view;
  if (customerReturn === "checkout") { catalogPanel.dataset.view = "checkout"; checkoutFlow.hidden = false; showCheckoutStage("customer"); }
  else orderTitle.focus();
}

function currency(value) {
  return `$${Number(value || 0).toFixed(2)}`;
}

function dateValue(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function rangeLabel(from, to) {
  if (!from) return "Any date";
  const format = (value) => new Date(`${value}T00:00:00`).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
  return to ? `${format(from)} – ${format(to)}` : format(from);
}

function renderCalendar() {
  document.querySelector("#calendar-month-label").textContent = calendarMonth.toLocaleDateString(undefined, { month: "long", year: "numeric" });
  document.querySelector("#invoice-date-range-description").textContent = calendarRange.from && !calendarRange.to ? "Choose an end date to complete the range." : "Choose a start date, then an end date.";
  invoiceCalendarGrid.replaceChildren();
  const firstWeekday = calendarMonth.getDay();
  const daysInMonth = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + 1, 0).getDate();
  for (let blank = 0; blank < firstWeekday; blank += 1) invoiceCalendarGrid.appendChild(document.createElement("span"));
  for (let day = 1; day <= daysInMonth; day += 1) {
    const date = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth(), day);
    const value = dateValue(date);
    const button = document.createElement("button");
    button.className = "btn calendar-day";
    button.type = "button";
    button.dataset.date = value;
    button.dataset.variant = "ghost";
    button.dataset.size = "icon-sm";
    button.setAttribute("role", "gridcell");
    button.setAttribute("aria-label", date.toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric", year: "numeric" }));
    button.setAttribute("aria-selected", String(value === calendarRange.from || value === calendarRange.to));
    if (calendarRange.from && calendarRange.to && value > calendarRange.from && value < calendarRange.to) button.dataset.range = "middle";
    if (value === dateValue(new Date())) button.dataset.today = "";
    button.textContent = day;
    invoiceCalendarGrid.appendChild(button);
  }
}

function openDateRangePicker() {
  calendarRange = { from: invoiceDateFrom.value, to: invoiceDateTo.value };
  const initial = calendarRange.from ? new Date(`${calendarRange.from}T00:00:00`) : new Date();
  calendarMonth = new Date(initial.getFullYear(), initial.getMonth(), 1);
  renderCalendar();
  invoiceDateRangeDialog.showModal();
}

function invoiceStatusLabel(status) {
  return status === "close" ? "Paid" : status === "cancelled" ? "Cancelled" : "Pending";
}

function updateInvoiceSummary(summary) {
  if (!summary) return;

  [["paid", "paid"], ["pending", "pending"], ["cancelled", "cancelled"]].forEach(([name, key]) => {
    document.querySelector(`#invoice-${name}-count`).textContent = Number(summary[`${key}_count`] || 0);
    document.querySelector(`#invoice-${name}-total`).textContent = currency(summary[`${key}_total`]);
  });
}

function invoicePaymentForm(invoice) {
  const payment = document.createElement("form");
  payment.className = "invoice-payment";
  payment.dataset.invoiceId = invoice.id;
  const createMethodSelector = (row, label) => {
    const methods = document.createElement("div");
    methods.className = "invoice-payment-methods sequence-options";
    methods.setAttribute("role", "group");
    methods.setAttribute("aria-label", label);
    row.dataset.paymentType = "CASH";
    [["CASH", "Cash"], ["CC", "Credit Card"]].forEach(([type, labelText]) => {
      const method = document.createElement("button");
      method.className = "btn"; method.type = "button"; method.dataset.paymentType = type;
      method.dataset.variant = type === "CASH" ? "default" : "secondary";
      method.setAttribute("aria-pressed", String(type === "CASH"));
      method.textContent = labelText;
      methods.appendChild(method);
    });
    return methods;
  };
  const createAmount = ({ id, value, readonly = false, label }) => {
    const amountWrap = document.createElement("div");
    amountWrap.className = "invoice-payment-amount";
    const amountLabel = document.createElement("label");
    amountLabel.className = "label sr-only";
    amountLabel.htmlFor = id;
    amountLabel.textContent = label;
    const amount = document.createElement("input");
    amount.className = "input numeric";
    amount.id = id;
    amount.value = value;
    if (readonly) {
      amount.type = "text";
      amount.readOnly = true;
      amount.setAttribute("aria-label", label);
    } else {
      amount.type = "number"; amount.min = "0.01"; amount.max = invoice.due_balance; amount.step = "0.01"; amount.required = true;
      amount.name = "paymentAmount";
    }
    amountWrap.append(amountLabel, amount);
    return amountWrap;
  };
  const primary = document.createElement("div");
  primary.className = "invoice-payment-row";
  primary.append(
    createAmount({ id: `invoice-payment-${invoice.id}`, value: "0", label: `Payment amount for ${invoice.sequence || invoice.id}` }),
    createMethodSelector(primary, "Payment method"),
  );
  const pay = document.createElement("button");
  pay.className = "btn"; pay.type = "submit"; pay.dataset.variant = "outline"; pay.textContent = "Pay";
  primary.appendChild(pay);
  const payoff = document.createElement("div");
  payoff.className = "invoice-payment-row invoice-payment-payoff";
  payoff.append(
    createAmount({ id: `invoice-payoff-${invoice.id}`, value: Number(invoice.due_balance).toFixed(2), readonly: true, label: `Outstanding balance for ${invoice.sequence || invoice.id}` }),
    createMethodSelector(payoff, "Payoff payment method"),
  );
  const payOff = document.createElement("button");
  payOff.className = "btn"; payOff.type = "submit"; payOff.formNoValidate = true; payOff.dataset.variant = "default"; payOff.textContent = "Pay off";
  payoff.appendChild(payOff);
  payment.append(primary, payoff);
  return payment;
}

function invoiceRow(invoice) {
  const row = document.createElement("tr");
  row.className = "table-row invoice-row";
  [invoice.sequence || `#${invoice.id}`, invoice.client_name || "Walk-in customer"].forEach((value, index) => {
    const cell = document.createElement("td");
    cell.className = "table-cell";
    const trigger = document.createElement("button");
    trigger.className = "btn invoice-detail-trigger";
    trigger.type = "button";
    trigger.dataset.variant = "ghost";
    trigger.dataset.invoiceDetail = invoice.id;
    trigger.setAttribute("aria-expanded", String(expandedInvoiceId === invoice.id));
    if (index === 0) {
      const indicator = document.createElement("span");
      indicator.className = "invoice-disclosure";
      indicator.setAttribute("aria-hidden", "true");
      indicator.textContent = expandedInvoiceId === invoice.id ? "▾" : "▸";
      trigger.append(indicator);
    }
    trigger.append(document.createTextNode(value));
    cell.appendChild(trigger);
    row.appendChild(cell);
  });
  const date = document.createElement("td");
  date.className = "table-cell";
  date.textContent = invoice.date_create ? new Date(invoice.date_create.replace(" ", "T")).toLocaleDateString() : "—";
  row.appendChild(date);
  const status = document.createElement("td");
  status.className = "table-cell";
  const badge = document.createElement("span");
  badge.className = `invoice-status invoice-status-${invoice.invoice_status}`;
  badge.textContent = invoiceStatusLabel(invoice.invoice_status);
  status.appendChild(badge);
  row.appendChild(status);
  [invoice.amount, invoice.due_balance].forEach((amount) => {
    const cell = document.createElement("td");
    cell.className = "table-cell numeric";
    cell.textContent = currency(amount);
    row.appendChild(cell);
  });
  const actions = document.createElement("td");
  actions.className = "table-cell invoice-actions";
  if (invoice.invoice_status !== "cancelled") {
    const cancel = document.createElement("button");
    cancel.className = "btn invoice-cancel"; cancel.type = "button"; cancel.dataset.variant = "ghost"; cancel.dataset.size = "sm"; cancel.dataset.cancelInvoice = invoice.id; cancel.textContent = "Cancel";
    actions.appendChild(cancel);
  } else {
    actions.textContent = invoice.cancelled_by || "—";
  }
  row.appendChild(actions);
  return row;
}

function invoiceDetailsRow(invoice) {
  const detail = invoiceDetails.get(invoice.id);
  const row = document.createElement("tr");
  row.className = "table-row invoice-details-row";
  const cell = document.createElement("td");
  cell.className = "table-cell";
  cell.colSpan = 7;
  const card = document.createElement("section");
  card.className = "card invoice-details-card";
  if (!detail) {
    const content = document.createElement("div");
    content.className = "card-content muted";
    content.textContent = "Loading invoice details…";
    card.appendChild(content);
  } else {
    const header = document.createElement("div");
    header.className = "card-header";
    const title = document.createElement("h3");
    title.className = "card-title";
    title.textContent = detail.sequence || `Invoice #${detail.id}`;
    const description = document.createElement("p");
    description.className = "card-description";
    description.textContent = `${detail.client?.name || "Walk-in customer"} · ${detail.sale_type || "Sale"} · ${detail.login || "—"}`;
    const headerCopy = document.createElement("div");
    headerCopy.append(title, description);
    header.appendChild(headerCopy);
    if (detail.invoice_status === "open") header.appendChild(invoicePaymentForm(detail));
    if (["close", "cancelled"].includes(detail.invoice_status)) {
      const statusBadge = document.createElement("span");
      statusBadge.className = `invoice-status invoice-detail-status invoice-status-${detail.invoice_status}`;
      statusBadge.textContent = invoiceStatusLabel(detail.invoice_status);
      header.appendChild(statusBadge);
    }
    const content = document.createElement("div");
    content.className = "card-content";
    const paymentTableWrap = document.createElement("div");
    paymentTableWrap.className = "table-container invoice-payment-history";
    const paymentTitle = document.createElement("p");
    paymentTitle.className = "invoice-table-section-title";
    paymentTitle.textContent = "Payments";
    const paymentTable = document.createElement("table");
    paymentTable.className = "table";
    const paymentCaption = document.createElement("caption");
    paymentCaption.className = "sr-only";
    paymentCaption.textContent = "Recorded payments";
    const paymentHead = document.createElement("thead");
    const paymentColumns = document.createElement("tr");
    paymentColumns.className = "table-row invoice-payment-columns";
    ["Payment", "Date", "User", "Method", "Amount", "Status"].forEach((label) => {
      const th = document.createElement("th");
      th.className = "table-head";
      th.scope = "col";
      th.textContent = label;
      paymentColumns.appendChild(th);
    });
    paymentHead.appendChild(paymentColumns);
    const paymentBody = document.createElement("tbody");
    if (!detail.payments.length) {
      const emptyRow = document.createElement("tr");
      emptyRow.className = "table-row";
      const emptyCell = document.createElement("td");
      emptyCell.className = "table-cell muted";
      emptyCell.colSpan = 6;
      emptyCell.textContent = "No payments recorded.";
      emptyRow.appendChild(emptyCell);
      paymentBody.appendChild(emptyRow);
    }
    detail.payments.forEach((payment) => {
      const paymentRow = document.createElement("tr");
      paymentRow.className = "table-row";
      const values = ["Payment", payment.date_create ? new Date(payment.date_create.replace(" ", "T")).toLocaleDateString() : "—", payment.login || detail.login || "—", payment.type === "CC" ? "Credit Card" : "Cash", currency(payment.amount), detail.invoice_status === "close" ? "Complete" : "Partial"];
      values.forEach((value, index) => {
        const paymentCell = document.createElement("td");
        paymentCell.className = index === 4 ? "table-cell numeric" : "table-cell";
        paymentCell.textContent = value;
        paymentRow.appendChild(paymentCell);
      });
      paymentBody.appendChild(paymentRow);
    });
    paymentTable.append(paymentCaption, paymentHead, paymentBody);
    paymentTableWrap.append(paymentTitle, paymentTable);
    const tableWrap = document.createElement("div");
    tableWrap.className = "table-container";
    const lineItemsTitle = document.createElement("p");
    lineItemsTitle.className = "invoice-table-section-title";
    lineItemsTitle.textContent = "Invoice line items";
    const table = document.createElement("table");
    table.className = "table invoice-detail-lines";
    const caption = document.createElement("caption");
    caption.className = "sr-only";
    caption.textContent = "Invoice line items";
    const head = document.createElement("thead");
    const headRow = document.createElement("tr");
    headRow.className = "table-row invoice-line-columns";
    ["Product", "Quantity", "Unit price", "Discount", "Total"].forEach((label) => {
      const th = document.createElement("th");
      th.className = "table-head"; th.scope = "col"; th.textContent = label; headRow.appendChild(th);
    });
    head.appendChild(headRow);
    const body = document.createElement("tbody");
    detail.lines.forEach((line) => {
      const lineRow = document.createElement("tr"); lineRow.className = "table-row";
      [line.product?.name || "—", line.quantity, currency(line.amount), currency(line.discount), currency(line.total_amount)].forEach((value, index) => {
        const td = document.createElement("td"); td.className = index ? "table-cell numeric" : "table-cell"; td.textContent = value; lineRow.appendChild(td);
      });
      body.appendChild(lineRow);
    });
    const foot = document.createElement("tfoot");
    [["Subtotal", detail.sub], ["Tax", detail.tax_amount], ["Discount", detail.discount], ["Total", detail.amount]].forEach(([label, value]) => {
      const summaryRow = document.createElement("tr");
      summaryRow.className = "table-row invoice-line-summary";
      if (label === "Total") summaryRow.classList.add("invoice-line-summary-total");
      const spacer = document.createElement("td");
      spacer.className = "table-cell";
      spacer.colSpan = 3;
      spacer.setAttribute("aria-hidden", "true");
      const summaryLabel = document.createElement("th");
      summaryLabel.className = "table-cell";
      summaryLabel.scope = "row";
      summaryLabel.textContent = label;
      const summaryAmount = document.createElement("td");
      summaryAmount.className = "table-cell numeric";
      summaryAmount.textContent = currency(value);
      summaryRow.append(spacer, summaryLabel, summaryAmount);
      foot.appendChild(summaryRow);
    });
    table.append(caption, head, body, foot); tableWrap.append(lineItemsTitle, table); content.append(paymentTableWrap, tableWrap); card.append(header, content);
  }
  cell.appendChild(card); row.appendChild(cell);
  return row;
}

function renderInvoices() {
  invoiceTableBody.replaceChildren(...invoices.flatMap((invoice) => expandedInvoiceId === invoice.id ? [invoiceRow(invoice), invoiceDetailsRow(invoice)] : [invoiceRow(invoice)]));
  if (!invoices.length && !invoiceLoading) invoiceReportStatus.textContent = "No invoices found.";
}

function renderInvoicesPreservingScroll(invoiceId) {
  const currentTrigger = invoiceTableBody.querySelector(`[data-invoice-detail="${invoiceId}"]`);
  const currentDetails = currentTrigger?.closest("tr")?.nextElementSibling;
  const scrollTop = catalogPanel.scrollTop;
  const offset = currentDetails ? currentDetails.getBoundingClientRect().top - catalogPanel.getBoundingClientRect().top : null;

  renderInvoices();

  requestAnimationFrame(() => {
    const refreshedTrigger = invoiceTableBody.querySelector(`[data-invoice-detail="${invoiceId}"]`);
    const refreshedDetails = refreshedTrigger?.closest("tr")?.nextElementSibling;
    if (offset !== null && refreshedDetails) {
      const refreshedOffset = refreshedDetails.getBoundingClientRect().top - catalogPanel.getBoundingClientRect().top;
      catalogPanel.scrollTop = scrollTop + refreshedOffset - offset;
    } else {
      catalogPanel.scrollTop = scrollTop;
    }
  });
}

function sortInvoices() {
  const { key, direction } = invoiceSort;
  const factor = direction === "asc" ? 1 : -1;
  invoices.sort((left, right) => {
    const leftValue = key === "sequence" ? left.sequence : left[key];
    const rightValue = key === "sequence" ? right.sequence : right[key];
    if (["amount", "due_balance"].includes(key)) return (Number(leftValue || 0) - Number(rightValue || 0)) * factor;
    return String(leftValue || "").localeCompare(String(rightValue || ""), undefined, { numeric: true, sensitivity: "base" }) * factor;
  });
}

async function loadInvoices({ reset = false } = {}) {
  if (invoiceLoading || (!reset && !invoiceHasMore)) return;
  if (reset) { invoiceCursor = null; invoiceHasMore = true; invoices = []; expandedInvoiceId = null; }
  invoiceLoading = true;
  invoiceReportStatus.textContent = invoices.length ? "Loading more invoices…" : "Loading invoices…";
  try {
    const page = await salesReport(storeId, invoiceCursor, invoiceSearch.value.trim(), invoiceDateFrom.value, invoiceDateTo.value, invoiceStatusFilter);
    invoices = invoices.concat(page.entries);
    sortInvoices();
    invoiceCursor = page.next_cursor;
    invoiceHasMore = page.has_more;
    updateInvoiceSummary(page.summary);
    renderInvoices();
    invoiceReportStatus.textContent = invoiceHasMore ? "Scroll for more invoices" : `${invoices.length} invoices loaded`;
  } catch (error) {
    console.error(error);
    invoiceReportStatus.textContent = "Invoices could not be loaded. Check the server connection.";
  } finally { invoiceLoading = false; }
}

function openInvoiceReport() {
  customersScreen.hidden = true;
  checkoutFlow.hidden = true;
  catalogPanel.dataset.view = "invoices";
  appShell.classList.add("invoice-view");
  invoiceReport.hidden = false;
  updateInvoiceStickyOffset();
  selectSidebar("sales-report-nav");
  if (!invoices.length) loadInvoices({ reset: true });
  requestAnimationFrame(() => document.querySelector("#invoice-report-title").focus());
}

function closeInvoiceReport() {
  invoiceReport.hidden = true;
  if (catalogPanel.dataset.view === "invoices") delete catalogPanel.dataset.view;
  appShell.classList.remove("invoice-view");
  selectSidebar("pos-nav");
}

function formatOperationDate(value) { return value ? new Date(String(value).replace(" ", "T")).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" }) : "—"; }
function closeOperations() { inventoryScreen.hidden = true; ordersScreen.hidden = true; purchaseOrderScreen.hidden = true; }
function openInventory() { openPos(); closeOperations(); catalogPanel.dataset.view = "inventory"; appShell.classList.add("invoice-view"); inventoryScreen.hidden = false; selectSidebar("inventory-nav"); loadInventory(); requestAnimationFrame(() => document.querySelector("#inventory-title").focus()); }
function openOrders() { openPos(); closeOperations(); catalogPanel.dataset.view = "orders"; appShell.classList.add("invoice-view"); ordersScreen.hidden = false; selectSidebar("orders-nav"); loadOrders(); requestAnimationFrame(() => document.querySelector("#orders-title").focus()); }
function sortOperationEntries(entries, sort) { const factor = sort.direction === "asc" ? 1 : -1; return [...entries].sort((a, b) => { const left = a[sort.key] ?? "", right = b[sort.key] ?? ""; return (typeof left === "number" && typeof right === "number" ? left - right : String(left).localeCompare(String(right), undefined, { numeric: true, sensitivity: "base" })) * factor; }); }
function renderInventory() {
  const q = inventorySearchInput.value.trim().toLowerCase();
  const entries = sortOperationEntries(q ? inventoryEntries.filter((e) => String(e.product_name || "").toLowerCase().includes(q)) : inventoryEntries, inventorySort);
  inventoryTableBody.replaceChildren(...entries.map((entry) => {
    const row = document.createElement("tr");
    row.className = "table-row";
    row.dataset.inventoryProductId = entry.product_id;
    [entry.product_name || `Product #${entry.product_id}`, entry.product_code || "—", entry.store_name || "Current store", currency(entry.product_cost), entry.quantity ?? 0, entry.prev_quantity ?? "—", formatOperationDate(entry.last_update), entry.user_updated || "—"].forEach((value) => {
      const cell = document.createElement("td"); cell.className = "table-cell"; cell.textContent = value; row.appendChild(cell);
    });
    const action = document.createElement("td"); action.className = "table-cell inventory-row-action";
    if (editingInventoryProductId === entry.product_id) {
      action.innerHTML = `<div class="inventory-inline-editor"><label class="sr-only" for="inventory-add-${entry.product_id}">Quantity to add</label><input id="inventory-add-${entry.product_id}" class="input" type="number" inputmode="numeric" placeholder="Add" aria-label="Quantity to add"><button class="btn" type="button" data-variant="default" data-size="sm" data-save-inventory="${entry.product_id}">Save</button><button class="btn" type="button" data-variant="ghost" data-size="sm" data-cancel-inventory>Cancel</button></div>`;
    } else {
      action.innerHTML = `<button class="btn" type="button" data-variant="outline" data-size="sm" data-adjust-product="${entry.product_id}">Update</button>`;
    }
    row.appendChild(action);
    return row;
  }));
  inventoryStatus.textContent = entries.length ? `${entries.length} products` : "No inventory found.";
}
function percentage(value) { return `${(Number(value || 0) * 100).toFixed(1)}%`; }
function compactList(items, formatter, empty = "No activity") { return Array.isArray(items) && items.length ? items.map(formatter).join(" · ") : empty; }
function inventoryMetric(title, value, description, tone = "", filter = "") {
  const card = document.createElement("article");
  card.className = `card inventory-summary-card ${tone}`.trim();
  const body = document.createElement(filter ? "button" : "div");
  if (filter) {
    body.className = "btn inventory-kpi";
    body.type = "button";
    body.dataset.inventoryFilter = filter;
    body.dataset.variant = inventoryFilter === filter ? "secondary" : "ghost";
    body.setAttribute("aria-pressed", String(inventoryFilter === filter));
    body.setAttribute("aria-label", `Filter inventory by ${title.toLowerCase()}`);
  }
  const header = document.createElement("div"); header.className = "card-header";
  const label = document.createElement("p"); label.className = "card-title"; label.textContent = title;
  const content = document.createElement("div"); content.className = "card-content";
  const metric = document.createElement("p"); metric.className = "inventory-kpi-value numeric"; metric.textContent = value;
  const detail = document.createElement("p"); detail.className = "inventory-kpi-detail"; detail.textContent = description;
  header.appendChild(label); content.append(metric, detail); body.append(header, content); card.appendChild(body);
  return card;
}
function renderInventorySummary(summary) {
  if (!summary) return;
  const bestProducts = compactList(summary.best_products, (item) => `${item.product_name}: ${currency(item.net_revenue)}`);
  const slowestProducts = compactList(summary.slowest_products, (item) => `${item.product_name}: ${Number(item.net_units).toFixed(0)} units`);
  const salesMix = compactList(summary.sales_mix, (item) => `${item.sale_type || "Sale"}/${item.login || "—"}: ${currency(item.net_sales)}`);
  const paymentMix = compactList(summary.payment_method_mix, (item) => `${item.type}: ${currency(item.amount)}`);
  const cards = [
    inventoryMetric("Inventory valuation", currency(summary.inventory_valuation), `Current store · company total ${currency(summary.company_inventory_valuation)}`),
    inventoryMetric("Negative-stock exposure", `${Number(summary.negative_stock_sku_count || 0)} SKUs`, `${Number(summary.negative_stock_units || 0)} units · ${currency(summary.negative_stock_value)}`, "inventory-summary-negative", "negative"),
    inventoryMetric("Uncosted inventory", `${Number(summary.uncosted_inventory_sku_count || 0)} SKUs`, `${Number(summary.uncosted_inventory_units || 0)} positive units with missing/zero cost`, "inventory-summary-warning", "uncosted"),
    inventoryMetric("Stockout rate", percentage(summary.zero_stock_rate), `${Number(summary.zero_stock_sku_count || 0)} of ${Number(summary.inventoried_sku_count || 0)} inventoried SKUs`, "inventory-summary-warning"),
    inventoryMetric("Net sales · 30 days", currency(summary.net_sales), `${Number(summary.sale_transaction_count || 0)} completed sale transactions`),
    inventoryMetric("Sales mix · 30 days", currency(summary.net_sales), salesMix),
    inventoryMetric("Average order", currency(summary.average_order_value), `${Number(summary.units_per_order || 0).toFixed(1)} net units per sale`),
    inventoryMetric("Best products · 30 days", bestProducts, `Slowest: ${slowestProducts}`),
    inventoryMetric("Discount rate · 30 days", percentage(summary.discount_rate), `${currency(summary.net_discount)} net discounts`),
    inventoryMetric("Payment-method mix · 30 days", paymentMix, "Recorded payments on non-return sales"),
    inventoryMetric("Customer retention · 30 days", `${Number(summary.returning_customer_count || 0)} returning`, `${Number(summary.purchasing_customer_count || 0)} buyers · ${Number(summary.average_purchase_frequency || 0).toFixed(1)} purchases/customer · ${currency(summary.average_customer_value)} avg value`),
    inventoryMetric("Purchase / transfer flow", `${Number(summary.open_purchase_order_count || 0)} purchase · ${Number(summary.open_transfer_count || 0)} transfer open`, `${Number(summary.closed_purchase_order_count || 0)} purchase / ${Number(summary.closed_transfer_count || 0)} transfer closed · ${percentage(summary.receiving_completion_rate)} received · ${Number(summary.average_closed_order_hours || 0).toFixed(1)}h avg`)
  ];
  inventorySummaryGrid.replaceChildren(...cards);
}
function focusInventoryRow(productId) {
  if (!productId) return;
  const row = inventoryTableBody.querySelector(`[data-inventory-product-id="${productId}"]`);
  if (!row) return;
  row.scrollIntoView({ block: "nearest", behavior: "smooth" });
  row.querySelector("[data-adjust-product]")?.focus({ preventScroll: true });
}
function renderInventoryWithoutMoving() {
  const scrollTop = catalogPanel.scrollTop;
  renderInventory();
  catalogPanel.scrollTop = scrollTop;
}
async function loadInventory(focusProductId = null) {
  inventoryStatus.textContent = "Loading inventory…";
  const storeId = document.querySelector("#inventory-store").value;
  try {
    const inventoryUrl = new URL(`${API_BASE_URL}/inventory`);
    inventoryUrl.searchParams.set("store_id", storeId);
    if (inventoryFilter) inventoryUrl.searchParams.set("inventory_filter", inventoryFilter);
    const [inventoryResponse, summaryResponse] = await Promise.all([
      fetch(inventoryUrl),
      inventorySummary(storeId)
    ]);
    if (!inventoryResponse.ok) throw new Error();
    inventoryEntries = (await inventoryResponse.json()).entries;
    renderInventorySummary(summaryResponse.summary);
    renderInventory();
    requestAnimationFrame(() => focusInventoryRow(focusProductId));
  } catch (error) {
    console.error(error);
    inventoryStatus.textContent = "Inventory could not be loaded.";
  }
}
function renderOrders() { const entries = sortOperationEntries(purchaseOrders, purchaseOrderSort); ordersTableBody.replaceChildren(...entries.map((o) => { const r = document.createElement("tr"); r.className = `table-row purchase-order-row purchase-order-${o.status === "received" ? "received" : "open"}`; [`#${o.id}`, o.from_origin_name || "External source", o.to_store_name || "—", o.status === "received" ? "Processed" : "Open", formatOperationDate(o.date_opened), o.user_requester || "—"].forEach((v) => { const c = document.createElement("td"); c.className = "table-cell"; c.textContent = v; r.appendChild(c); }); const c = document.createElement("td"); c.className = "table-cell"; c.innerHTML = `<button class="btn" type="button" data-variant="outline" data-size="sm" data-order-detail="${o.id}">View</button>`; r.appendChild(c); return r; })); ordersStatus.textContent = entries.length ? `${entries.length} orders` : "No purchase orders found."; }
async function loadOrders() { ordersStatus.textContent = "Loading purchase orders…"; try { purchaseOrders = (await productOrders(storeId)).entries.map((order) => ({ ...order, last_updated: order.date_closed || order.date_opened })); renderOrders(); } catch { ordersStatus.textContent = "Purchase orders could not be loaded."; } }
function showOrderDetail(order) { selectedOrder = order; ordersScreen.hidden = true; purchaseOrderScreen.hidden = false; const detail = document.querySelector("#order-detail"); detail.innerHTML = `<div class="card-header"><div><p class="eyebrow">Order #${order.id}</p><h3 class="card-title">${order.status === "received" ? "Processed" : "Open"}</h3><p class="field-description">${order.from_origin_name || "External source"} → ${order.to_store_name || "—"} · Created by ${order.user_requester || "—"}</p></div>${order.status === "opened" ? '<button id="process-order" class="btn" type="button" data-variant="default">Process order</button>' : ""}</div><div class="card-content table-container"><table class="table purchase-order-lines-table"><caption class="table-caption">Products in this purchase order.</caption><thead><tr class="table-row"><th class="table-head">Product</th><th class="table-head">Requested</th><th class="table-head">Observed</th><th class="table-head">Status</th></tr></thead><tbody>${order.lines.map((l) => `<tr class="table-row"><td class="table-cell">${l.product_name}</td><td class="table-cell numeric">${l.quantity}</td><td class="table-cell numeric">${l.quantity_observed ?? "—"}</td><td class="table-cell">${l.status}</td></tr>`).join("")}</tbody></table></div>`; detail.querySelector("#process-order")?.addEventListener("click", openProcessOrder); requestAnimationFrame(() => document.querySelector("#purchase-order-title").focus()); }
function openPurchaseOrderCreate() { ordersScreen.hidden = true; purchaseOrderScreen.hidden = false; const detail = document.querySelector("#order-detail"); detail.innerHTML = `<div class="card-header"><div><p class="eyebrow">Operations</p><h3 class="card-title">Create purchase order</h3><p class="field-description">Add products and confirm the requested quantities.</p></div></div><form id="purchase-order-create-form" class="form card-content"><div class="order-form-grid"><div class="form-field"><label class="label" for="purchase-order-source">Source / provider / store ID</label><input id="purchase-order-source" class="input" type="number" min="1" required></div><div class="form-field"><label class="label" for="purchase-order-destination">Destination store</label><select id="purchase-order-destination" class="select" required><option value="2">Current store</option></select></div></div><div id="order-lines" class="order-lines"></div><button id="add-order-line" class="btn" type="button" data-variant="outline" data-size="sm">Add product</button><p id="purchase-order-create-status" class="field-description" role="status"></p><div class="form-actions"><button class="btn" type="submit" data-variant="default">Create order</button></div></form>`; detail.querySelector("#add-order-line").addEventListener("click", addOrderLine); detail.querySelector("form").addEventListener("submit", createPurchaseOrder); addOrderLine(); requestAnimationFrame(() => document.querySelector("#purchase-order-title").focus()); }
async function createPurchaseOrder(event) { event.preventDefault(); const lines = [...document.querySelectorAll("#order-lines .order-line")].map((line) => ({ product_id: Number(line.querySelector("select").value), quantity: Number(line.querySelector("input[type='number']").value) })); const status = document.querySelector("#purchase-order-create-status"); status.textContent = "Creating…"; try { const order = await createProductOrder({ order_type: "purchase", from_origin_id: Number(document.querySelector("#purchase-order-source").value), to_store_id: Number(document.querySelector("#purchase-order-destination").value), lines }); purchaseOrders.unshift(order); renderOrders(); showOrderDetail(order); window.toast?.success({ title: "Purchase order created", description: `Order #${order.id} is ready to process.` }); } catch (error) { status.textContent = error.message; } }
function fillProductOptions(select) { const entries = inventoryEntries.length ? inventoryEntries : products.map((product) => ({ product_id: product.id, product_name: product.name })); select.replaceChildren(...entries.map((e) => new Option(e.product_name, e.product_id))); }
function openInventoryDialog(productId) { const dialog = document.querySelector("#inventory-dialog"), select = document.querySelector("#inventory-product"); fillProductOptions(select); select.value = productId || inventoryEntries[0]?.product_id || ""; updateInventoryCurrent(); dialog.showModal(); }
function updateInventoryCurrent() { const entry = inventoryEntries.find((e) => String(e.product_id) === document.querySelector("#inventory-product").value); document.querySelector("#inventory-current").value = entry?.quantity ?? 0; }
function addOrderLine() { const line = document.createElement("div"); line.className = "order-line"; const select = document.createElement("select"); select.className = "select"; select.required = true; fillProductOptions(select); const current = document.createElement("input"); current.className = "input numeric"; current.type = "text"; current.readOnly = true; current.setAttribute("aria-label", "Current inventory quantity"); const updateCurrent = () => { const productId = Number(select.value); const entry = inventoryEntries.find((item) => Number(item.product_id) === productId) || products.find((item) => Number(item.id) === productId); current.value = entry?.quantity ?? entry?.inventory_quantity ?? 0; }; select.addEventListener("change", updateCurrent); updateCurrent(); const qty = document.createElement("input"); qty.className = "input"; qty.type = "number"; qty.min = "1"; qty.value = "1"; qty.required = true; qty.setAttribute("aria-label", "Requested quantity"); const remove = document.createElement("button"); remove.className = "btn"; remove.type = "button"; remove.dataset.variant = "ghost"; remove.textContent = "Remove"; remove.addEventListener("click", () => line.remove()); line.append(select, current, qty, remove); document.querySelector("#order-lines").appendChild(line); }
function openOrderDialog() { document.querySelector("#order-form").reset(); document.querySelector("#order-lines").replaceChildren(); addOrderLine(); document.querySelector("#order-dialog").showModal(); }
function openProcessOrder() { const lines = document.querySelector("#process-order-lines"); lines.replaceChildren(); selectedOrder.lines.forEach((line) => { const row = document.createElement("div"); row.className = "order-line process-line"; row.dataset.lineId = line.id; const name = document.createElement("span"); name.textContent = `${line.product_name} (requested ${line.quantity})`; const observed = document.createElement("input"); observed.className = "input"; observed.type = "number"; observed.min = "0"; observed.value = line.quantity_observed ?? line.quantity; row.append(name, observed); lines.appendChild(row); }); document.querySelector("#process-order-dialog").showModal(); }

function selectSidebar(id) {
  document.querySelectorAll(".sidebar-link").forEach((link) => {
    link.toggleAttribute("aria-current", link.id === id);
  });
}

function openPos(event) {
  event?.preventDefault();
  invoiceReport.hidden = true;
  customersScreen.hidden = true;
  inventoryScreen.hidden = true;
  ordersScreen.hidden = true;
  checkoutFlow.hidden = true;
  startCheckoutButton.hidden = false;
  delete catalogPanel.dataset.view;
  appShell.classList.remove("invoice-view");
  selectSidebar("pos-nav");
  productSearch.focus();
}

function openSettings() {
  openPos();
  selectSidebar("settings-nav");
  const switcher = document.querySelector("#language-switcher");
  switcher.open = true;
  switcher.querySelector("summary").focus();
}

function selectCustomer(customer) {
  if (!customer) return;
  selectedCustomer = customer;
  updateCustomerPicker();
  const choice = document.querySelector("#customer-picker");
  const details = document.querySelector("#customer-details");
  if (choice) choice.textContent = customer.name;
  if (details) { details.hidden = false; details.textContent = `${customer.name} · ${customer.celphone || ""} · ${customer.address || ""}`; }
  document.querySelector("#customer-continue").disabled = false;
  document.querySelector("#credit-toggle").disabled = false;
  closeCustomers();
}

function imageSource(raw) {
  if (!raw) return null;
  if (raw.startsWith("data:image/") || raw.startsWith("http://") || raw.startsWith("https://")) return raw;
  return `data:image/jpeg;base64,${raw}`;
}

function productCard(product) {
  const card = document.createElement("article");
  card.className = "card product";
  card.tabIndex = 0; card.setAttribute("role", "button");
  card.dataset.productId = product.id; card.dataset.name = product.name || t("product.unnamed");
  card.dataset.price = product.price || 0; card.dataset.sub = product.sub; card.dataset.tax = product.tax;
  card.setAttribute("aria-label", t("product.add", { name: product.name || t("product.unnamed") }));
  const source = imageSource(product.image_raw);
  if (source) {
    const image = document.createElement("img");
    image.className = "product-image"; image.src = source; image.alt = ""; image.loading = "lazy";
    card.appendChild(image);
  } else {
    const placeholder = document.createElement("div");
    placeholder.className = "product-image product-image-placeholder";
    placeholder.setAttribute("aria-hidden", "true");
    placeholder.textContent = (product.name || "?").slice(0, 1).toUpperCase();
    card.appendChild(placeholder);
  }
  const content = document.createElement("div");
  content.className = "card-content product-content";
  const name = document.createElement("h2");
  name.className = "card-title product-name"; name.textContent = product.name || t("product.unnamed");
  const meta = document.createElement("div");
  meta.className = "product-footer";
  const price = document.createElement("strong");
  price.className = "product-price numeric"; price.textContent = `$${Number(product.price || 0).toFixed(2)}`;
  const inventory = document.createElement("span");
  inventory.className = "inventory-badge numeric";
  inventory.classList.toggle("inventory-badge-low", Number(product.inventory_quantity || 0) <= 0);
  inventory.textContent = t("product.stock", { count: Number(product.inventory_quantity || 0) });
  const code = document.createElement("p");
  code.className = "product-code"; code.textContent = product.code ? `SKU ${product.code}` : t("product.tap");
  meta.append(price, inventory); content.append(name, code, meta); card.appendChild(content);
  return card;
}

function renderProducts() {
  const query = productSearch.value.trim().toLocaleLowerCase();
  const visible = query ? products.filter((p) => `${p.name || ""} ${p.code || ""}`.toLocaleLowerCase().includes(query)) : products;
  productGrid.replaceChildren(...visible.map(productCard));
  if (!visible.length && !loading) productStatus.textContent = query ? t("product.emptyMatch") : t("product.none");
}

async function loadProducts() {
  if (loading || !hasMore) return;
  loading = true;
  productStatus.textContent = products.length ? t("product.loadingMore") : t("products.loading");
  try {
    const page = await activeProducts(storeId, cursor);
    products = products.concat(page.entries);
    cursor = page.next_cursor;
    hasMore = page.has_more;
    renderProducts();
    productStatus.textContent = hasMore ? t("product.scroll") : t("product.loaded", { count: products.length });
  } catch (error) {
    console.error(error);
    productStatus.textContent = t("product.error");
  } finally { loading = false; }
}

async function refreshInventory(productIds) {
  const ids = [...new Set(productIds.map(Number))].filter(Number.isInteger);
  if (!ids.length) return;
  const page = await inventoryQuantities(storeId, ids);
  const quantities = new Map(page.entries.map((entry) => [Number(entry.product_id), entry.quantity]));
  products = products.map((product) => quantities.has(Number(product.id)) ? { ...product, inventory_quantity: quantities.get(Number(product.id)) } : product);
  renderProducts();
  if (!inventoryScreen.hidden) {
    const { summary } = await inventorySummary(document.querySelector("#inventory-store").value);
    renderInventorySummary(summary);
  }
}

function subscribeToInventory() {
  const socketUrl = new URL(API_BASE_URL);
  socketUrl.protocol = socketUrl.protocol === "https:" ? "wss:" : "ws:";
  socketUrl.pathname = "/socket/websocket";
  socketUrl.search = "vsn=2.0.0";
  const socket = new WebSocket(socketUrl);

  socket.addEventListener("open", () => socket.send(JSON.stringify(["1", "1", `inventory:educa:${storeId}`, "phx_join", {}])));
  socket.addEventListener("message", (event) => {
    const [, , , name, payload] = JSON.parse(event.data);
    if (name === "inventory_changed") refreshInventory(payload.product_ids).catch(console.error);
  });
}

async function updatePrinterStatus() {
  try {
    const status = await printer.status();
    printerStatus.alt = status.connected ? t("printer.connected") : t("printer.disconnected");
    printerStatus.title = printerStatus.alt;
    printerStatus.classList.toggle("connected", status.connected);
    printerStatus.classList.toggle("disconnected", !status.connected);
    return status.connected;
  } catch (error) {
    console.error(error); printerStatus.alt = t("printer.disconnected"); printerStatus.title = printerStatus.alt;
    printerStatus.classList.remove("connected"); printerStatus.classList.add("disconnected"); return false;
  }
}

productSearch.addEventListener("input", renderProducts);
orderTitle.addEventListener("click", () => openCustomers("pos"));
clearCustomerButton.addEventListener("click", () => { selectedCustomer = null; updateCustomerPicker(); });
document.querySelector("#customers-back").addEventListener("click", closeCustomers);
customerSearch.addEventListener("input", () => { clearTimeout(customerSearchTimer); customerSearchTimer = setTimeout(loadCustomers, 220); });
document.querySelector("#pos-nav").addEventListener("click", openPos);
document.querySelector("#sales-report-nav").addEventListener("click", openInvoiceReport);
document.querySelector("#inventory-nav").addEventListener("click", openInventory);
document.querySelector("#orders-nav").addEventListener("click", openOrders);
document.querySelector("#inventory-screen thead").addEventListener("click", (event) => { const button = event.target.closest("[data-inventory-sort]"); if (!button) return; const key = button.dataset.inventorySort; inventorySort = { key, direction: inventorySort.key === key && inventorySort.direction === "asc" ? "desc" : "asc" }; document.querySelectorAll("[data-inventory-sort]").forEach((item) => item.parentElement.setAttribute("aria-sort", item === button ? (inventorySort.direction === "asc" ? "ascending" : "descending") : "none")); renderInventory(); });
document.querySelector("#orders-screen thead").addEventListener("click", (event) => { const button = event.target.closest("[data-order-sort]"); if (!button) return; const key = button.dataset.orderSort; purchaseOrderSort = { key, direction: purchaseOrderSort.key === key && purchaseOrderSort.direction === "asc" ? "desc" : "asc" }; document.querySelectorAll("[data-order-sort]").forEach((item) => item.parentElement.setAttribute("aria-sort", item === button ? (purchaseOrderSort.direction === "asc" ? "ascending" : "descending") : "none")); renderOrders(); });
inventorySearchInput.addEventListener("input", renderInventory);
document.querySelector("#inventory-store").addEventListener("change", loadInventory);
document.querySelector("#inventory-kpis-toggle").addEventListener("click", (event) => {
  const expanded = event.currentTarget.getAttribute("aria-expanded") !== "true";
  inventorySummaryGrid.classList.toggle("is-collapsed", !expanded);
  event.currentTarget.setAttribute("aria-expanded", String(expanded));
  event.currentTarget.innerHTML = `${expanded ? "Show fewer KPIs" : "Show more KPIs"} <span aria-hidden="true">${expanded ? "⌃" : "⌄"}</span>`;
});
inventorySummaryGrid.addEventListener("click", (event) => {
  const card = event.target.closest("[data-inventory-filter]");
  if (!card) return;
  inventoryFilter = inventoryFilter === card.dataset.inventoryFilter ? "" : card.dataset.inventoryFilter;
  loadInventory();
});
inventoryTableBody.addEventListener("click", async (event) => {
  const update = event.target.closest("[data-adjust-product]");
  const cancel = event.target.closest("[data-cancel-inventory]");
  const save = event.target.closest("[data-save-inventory]");
  if (update) { editingInventoryProductId = Number(update.dataset.adjustProduct); renderInventoryWithoutMoving(); return; }
  if (cancel) { editingInventoryProductId = null; renderInventoryWithoutMoving(); return; }
  if (!save) return;
  const productId = Number(save.dataset.saveInventory);
  const input = document.querySelector(`#inventory-add-${productId}`);
  const quantity = Number(input.value);
  if (!Number.isInteger(quantity)) { input.focus(); return; }
  save.disabled = true;
  try {
    await adjustInventory({ product_id: productId, store_id: document.querySelector("#inventory-store").value, quantity });
    editingInventoryProductId = null;
    await loadInventory(productId);
    refreshInventory([productId]).catch(console.error);
    window.toast?.success({ title: "Inventory updated", description: "The product quantity was refreshed." });
  } catch (error) {
    save.disabled = false;
    inventoryStatus.textContent = error.message;
  }
});
document.querySelector("#inventory-product").addEventListener("change", updateInventoryCurrent);
document.querySelector("#inventory-form").addEventListener("submit", async (event) => { event.preventDefault(); const form = event.currentTarget; const productId = document.querySelector("#inventory-product").value; const quantity = Number(document.querySelector("#inventory-quantity").value); if (!Number.isInteger(quantity)) return; const status = document.querySelector("#inventory-form-status"); status.textContent = "Saving…"; try { await adjustInventory({ product_id: productId, store_id: document.querySelector("#inventory-form-store").value, quantity }); document.querySelector("#inventory-dialog").close(); await loadInventory(productId); refreshInventory([productId]).catch(console.error); window.toast?.success({ title: "Inventory updated", description: "The product quantity was refreshed." }); } catch (error) { status.textContent = error.message; } });
document.querySelector("#create-order").addEventListener("click", openPurchaseOrderCreate);
document.querySelector("#purchase-order-back").addEventListener("click", () => { purchaseOrderScreen.hidden = true; ordersScreen.hidden = false; requestAnimationFrame(() => document.querySelector("#orders-title").focus()); });
document.querySelector("#add-order-line").addEventListener("click", addOrderLine);
document.querySelector("#order-form").addEventListener("submit", async (event) => { event.preventDefault(); const lines = [...document.querySelectorAll("#order-lines .order-line")].map((line) => ({ product_id: Number(line.querySelector("select").value), quantity: Number(line.querySelector("input[type='number']").value) })); const status = document.querySelector("#order-form-status"); status.textContent = "Creating…"; try { const order = await createProductOrder({ order_type: "purchase", from_origin_id: Number(document.querySelector("#order-source").value), to_store_id: Number(document.querySelector("#order-destination").value), lines }); document.querySelector("#order-dialog").close(); purchaseOrders.unshift(order); renderOrders(); showOrderDetail(order); window.toast?.success({ title: "Purchase order created", description: `Order #${order.id} is ready to process.` }); } catch (error) { status.textContent = error.message; } });
ordersTableBody.addEventListener("click", (event) => { const button = event.target.closest("[data-order-detail]"); if (button) showOrderDetail(purchaseOrders.find((order) => String(order.id) === button.dataset.orderDetail)); });
document.querySelector("#process-order-form").addEventListener("submit", async (event) => { event.preventDefault(); const status = document.querySelector("#process-order-status"); status.textContent = "Processing…"; try { const order = await receiveProductOrder(selectedOrder.id, { lines: [...document.querySelectorAll(".process-line")].map((row) => ({ id: Number(row.dataset.lineId), quantity_observed: Number(row.querySelector("input").value) })) }); document.querySelector("#process-order-dialog").close(); purchaseOrders = purchaseOrders.map((item) => item.id === order.id ? order : item); renderOrders(); showOrderDetail(order); loadInventory(); refreshInventory(order.lines.map((line) => line.product_id)).catch(console.error); window.toast?.success({ title: "Order processed", description: "Inventory quantities were refreshed." }); } catch (error) { status.textContent = error.message; } });
document.querySelector(".invoice-table thead").addEventListener("click", (event) => {
  const button = event.target.closest("[data-sort]");
  if (!button) return;
  const key = button.dataset.sort;
  invoiceSort = {
    key,
    direction: invoiceSort.key === key && invoiceSort.direction === "asc" ? "desc" : "asc"
  };
  document.querySelectorAll(".invoice-sort").forEach((sortButton) => {
    const active = sortButton === button;
    sortButton.parentElement.setAttribute("aria-sort", active ? (invoiceSort.direction === "asc" ? "ascending" : "descending") : "none");
  });
  sortInvoices();
  renderInvoices();
});
document.querySelectorAll("[data-status-filter]").forEach((button) => {
  button.setAttribute("aria-pressed", "false");
  button.addEventListener("click", () => {
    invoiceStatusFilter = invoiceStatusFilter === button.dataset.statusFilter ? "" : button.dataset.statusFilter;
    document.querySelectorAll("[data-status-filter]").forEach((kpi) => {
      const selected = kpi.dataset.statusFilter === invoiceStatusFilter;
      kpi.setAttribute("aria-pressed", String(selected));
      kpi.dataset.variant = selected ? "secondary" : "ghost";
    });
    loadInvoices({ reset: true });
  });
});
invoiceSearch.addEventListener("input", () => {
  clearTimeout(invoiceSearchTimer);
  invoiceSearchTimer = setTimeout(() => loadInvoices({ reset: true }), 250);
});
invoiceFilters.addEventListener("submit", (event) => {
  event.preventDefault();
  loadInvoices({ reset: true });
});
invoiceDateRangeTrigger.addEventListener("click", openDateRangePicker);
document.querySelector("#calendar-previous-month").addEventListener("click", () => { calendarMonth = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() - 1, 1); renderCalendar(); });
document.querySelector("#calendar-next-month").addEventListener("click", () => { calendarMonth = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + 1, 1); renderCalendar(); });
invoiceCalendarGrid.addEventListener("click", (event) => {
  const day = event.target.closest("[data-date]");
  if (!day) return;
  const value = day.dataset.date;
  if (!calendarRange.from || calendarRange.to) calendarRange = { from: value, to: "" };
  else calendarRange = value < calendarRange.from ? { from: value, to: calendarRange.from } : { from: calendarRange.from, to: value };
  renderCalendar();
});
document.querySelector("#invoice-date-range-clear").addEventListener("click", () => { calendarRange = { from: "", to: "" }; renderCalendar(); });
document.querySelector("#invoice-date-range-apply").addEventListener("click", () => {
  invoiceDateFrom.value = calendarRange.from;
  invoiceDateTo.value = calendarRange.to;
  invoiceDateRangeTrigger.textContent = rangeLabel(calendarRange.from, calendarRange.to);
  invoiceDateRangeDialog.close();
  loadInvoices({ reset: true });
});
document.querySelector("#invoice-filters-clear").addEventListener("click", () => {
  invoiceFilters.reset();
  invoiceDateRangeTrigger.textContent = "Any date";
  invoiceStatusFilter = "";
  document.querySelectorAll("[data-status-filter]").forEach((kpi) => { kpi.setAttribute("aria-pressed", "false"); kpi.dataset.variant = "ghost"; });
  loadInvoices({ reset: true });
});
invoiceTableBody.addEventListener("click", async (event) => {
  const trigger = event.target.closest("[data-invoice-detail]");
  if (!trigger) return;
  const invoiceId = Number(trigger.dataset.invoiceDetail);
  if (expandedInvoiceId === invoiceId) {
    expandedInvoiceId = null;
    renderInvoices();
    return;
  }
  expandedInvoiceId = invoiceId;
  renderInvoices();
  if (invoiceDetails.has(invoiceId)) return;
  try {
    invoiceDetails.set(invoiceId, await saleDetails(invoiceId));
    if (expandedInvoiceId === invoiceId) renderInvoices();
  } catch (error) {
    console.error(error);
    expandedInvoiceId = null;
    renderInvoices();
    window.toast?.error({ title: "Could not load invoice details", description: error.message });
  }
});
invoiceTableBody.addEventListener("click", (event) => {
  const button = event.target.closest("[data-payment-type]");
  if (!button || !button.closest(".invoice-payment-methods")) return;
  const row = button.closest(".invoice-payment-row");
  row.dataset.paymentType = button.dataset.paymentType;
  row.querySelectorAll("[data-payment-type]").forEach((method) => {
    const selected = method === button;
    method.dataset.variant = selected ? "default" : "secondary";
    method.setAttribute("aria-pressed", String(selected));
  });
});
invoiceTableBody.addEventListener("submit", async (event) => {
  const form = event.target.closest(".invoice-payment");
  if (!form) return;
  event.preventDefault();
  const invoice = invoices.find((entry) => String(entry.id) === form.dataset.invoiceId);
  const submit = event.submitter;
  const paymentRow = submit?.closest(".invoice-payment-row");
  const isPayoff = paymentRow?.classList.contains("invoice-payment-payoff");
  const amount = isPayoff ? Number(invoice?.due_balance) : Number(paymentRow?.querySelector("input[name='paymentAmount']")?.value);
  if (!invoice || !Number.isFinite(amount) || amount <= 0 || amount > Number(invoice.due_balance)) return;
  submit.disabled = true;
  try {
    const sale = await addSalePayment(invoice.id, { amount, type: paymentRow.dataset.paymentType });
    Object.assign(invoice, sale);
    invoiceDetails.set(invoice.id, sale);
    renderInvoicesPreservingScroll(invoice.id);
    invoiceReportStatus.textContent = "Payment recorded.";
    window.toast?.success({ title: "Payment recorded", description: `${currency(amount)} applied to invoice ${invoice.sequence || invoice.id}.` });
  } catch (error) {
    console.error(error);
    invoiceReportStatus.textContent = error.message;
    window.toast?.error({ title: "Could not record payment", description: error.message });
    submit.disabled = false;
  }
});
invoiceTableBody.addEventListener("click", async (event) => {
  const button = event.target.closest("[data-cancel-invoice]");
  if (!button) return;
  const invoice = invoices.find((entry) => String(entry.id) === button.dataset.cancelInvoice);
  if (!invoice) return;
  invoicePendingCancellation = invoice.id;
  document.querySelector("#invoice-cancel-details-title").textContent = invoice.sequence || `Invoice #${invoice.id}`;
  document.querySelector("#invoice-cancel-details").textContent = `${invoice.client_name || "Walk-in customer"} · ${currency(invoice.amount)} · ${invoice.date_create ? new Date(invoice.date_create.replace(" ", "T")).toLocaleDateString() : "No date"}`;
  invoiceCancelDialog.showModal();
});
document.querySelector("#confirm-invoice-cancel").addEventListener("click", async () => {
  const invoice = invoices.find((entry) => entry.id === invoicePendingCancellation);
  if (!invoice) return;
  const confirm = document.querySelector("#confirm-invoice-cancel");
  confirm.disabled = true;
  try {
    const sale = await cancelSale(invoice.id);
    Object.assign(invoice, sale);
    invoiceDetails.set(invoice.id, sale);
    renderInvoices();
    invoiceReportStatus.textContent = "Invoice cancelled.";
    invoiceCancelDialog.close();
    window.toast?.success({ title: "Invoice cancelled", description: `Inventory for invoice ${invoice.sequence || invoice.id} was restored.` });
  } catch (error) {
    console.error(error);
    invoiceReportStatus.textContent = error.message;
    window.toast?.error({ title: "Could not cancel invoice", description: error.message });
  } finally { confirm.disabled = false; invoicePendingCancellation = null; }
});
customerForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!customerForm.reportValidity()) return;
  const submit = document.querySelector("#customer-submit");
  customerFormStatus.hidden = true; submit.disabled = true;
  try {
    const customer = await createCustomer(Object.fromEntries(new FormData(customerForm)));
    customerForm.reset(); customerDialog.close(); selectCustomer(customer);
  } catch (error) {
    console.error(error); customerFormStatus.textContent = t("customer.saveError"); customerFormStatus.hidden = false;
  } finally { submit.disabled = false; }
});
document.querySelector("#search-focus").addEventListener("click", () => productSearch.focus());
productGrid.addEventListener("keydown", (event) => {
  const product = event.target.closest("[data-product-id]");
  if (product && (event.key === "Enter" || event.key === " ")) {
    event.preventDefault();
    product.click();
  }
});
new IntersectionObserver((entries) => { if (entries.some((entry) => entry.isIntersecting)) loadProducts(); }, { rootMargin: "360px" }).observe(productSentinel);
new IntersectionObserver((entries) => {
  if (!invoiceReport.hidden && entries.some((entry) => entry.isIntersecting)) loadInvoices();
}, { root: catalogPanel, rootMargin: "360px" }).observe(invoiceSentinel);
function showCheckoutStage(stage) {
  checkoutStage = stage;
  checkoutFlow.querySelectorAll("[data-stage]").forEach((element) => {
    element.hidden = element.dataset.stage !== stage;
  });
  checkoutFlow.querySelectorAll("[data-checkout-step]").forEach((element) => {
    const active = element.dataset.checkoutStep === stage;
    if (active) element.setAttribute("aria-current", "step");
    else element.removeAttribute("aria-current");
  });
  const title = checkoutFlow.querySelector(`[data-stage="${stage}"] h2`)?.textContent;
  document.querySelector("#checkout-title").textContent = title || "Checkout";
  checkoutStatus.textContent = "";
  requestAnimationFrame(() => checkoutFlow.querySelector(`[data-stage="${stage}"] h2`)?.focus?.());
}

function openCheckout() {
  if (pos.isEmpty()) { printStatus.textContent = t("print.addItem"); return; }
  catalogPanel.dataset.view = "checkout";
  startCheckoutButton.hidden = true;
  checkoutFlow.hidden = false;
  showCheckoutStage(selectedCustomer ? "payment" : "customer");
}

function closeCheckout() {
  checkoutFlow.hidden = true;
  delete catalogPanel.dataset.view;
  startCheckoutButton.hidden = false;
  startCheckoutButton.focus();
}

function updatePaymentCompletion() {
  const paymentLines = [...document.querySelectorAll(".payment-line")];
  const paid = paymentLines.reduce((sum, line) => sum + (Number(line.querySelector("input").value) || 0), 0);
  const remaining = Math.max(0, pos.total() - paid);
  const nonCashPaid = paymentLines.reduce((sum, line) => line.querySelector("select").value === "CASH" ? sum : sum + (Number(line.querySelector("input").value) || 0), 0);
  const cashPaid = paid - nonCashPaid;
  const change = Math.max(0, cashPaid - Math.max(0, pos.total() - nonCashPaid));
  document.querySelector("#payment-balance").textContent = `${t("checkout.remaining")}: $${remaining.toFixed(2)}`;
  const changeLabel = document.querySelector("#payment-change");
  changeLabel.hidden = change === 0;
  changeLabel.textContent = change ? `${t("checkout.change")}: $${change.toFixed(2)}` : "";
  const onCredit = document.querySelector("#credit-toggle").getAttribute("aria-pressed") === "true";
  document.querySelector("#complete-sale").disabled = !onCredit && paid < pos.total();
}

function updatePaymentChoice() {
  const credit = document.querySelector("#credit-toggle").getAttribute("aria-pressed") === "true";
  const methods = credit ? [t("checkout.credit")] : [...document.querySelectorAll(".payment-line select")].map((select) => select.value === "CC" ? t("checkout.card") : t("checkout.cash"));
  document.querySelector("#payment-choice").textContent = methods.length ? [...new Set(methods)].join(" + ") : "—";
}

startCheckoutButton.addEventListener("click", openCheckout);
document.querySelector("#checkout-cancel").addEventListener("click", closeCheckout);
checkoutFlow.addEventListener("click", (event) => {
  const next = event.target.closest("[data-checkout-next]");
  const back = event.target.closest("[data-checkout-back]");
  if (next) showCheckoutStage(next.dataset.checkoutNext);
  if (back) back.dataset.checkoutBack === "pos" ? closeCheckout() : showCheckoutStage(back.dataset.checkoutBack);
  const sequence = event.target.closest("[data-sequence]");
  if (sequence) document.querySelectorAll("[data-sequence]").forEach((button) => { button.dataset.variant = button === sequence ? "default" : "secondary"; });
});
document.querySelector("#customer-picker").addEventListener("click", () => openCustomers("checkout"));
document.querySelector("#customer-continue").addEventListener("click", () => showCheckoutStage("payment"));
document.querySelector("#delivery-toggle").addEventListener("click", (event) => { const active = event.currentTarget.getAttribute("aria-pressed") !== "true"; event.currentTarget.setAttribute("aria-pressed", String(active)); event.currentTarget.dataset.variant = active ? "default" : "outline"; const target = document.querySelector("#delivery-options"); target.hidden = !active; if (active) target.replaceChildren(...[100,150,200,250,300,400,500,600].map((amount) => { const button = document.createElement("button"); button.className = "btn"; button.dataset.variant = "secondary"; button.dataset.delivery = amount; button.textContent = `$${amount}`; return button; })); else { pos.setDelivery(0); document.querySelector("#delivery-summary").hidden = true; } updatePaymentCompletion(); });
document.querySelector("#delivery-options").addEventListener("click", (event) => { const button = event.target.closest("[data-delivery]"); if (!button) return; pos.setDelivery(Number(button.dataset.delivery)); document.querySelector("#delivery-summary").hidden = false; document.querySelectorAll("[data-delivery]").forEach((item) => item.dataset.variant = item === button ? "default" : "secondary"); updatePaymentCompletion(); });
document.querySelector("#add-payment-line").addEventListener("click", () => { const line = document.createElement("div"); line.className = "payment-line"; const previous = document.querySelector(".payment-line:last-child select")?.value; const method = previous === "CC" ? "CASH" : "CC"; line.innerHTML = `<select class="select" aria-label="${t("checkout.paymentMethod")}"><option value="CASH">${t("checkout.cash")}</option><option value="CC">${t("checkout.card")}</option></select><input class="input numeric" aria-label="${t("checkout.amount")}" type="number" min="0.01" step="0.01" placeholder="$ 0.00"><button class="btn" type="button" data-variant="ghost" data-size="icon" data-remove-payment aria-label="${t("checkout.removePayment")}">×</button>`; line.querySelector("select").value = method; document.querySelector("#payment-lines").append(line); updatePaymentChoice(); });
document.querySelector("#payment-lines").addEventListener("click", (event) => { const button = event.target.closest("[data-remove-payment]"); if (!button) return; button.closest(".payment-line").remove(); document.querySelector("#payment-lines").dispatchEvent(new Event("input", { bubbles: true })); updatePaymentChoice(); });
document.querySelector("#payment-lines").addEventListener("change", () => { updatePaymentChoice(); updatePaymentCompletion(); });
document.querySelector("#payment-lines").addEventListener("input", updatePaymentCompletion);
document.querySelector("#credit-toggle").addEventListener("click", (event) => { const active = event.currentTarget.getAttribute("aria-pressed") !== "true"; event.currentTarget.setAttribute("aria-pressed", String(active)); event.currentTarget.dataset.variant = active ? "default" : "outline"; document.querySelector("#payment-inputs").hidden = active; document.querySelector("#complete-sale").disabled = false; updatePaymentChoice(); });
document.querySelector("#complete-sale").addEventListener("click", async () => { const complete = document.querySelector("#complete-sale"); const credit = document.querySelector("#credit-toggle").getAttribute("aria-pressed") === "true"; const payments = [...document.querySelectorAll(".payment-line")].map((line) => ({ type: line.querySelector("select").value, amount: Number(line.querySelector("input").value) || 0 })).filter((line) => line.amount); if (!credit && payments.reduce((sum, line) => sum + line.amount, 0) < pos.total()) return; const receipt = pos.receipt(); complete.disabled = true; try { await createSale({ store_id: storeId, client_id: selectedCustomer.id, sequence_type: document.querySelector("[data-sequence][data-variant=default]").dataset.sequence, status: credit ? "CREDIT" : "CASH", sale_type: receipt.delivery ? "FOR_DELIVER" : "IN_SHOP", delivery_charge: receipt.delivery, lines: receipt.items.map((item) => ({ product_id: Number(item.id), quantity: item.qty, discount: item.discount })), payments: credit ? [] : payments }); await refreshInventory(receipt.items.map((item) => item.id)).catch(console.error); completedReceipt = receipt; resetCompletedOrder(); closeCheckout(); document.querySelector("#receipt-dialog").showModal(); } catch (error) { checkoutStatus.textContent = error.message; complete.disabled = false; } });
document.querySelector("#skip-print").addEventListener("click", () => { document.querySelector("#receipt-dialog").close(); completedReceipt = null; });
document.querySelector("#print-receipt").addEventListener("click", async () => { try { if (completedReceipt) await printer.print(completedReceipt); } finally { document.querySelector("#receipt-dialog").close(); completedReceipt = null; } });

pos.render();
translateDocument();
onLanguageChange(() => {
  languageSwitcher.sync();
  pos.render();
  renderProducts();
  updatePrinterStatus();
  if (!checkoutFlow.hidden) showCheckoutStage(checkoutStage);
  updateCustomerPicker();
  if (!customersScreen.hidden) loadCustomers();
});
updateCustomerPicker();
updatePrinterStatus();
loadProducts();
subscribeToInventory();
