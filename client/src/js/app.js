import * as printer from "./printer.js";
import { API_BASE_URL, activeProducts, addSalePayment, cancelSale, createCustomer, createSale, customers, inventoryQuantities, salesReport } from "./api.js";
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

function updateInvoiceStickyOffset() {
  invoiceReport.style.setProperty("--invoice-fixed-height", `${invoiceReportFixed.offsetHeight}px`);
}

new ResizeObserver(updateInvoiceStickyOffset).observe(invoiceReportFixed);

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

function invoiceRow(invoice) {
  const row = document.createElement("tr");
  row.className = "table-row invoice-row";
  const values = [
    invoice.sequence || `#${invoice.id}`,
    invoice.client_name || "Walk-in customer",
    invoice.date_create ? new Date(invoice.date_create.replace(" ", "T")).toLocaleDateString() : "—",
  ];
  values.forEach((value) => {
    const cell = document.createElement("td");
    cell.className = "table-cell";
    cell.textContent = value;
    row.appendChild(cell);
  });
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
  if (invoice.invoice_status === "open") {
    const payment = document.createElement("form");
    payment.className = "invoice-payment";
    payment.dataset.invoiceId = invoice.id;
    const inputId = `invoice-payment-${invoice.id}`;
    const label = document.createElement("label");
    label.className = "label sr-only";
    label.htmlFor = inputId;
    label.textContent = `Payment amount for ${invoice.sequence || invoice.id}`;
    const amount = document.createElement("input");
    amount.className = "input numeric";
    amount.id = inputId;
    amount.type = "number"; amount.min = "0.01"; amount.max = invoice.due_balance; amount.step = "0.01"; amount.required = true;
    amount.value = Number(invoice.due_balance).toFixed(2);
    const typeId = `invoice-payment-type-${invoice.id}`;
    const typeLabel = document.createElement("label");
    typeLabel.className = "label sr-only";
    typeLabel.htmlFor = typeId;
    typeLabel.textContent = "Payment method";
    const type = document.createElement("select");
    type.className = "select"; type.id = typeId;
    type.innerHTML = "<option value=\"CASH\">Cash</option><option value=\"CC\">Card</option>";
    const pay = document.createElement("button");
    pay.className = "btn"; pay.type = "submit"; pay.dataset.variant = "outline"; pay.dataset.size = "sm"; pay.textContent = "Pay";
    payment.append(label, amount, typeLabel, type, pay); actions.appendChild(payment);
  }
  if (invoice.invoice_status !== "cancelled") {
    const cancel = document.createElement("button");
    cancel.className = "btn invoice-cancel"; cancel.type = "button"; cancel.dataset.variant = "ghost"; cancel.dataset.size = "sm"; cancel.dataset.cancelInvoice = invoice.id; cancel.textContent = "Cancel";
    actions.appendChild(cancel);
  }
  row.appendChild(actions);
  return row;
}

function renderInvoices() {
  invoiceTableBody.replaceChildren(...invoices.map(invoiceRow));
  if (!invoices.length && !invoiceLoading) invoiceReportStatus.textContent = "No invoices found.";
}

async function loadInvoices({ reset = false } = {}) {
  if (invoiceLoading || (!reset && !invoiceHasMore)) return;
  if (reset) { invoiceCursor = null; invoiceHasMore = true; invoices = []; }
  invoiceLoading = true;
  invoiceReportStatus.textContent = invoices.length ? "Loading more invoices…" : "Loading invoices…";
  try {
    const page = await salesReport(storeId, invoiceCursor, invoiceSearch.value.trim(), invoiceDateFrom.value, invoiceDateTo.value, invoiceStatusFilter);
    invoices = invoices.concat(page.entries);
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

function selectSidebar(id) {
  document.querySelectorAll(".sidebar-link").forEach((link) => {
    link.toggleAttribute("aria-current", link.id === id);
  });
}

function openPos(event) {
  event?.preventDefault();
  invoiceReport.hidden = true;
  customersScreen.hidden = true;
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
document.querySelector("#catalog-nav").addEventListener("click", openPos);
document.querySelector("#sales-report-nav").addEventListener("click", openInvoiceReport);
document.querySelector("#settings-nav").addEventListener("click", openSettings);
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
invoiceTableBody.addEventListener("submit", async (event) => {
  const form = event.target.closest(".invoice-payment");
  if (!form) return;
  event.preventDefault();
  const invoice = invoices.find((entry) => String(entry.id) === form.dataset.invoiceId);
  const amount = Number(form.querySelector("input").value);
  if (!invoice || !Number.isFinite(amount) || amount <= 0 || amount > Number(invoice.due_balance)) return;
  const submit = form.querySelector("button");
  submit.disabled = true;
  try {
    const sale = await addSalePayment(invoice.id, { amount, type: form.querySelector("select").value });
    Object.assign(invoice, sale);
    renderInvoices();
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
