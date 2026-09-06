import { LiveSocket } from "/liveview-client.js";

const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");
const hooks = {
  InfiniteCatalog: {
    mounted() {
      this.observer = new IntersectionObserver(entries => {
        if (entries.some(entry => entry.isIntersecting)) this.pushEvent("load_more_products");
      }, {rootMargin: "360px"});
      this.observer.observe(this.el);
    },
    destroyed() { this.observer?.disconnect(); }
  },
  PosShell: {
    mounted() {
      this.onKeydown = event => {
        if (event.key === "Escape" && this.el.dataset.mobileCartOpen === "true") this.pushEvent("close_mobile_cart");
      };
      document.addEventListener("keydown", this.onKeydown);
    },
    updated() {
      const panel = this.el.querySelector("#order-panel");
      const catalog = this.el.querySelector(".catalog-panel");
      if (this.el.dataset.mobileCartOpen === "true") {
        panel?.setAttribute("role", "dialog");
        panel?.setAttribute("aria-modal", "true");
        catalog?.setAttribute("inert", "");
      } else {
        panel?.removeAttribute("role");
        panel?.removeAttribute("aria-modal");
        catalog?.removeAttribute("inert");
      }
    },
    destroyed() { document.removeEventListener("keydown", this.onKeydown); }
  },
  CartAmounts: {
    mounted() {
      this.recalculate = () => calculateCart(this.el)
      this.onQuantityClick = event => {
        const button = event.target.closest("[aria-label='Increase quantity'], [aria-label='Decrease quantity']")
        if (!button) return
        const input = button.closest(".quantity-control")?.querySelector(".quantity-input")
        if (!input) return
        const delta = button.getAttribute("aria-label") === "Increase quantity" ? 1 : -1
        input.value = String(Math.max(1, (Number.parseInt(input.value, 10) || 1) + delta))
        this.recalculate()
      }
      this.onDoubleClick = event => {
        if (event.target.closest("input, button")) return
        const line = event.target.closest("[data-cart-item-id]")
        if (line && this.el.contains(line)) this.pushEvent("open_line_discount", {id: line.dataset.cartItemId})
      }
      this.el.addEventListener("input", this.recalculate)
      this.el.addEventListener("click", this.onQuantityClick)
      this.el.addEventListener("dblclick", this.onDoubleClick)
      this.handleEvent("pos:cart-bump", ({id}) => {
        const line = document.getElementById(`cart-line-${id}`)
        if (!line) return
        line.classList.remove("bump")
        void line.offsetWidth
        line.classList.add("bump")
        calculateCart(line.closest("#order-panel"))
      })
      this.recalculate()
    },
    updated() { this.recalculate() },
    destroyed() {
      this.el.removeEventListener("input", this.recalculate)
      this.el.removeEventListener("click", this.onQuantityClick)
      this.el.removeEventListener("dblclick", this.onDoubleClick)
    }
  },
  DiscountPreview: {
    mounted() {
      this.updatePreview = () => updateDiscountPreview(this.el)
      this.el.querySelector("#discount-input")?.addEventListener("input", this.updatePreview)
      this.onTypeClick = event => {
        if (event.target.closest("[data-clear-discount]")) {
          const input = this.el.querySelector("#discount-input")
          input.value = ""
          this.updatePreview()
          input.focus()
          return
        }
        const button = event.target.closest("[data-discount-type]")
        if (!button) return
        const type = button.dataset.discountType
        this.el.dataset.discountType = type
        this.el.querySelector("#discount-type").value = type
        this.el.querySelectorAll("[data-discount-type]").forEach(entry => {
          const active = entry === button
          entry.dataset.variant = active ? "default" : "secondary"
          entry.setAttribute("aria-pressed", String(active))
        })
        const input = this.el.querySelector("#discount-input")
        input.max = type === "percent" ? "100" : ""
        this.el.querySelector("#discount-input-label").textContent = type === "percent" ? "Discount percentage" : "Discount amount"
        this.el.querySelector("#discount-help").textContent = type === "percent" ? "Enter 0 to remove this item discount." : "The amount applies to this entire order line."
        this.updatePreview()
      }
      this.el.addEventListener("click", this.onTypeClick)
      this.updatePreview()
    },
    updated() { this.updatePreview() },
    destroyed() {
      this.el.querySelector("#discount-input")?.removeEventListener("input", this.updatePreview)
      this.el.removeEventListener("click", this.onTypeClick)
    }
  },
  DiscountDialog: {
    mounted() {
      if (!this.el.open) this.el.showModal()
      requestAnimationFrame(() => this.el.querySelector("#discount-input")?.focus())
      this.onBackdropClick = event => {
        if (event.target === this.el) this.pushEvent("close_dialog")
      }
      this.el.addEventListener("click", this.onBackdropClick)
    },
    destroyed() { this.el.removeEventListener("click", this.onBackdropClick) }
  },
  FlashToast: {
    mounted() {
      this.el.showPopover?.()
      this.dismissTimer = setTimeout(() => this.pushEvent("clear_pos_flash"), 4000)
    },
    destroyed() { clearTimeout(this.dismissTimer) }
  }
};

function updateDiscountPreview(form) {
  const base = Number.parseFloat(form.dataset.discountBase) || 0
  const input = form.querySelector("#discount-input")
  const entered = Number.parseFloat(input?.value) || 0
  const deduction = form.dataset.discountType === "percent"
    ? base * Math.min(Math.max(entered, 0), 100) / 100
    : Math.min(Math.max(entered, 0), base)
  const money = value => new Intl.NumberFormat("en-US", {style: "currency", currency: "USD"}).format(value)
  const values = form.querySelectorAll(".discount-preview dd")
  if (values[0]) values[0].textContent = money(base)
  if (values[1]) values[1].textContent = `−${money(deduction)}`
  if (values[2]) values[2].textContent = money(base - deduction)
}

// This is a direct port of client/src/js/pos.js's calculation order. The DOM
// values update without waiting for a LiveView round trip; sale persistence is
// still validated by the server.
function calculateCart(panel) {
  const number = value => Number.parseFloat(value) || 0
  const money = value => new Intl.NumberFormat("en-US", {style: "currency", currency: "USD"}).format(value)
  const lines = [...panel.querySelectorAll(".cart-line")].map(element => {
    const price = number(element.dataset.price)
    const quantity = Math.max(0, number(element.querySelector(".quantity-input")?.value))
    const discount = number(element.dataset.discount)
    const discountType = element.dataset.discountType
    const gross = price * quantity
    const lineDiscount = discountType === "percent" ? gross * Math.min(discount, 100) / 100 : Math.min(discount, gross)
    return {element, price, quantity, sub: number(element.dataset.sub), tax: number(element.dataset.tax), gross, lineDiscount}
  })
  const grossSubtotal = lines.reduce((sum, line) => sum + line.gross, 0)
  const lineDiscountTotal = lines.reduce((sum, line) => sum + line.lineDiscount, 0)
  const beforeOrderDiscount = grossSubtotal - lineDiscountTotal
  const orderDiscountInput = number(panel.dataset.orderDiscount)
  const orderDiscount = panel.dataset.orderDiscountType === "percent"
    ? beforeOrderDiscount * Math.min(orderDiscountInput, 100) / 100
    : Math.min(orderDiscountInput, beforeOrderDiscount)
  const delivery = number(panel.dataset.delivery)
  const total = beforeOrderDiscount - orderDiscount + delivery
  const orderFactor = beforeOrderDiscount ? total / beforeOrderDiscount : 1
  let subtotal = 0
  let tax = 0
  lines.forEach(line => {
    const lineFactor = line.gross ? (line.gross - line.lineDiscount) / line.gross : 1
    subtotal += line.sub * line.quantity * lineFactor * orderFactor
    tax += line.tax * line.quantity * lineFactor * orderFactor
    const values = line.element.querySelectorAll(".cart-line-breakdown strong")
    values[0] && (values[0].textContent = money(line.sub * lineFactor))
    values[1] && (values[1].textContent = money(line.tax * lineFactor))
    values[2] && (values[2].textContent = money(line.price * lineFactor))
    const lineTotal = line.element.querySelector(".cart-line-total")
    if (lineTotal) lineTotal.textContent = money(line.gross - line.lineDiscount)
  })
  const rows = panel.querySelectorAll(".totals > div")
  if (rows[0]) rows[0].querySelector("dd").textContent = String(lines.reduce((sum, line) => sum + line.quantity, 0))
  if (rows[1]) rows[1].querySelector("dd").textContent = money(subtotal)
  if (rows[2]) rows[2].querySelector("dd").textContent = money(tax)
  if (rows[3]) rows[3].querySelector("dd").textContent = `−${money(lineDiscountTotal + orderDiscount)}`
  const grandTotal = panel.querySelector(".grand-total dd")
  if (grandTotal) grandTotal.textContent = money(total)
}
const liveSocket = new LiveSocket("/live", window.Phoenix.Socket, {
  params: { _csrf_token: csrfToken },
  hooks,
});

liveSocket.connect();
window.liveSocket = liveSocket;
