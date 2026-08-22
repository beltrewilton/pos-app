export function createPos({ cartElement, totalElement, productGrid }) {
  const cart = [];

  function total() {
    return cart.reduce((value, item) => value + item.qty * item.price, 0);
  }

  function render() {
    cartElement.innerHTML = "";
    cart.forEach((item) => {
      const line = document.createElement("div");
      line.className = "cart-line";
      const name = document.createElement("span");
      name.textContent = `${item.name} × ${item.qty}`;
      const price = document.createElement("strong");
      price.textContent = `$${(item.qty * item.price).toFixed(2)}`;
      line.append(name, price);
      cartElement.appendChild(line);
    });
    totalElement.textContent = `$${total().toFixed(2)}`;
  }

  function addProduct({ id, name, price }) {
    const existingItem = cart.find((item) => item.id === id);
    if (existingItem) existingItem.qty += 1;
    else cart.push({ id, name, qty: 1, price });
    render();
  }

  productGrid.addEventListener("click", (event) => {
    const product = event.target.closest("[data-product-id]");
    if (!product || !productGrid.contains(product)) return;

    addProduct({
      id: product.dataset.productId,
      name: product.dataset.name,
      price: Number(product.dataset.price),
    });
  });

  return {
    isEmpty: () => cart.length === 0,
    receipt: () => ({
      number: `POS-${String(Date.now()).slice(-6)}`,
      items: cart.map(({ name, qty, price }) => ({ name, qty, price })),
      total: total(),
    }),
    render,
  };
}
