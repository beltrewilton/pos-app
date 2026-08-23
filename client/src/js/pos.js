export function createPos(options) {
  const { cartElement, totalElement, subtotalElement, discountElement, taxElement, itemCountElement, emptyElement, clearButton, chargeButton, productGrid, discountDialog, discountForm, discountTypeButtons, discountInput, discountInputLabel, discountHelp, discountProductName, discountPreviewAmount, discountPreviewDiscount, discountPreviewTotal, clearDialog, clearConfirmButton } = options;
  const cart = [];
  let discountTarget = null;
  let discountType = "percent";
  const money = (value) => "$" + value.toFixed(2);
  const lineGross = (item) => item.price * item.qty;
  const lineDiscount = (item) => item.discountType === "amount" ? Math.min(item.discount, lineGross(item)) : lineGross(item) * (item.discount / 100);
  const subtotal = () => cart.reduce((value, item) => value + item.qty * item.price, 0);
  const discountTotal = () => cart.reduce((value, item) => value + lineDiscount(item), 0);
  const total = () => subtotal() - discountTotal();
  const lineFactor = (item) => lineGross(item) ? (lineGross(item) - lineDiscount(item)) / lineGross(item) : 1;
  const taxTotal = () => cart.reduce((value, item) => value + item.tax * item.qty * lineFactor(item), 0);
  const subTotal = () => cart.reduce((value, item) => value + item.sub * item.qty * lineFactor(item), 0);
  const items = () => cart.reduce((value, item) => value + item.qty, 0);

  function render({ bumpId } = {}) {
    cartElement.replaceChildren(...cart.map((item) => {
      const line = document.createElement("article");
      line.className = "cart-line";
      if (item.id === bumpId) line.classList.add("bump");
      line.dataset.cartItemId = item.id;
      const safeName = escapeHtml(item.name);
      const badge = item.discount ? '<span class="line-discount">' + (item.discountType === "amount" ? money(item.discount) : item.discount + "%") + ' off</span>' : "";
      const factor = lineFactor(item);
      const breakdown = '<p class="cart-line-breakdown"><span><small class="small">Sub</small><strong class="numeric">' + money(item.sub * factor) + '</strong></span><span><small class="small">Tax</small><strong class="numeric">' + money(item.tax * factor) + '</strong></span><span><small class="small">Total</small><strong class="numeric">' + money(item.price * factor) + '</strong><small class="small">each</small></span></p>';
      line.innerHTML = '<div class="cart-line-head"><div><p class="cart-line-name" title="' + safeName + '">' + safeName + badge + '</p>' + breakdown + '</div><button class="btn remove-line" type="button" data-variant="ghost" data-size="icon-xs" data-cart-action="remove" aria-label="Remove ' + safeName + '">×</button></div><div class="cart-line-footer"><div class="quantity-control" role="group"><button class="btn" type="button" data-variant="outline" data-size="icon-xs" data-cart-action="decrease" aria-label="Decrease quantity">−</button><input id="quantity-' + item.id + '" class="quantity-input" data-cart-action="quantity" type="number" inputmode="numeric" min="1" value="' + item.qty + '" aria-label="Item count"><button class="btn" type="button" data-variant="outline" data-size="icon-xs" data-cart-action="increase" aria-label="Increase quantity">+</button></div><strong class="cart-line-total numeric">' + money(lineGross(item) - lineDiscount(item)) + '</strong></div>';
      return line;
    }));
    const isEmpty = cart.length === 0;
    emptyElement.hidden = !isEmpty;
    clearButton.disabled = isEmpty;
    chargeButton.disabled = isEmpty;
    subtotalElement.textContent = money(subTotal());
    taxElement.textContent = money(taxTotal());
    discountElement.textContent = "−" + money(discountTotal());
    totalElement.textContent = money(total());
    itemCountElement.textContent = String(items());
    chargeButton.textContent = "Charge " + money(total());
  }

  function addProduct({ id, name, price, sub, tax }) {
    const existingItem = cart.find((item) => item.id === id);
    if (existingItem) existingItem.qty += 1;
    else cart.push({ id, name, qty: 1, price, sub, tax, discount: 0, discountType: "percent" });
    render({ bumpId: id });
    requestAnimationFrame(() => Array.from(cartElement.children).find((line) => line.dataset.cartItemId === String(id))?.scrollIntoView({ behavior: "smooth", block: "nearest" }));
  }
  function changeQuantity(id, quantity) {
    const item = cart.find((entry) => entry.id === id);
    if (!item) return;
    if (!Number.isFinite(quantity) || quantity < 1) return removeProduct(id);
    item.qty = Math.floor(quantity);
    render({ bumpId: id });
  }
  function removeProduct(id) {
    const index = cart.findIndex((item) => item.id === id);
    if (index === -1) return;
    const [removed] = cart.splice(index, 1);
    render();
    window.toast?.info({ title: removed.name + " removed", action: { label: "Undo", onClick: () => { cart.splice(index, 0, removed); render({ bumpId: removed.id }); } } });
  }
  function openDiscount(id) {
    const item = cart.find((entry) => entry.id === id);
    if (!item) return;
    discountTarget = id;
    discountType = item.discountType;
    discountInput.value = String(item.discount);
    updateDiscountField();
    discountProductName.textContent = "Set a discount for " + item.name + ".";
    discountDialog.showModal();
    requestAnimationFrame(() => discountInput.focus());
  }

  productGrid.addEventListener("click", (event) => {
    const product = event.target.closest("[data-product-id]");
    if (product && productGrid.contains(product)) addProduct({ id: product.dataset.productId, name: product.dataset.name, price: Number(product.dataset.price), sub: Number(product.dataset.sub), tax: Number(product.dataset.tax) });
  });
  cartElement.addEventListener("click", (event) => {
    const action = event.target.closest("[data-cart-action]")?.dataset.cartAction;
    const line = event.target.closest("[data-cart-item-id]");
    const item = line && cart.find((entry) => entry.id === line.dataset.cartItemId);
    if (!action || !item) return;
    if (action === "increase") changeQuantity(item.id, item.qty + 1);
    if (action === "decrease") changeQuantity(item.id, item.qty - 1);
    if (action === "remove") removeProduct(item.id);
  });
  cartElement.addEventListener("change", (event) => {
    if (event.target.dataset.cartAction === "quantity") changeQuantity(event.target.closest("[data-cart-item-id]").dataset.cartItemId, Number(event.target.value));
  });
  cartElement.addEventListener("dblclick", (event) => {
    const line = event.target.closest("[data-cart-item-id]");
    if (line && cartElement.contains(line) && !event.target.matches("input, button")) openDiscount(line.dataset.cartItemId);
  });
  clearButton.addEventListener("click", () => { if (cart.length) clearDialog.showModal(); });
  clearConfirmButton.addEventListener("click", () => { cart.splice(0); render(); clearDialog.close(); window.toast?.info("Order cleared"); });
  discountForm.addEventListener("submit", (event) => {
    event.preventDefault();
    const discount = Number(discountInput.value);
    if (!Number.isFinite(discount) || discount < 0 || (discountType === "percent" && discount > 100)) { discountInput.setAttribute("aria-invalid", "true"); discountInput.focus(); return; }
    const item = cart.find((entry) => entry.id === discountTarget);
    if (item) { item.discount = discount; item.discountType = discountType; render({ bumpId: item.id }); window.toast?.success({ title: discount ? "Discount applied" : "Discount removed", description: item.name }); }
    discountInput.removeAttribute("aria-invalid");
    discountDialog.close();
  });
  discountDialog.addEventListener("click", (event) => { if (event.target === discountDialog) discountDialog.close(); });
  discountInput.addEventListener("input", updateDiscountPreview);
  discountTypeButtons.forEach((button) => button.addEventListener("click", () => { discountType = button.dataset.discountType; updateDiscountField(); }));
  function updateDiscountField() {
    const isPercent = discountType === "percent";
    discountTypeButtons.forEach((button) => {
      const active = button.dataset.discountType === discountType;
      button.dataset.variant = active ? "default" : "secondary";
      button.setAttribute("aria-pressed", String(active));
    });
    discountInput.max = isPercent ? "100" : "";
    discountInputLabel.textContent = isPercent ? "Discount percentage" : "Discount amount";
    discountHelp.textContent = isPercent ? "Enter 0 to remove this item discount." : "The amount applies to this entire line item.";
    updateDiscountPreview();
  }
  function updateDiscountPreview() {
    const item = cart.find((entry) => entry.id === discountTarget);
    const amount = item ? lineGross(item) : 0;
    const enteredDiscount = Number(discountInput.value) || 0;
    const deduction = discountType === "amount" ? Math.min(enteredDiscount, amount) : amount * Math.min(enteredDiscount, 100) / 100;
    discountPreviewAmount.textContent = money(amount);
    discountPreviewDiscount.textContent = "−" + money(deduction);
    discountPreviewTotal.textContent = money(amount - deduction);
  }
  return { isEmpty: () => cart.length === 0, receipt: () => ({ number: "POS-" + String(Date.now()).slice(-6), items: cart.map(({ name, qty, price, sub, tax, discount }) => ({ name, qty, price, sub, tax, discount })), sub: subTotal(), tax: taxTotal(), total: total() }), render };
}

function escapeHtml(value) {
  return String(value).replace(/[&<>'"]/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[character]);
}
