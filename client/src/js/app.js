import * as printer from "./printer.js";
import { activeProducts } from "./api.js";
import { createPos } from "./pos.js";

const printerStatus = document.querySelector("#printer-status");
const printButton = document.querySelector("#print-test");
const printStatus = document.querySelector("#print-status");
const productGrid = document.querySelector("#product-grid");
const productStatus = document.querySelector("#products-status");
const productSearch = document.querySelector("#product-search");
const productSentinel = document.querySelector("#products-sentinel");
const pos = createPos({ cartElement: document.querySelector("#cart"), totalElement: document.querySelector("#total"), productGrid });

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
  name.className = "card-title product-name"; name.textContent = product.name || "Unnamed product";
  const meta = document.createElement("div");
  meta.className = "product-meta";
  const price = document.createElement("strong");
  price.className = "product-price numeric"; price.textContent = `$${Number(product.price || 0).toFixed(2)}`;
  const add = document.createElement("button");
  add.className = "btn product-add"; add.type = "button"; add.dataset.variant = "outline"; add.dataset.size = "sm";
  add.dataset.productId = product.id; add.dataset.name = product.name || "Unnamed product"; add.dataset.price = product.price || 0;
  add.textContent = "Add to order"; add.setAttribute("aria-label", `Add ${product.name || "Unnamed product"} to order`);
  meta.append(price); content.append(name, meta, add); card.appendChild(content);
  return card;
}

function renderProducts() {
  const query = productSearch.value.trim().toLocaleLowerCase();
  const visible = query ? products.filter((p) => `${p.name || ""} ${p.code || ""}`.toLocaleLowerCase().includes(query)) : products;
  productGrid.replaceChildren(...visible.map(productCard));
  if (!visible.length && !loading) productStatus.textContent = query ? "No matching products." : "No active products found.";
}

async function loadProducts() {
  if (loading || !hasMore) return;
  loading = true;
  productStatus.textContent = products.length ? "Loading more products…" : "Loading products…";
  try {
    const page = await activeProducts(cursor);
    products = products.concat(page.entries);
    cursor = page.next_cursor;
    hasMore = page.has_more;
    renderProducts();
    productStatus.textContent = hasMore ? "Scroll for more products" : `${products.length} products loaded`;
  } catch (error) {
    console.error(error);
    productStatus.textContent = "Products could not be loaded. Check the server connection.";
  } finally { loading = false; }
}

async function updatePrinterStatus() {
  try {
    const status = await printer.status();
    printerStatus.textContent = `Printer: ${status.connected ? "Connected" : "Disconnected"}`;
    printerStatus.classList.toggle("connected", status.connected);
    printerStatus.classList.toggle("disconnected", !status.connected);
    return status.connected;
  } catch (error) {
    console.error(error); printerStatus.textContent = "Printer: Disconnected";
    printerStatus.classList.remove("connected"); printerStatus.classList.add("disconnected"); return false;
  }
}

productSearch.addEventListener("input", renderProducts);
new IntersectionObserver((entries) => { if (entries.some((entry) => entry.isIntersecting)) loadProducts(); }, { rootMargin: "360px" }).observe(productSentinel);
printButton.addEventListener("click", async () => {
  if (pos.isEmpty()) { printStatus.textContent = "Add an item before printing."; return; }
  if (!(await updatePrinterStatus())) { printStatus.textContent = "Printer disconnected."; return; }
  printStatus.textContent = "Printing…"; printButton.disabled = true;
  try { printStatus.textContent = await printer.print(pos.receipt()); }
  catch (error) { console.error(error); printStatus.textContent = `Print error: ${error}`; }
  finally { printButton.disabled = false; updatePrinterStatus(); }
});

pos.render();
updatePrinterStatus();
loadProducts();
