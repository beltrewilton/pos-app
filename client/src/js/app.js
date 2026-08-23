import * as printer from "./printer.js";
import { activeProducts } from "./api.js";
import { createPos } from "./pos.js";
import { onLanguageChange, t, translateDocument } from "./i18n.js";
import { createLanguageSwitcher } from "./language-switcher.js";

const printerStatus = document.querySelector("#printer-status");
const printButton = document.querySelector("#print-test");
const printStatus = document.querySelector("#print-status");
const productGrid = document.querySelector("#product-grid");
const productStatus = document.querySelector("#products-status");
const productSearch = document.querySelector("#product-search");
const productSentinel = document.querySelector("#products-sentinel");
const languageSwitcher = createLanguageSwitcher(document.querySelector("#language-switcher"));
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
    const page = await activeProducts(cursor);
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
document.querySelector("#search-focus").addEventListener("click", () => productSearch.focus());
productGrid.addEventListener("keydown", (event) => {
  const product = event.target.closest("[data-product-id]");
  if (product && (event.key === "Enter" || event.key === " ")) {
    event.preventDefault();
    product.click();
  }
});
new IntersectionObserver((entries) => { if (entries.some((entry) => entry.isIntersecting)) loadProducts(); }, { rootMargin: "360px" }).observe(productSentinel);
printButton.addEventListener("click", async () => {
  if (pos.isEmpty()) { printStatus.textContent = t("print.addItem"); return; }
  if (!(await updatePrinterStatus())) { printStatus.textContent = t("printer.disconnected"); return; }
  printStatus.textContent = t("print.printing"); printButton.disabled = true;
  try { printStatus.textContent = await printer.print(pos.receipt()); }
  catch (error) { console.error(error); printStatus.textContent = t("print.error", { error }); }
  finally { printButton.disabled = false; updatePrinterStatus(); }
});

pos.render();
translateDocument();
onLanguageChange(() => { languageSwitcher.sync(); pos.render(); renderProducts(); updatePrinterStatus(); });
updatePrinterStatus();
loadProducts();
