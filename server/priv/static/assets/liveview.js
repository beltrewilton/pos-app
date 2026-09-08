import { LiveSocket } from "/liveview-client.js";

const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");
const hooks = {
  LoginScreen: window.LoginScreenHook,
  CompanySettings: window.CompanySettingsHook,
  InfiniteInvoices: {
    mounted() {
      this.observer = new IntersectionObserver(entries => {
        if (entries.some(entry => entry.isIntersecting)) this.pushEvent("load_more")
      }, {rootMargin: "360px"})
      this.observer.observe(this.el)
    },
    destroyed() { this.observer?.disconnect() }
  },
  InvoiceReport: {
    mounted() {
      this.fixed = this.el.querySelector(".invoice-report-fixed")
      this.syncStickyOffset = () => this.el.querySelector("#invoice-report")?.style.setProperty("--invoice-fixed-height", `${this.fixed?.offsetHeight || 0}px`)
      this.resizeObserver = new ResizeObserver(this.syncStickyOffset)
      if (this.fixed) this.resizeObserver.observe(this.fixed)
      this.syncStickyOffset()
      this.onPointerDown = event => {
        if (!this.el.querySelector(".invoice-date-picker")?.contains(event.target)) this.pushEvent("close_calendar")
      }
      document.addEventListener("pointerdown", this.onPointerDown)
      requestAnimationFrame(() => this.el.querySelector("#invoice-search")?.focus())
    },
    updated() { this.syncStickyOffset?.() },
    destroyed() {
      this.resizeObserver?.disconnect()
      document.removeEventListener("pointerdown", this.onPointerDown)
    }
  },
  InfiniteCatalog: {
    mounted() {
      this.observer = new IntersectionObserver(entries => {
        if (entries.some(entry => entry.isIntersecting)) this.pushEvent("load_more_products");
      }, {rootMargin: "360px"});
      this.observer.observe(this.el);
    },
    destroyed() { this.observer?.disconnect(); }
  },
  PosTheme: {
    mounted() {
      this.onTheme = event => document.documentElement.dataset.theme = event.detail.theme;
      window.addEventListener("pos:set-theme", this.onTheme);
    },
    destroyed() { window.removeEventListener("pos:set-theme", this.onTheme); }
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
      this.el.addEventListener("input", this.recalculate)
      this.el.addEventListener("click", this.onQuantityClick)
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
        input.focus()
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
      // Discount cards are deliberate confirmation dialogs. Native dialogs
      // normally close on Escape and the old hook closed on their backdrop;
      // both paths would discard an in-progress discount without choosing
      // Cancel or Apply discount.
      this.preventCancel = event => event.preventDefault()
      this.el.addEventListener("cancel", this.preventCancel)
    },
    destroyed() { this.el.removeEventListener("cancel", this.preventCancel) }
  },
  CustomerPurchases: {
    mounted() {
      this.onClick = event => {
        const trigger = event.target.closest("[data-customer-purchase-details]")
        if (!trigger || !this.el.contains(trigger)) return
        const details = document.getElementById(`customer-purchase-items-${trigger.dataset.customerPurchaseDetails}`)
        if (!details) return
        const expanded = trigger.getAttribute("aria-expanded") === "true"
        trigger.setAttribute("aria-expanded", String(!expanded))
        trigger.querySelector(".customer-purchase-disclosure").textContent = expanded ? "▸" : "▾"
        details.hidden = expanded
      }
      this.el.addEventListener("click", this.onClick)
    },
    destroyed() { this.el.removeEventListener("click", this.onClick) }
  },
  PaymentAmounts: {
    mounted() {
      this.money = value => new Intl.NumberFormat("en-US", {style: "currency", currency: "USD"}).format(value)
      this.updateSummary = () => {
        const total = Number(this.el.dataset.saleTotal) || 0
        const paid = [...this.el.querySelectorAll(".payment-line input")].reduce((sum, input) => sum + (Number(input.value) || 0), 0)
        const remaining = Math.max(0, total - paid)
        const change = Math.max(0, paid - total)
        // `data-sale-total` is the LiveView-authoritative checkout amount.
        // Keep the payment-stage header in lockstep with it after a delivery
        // option patches this hook, rather than waiting for a separate DOM
        // update of the heading.
        const checkoutTotal = this.el.closest(".checkout-stage")?.querySelector("#checkout-total")
        const balance = this.el.parentElement.querySelector("#payment-balance")
        let changeLabel = this.el.parentElement.querySelector("#payment-change")
        if (!changeLabel) {
          changeLabel = this.el.parentElement.querySelector("[data-client-payment-change]")
          if (!changeLabel) {
            changeLabel = document.createElement("p")
            changeLabel.className = "payment-change"
            changeLabel.dataset.clientPaymentChange = ""
            changeLabel.hidden = true
            balance?.insertAdjacentElement("afterend", changeLabel)
          }
        }
        const complete = this.el.closest(".checkout-stage")?.querySelector("#complete-sale")
        if (checkoutTotal) checkoutTotal.textContent = this.money(total)
        if (balance) balance.textContent = `Remaining: ${this.money(remaining)}`
        if (changeLabel) {
          changeLabel.hidden = change === 0
          changeLabel.textContent = change ? `Change: ${this.money(change)}` : ""
        }
        if (complete) complete.disabled = paid < total
      }
      this.onInput = event => {
        const input = event.target.closest(".payment-line input")
        if (!input || !this.el.contains(input)) return
        const line = input.closest(".payment-line")
        const previous = Number(input.dataset.previousAmount) || 0
        const entered = Number(input.value) || 0
        const sourceId = line.dataset.splitSource
        const source = sourceId && this.el.querySelector(`[data-payment-line-id="${sourceId}"] input`)
        if (source) {
          const change = Math.round((entered - previous) * 100) / 100
          const total = Number(this.el.dataset.saleTotal) || 0
          const totalBeforeChange = [...this.el.querySelectorAll(".payment-line input")].reduce((sum, node) => sum + (Number(node.value) || 0), 0) - entered + previous
          const changeAbsorbed = change < 0 ? Math.min(-change, Math.max(0, totalBeforeChange - total)) : 0
          const transferred = change > 0 ? Math.min(change, Number(source.value) || 0) : change + changeAbsorbed
          source.value = String(Math.max(0, Math.round(((Number(source.value) || 0) - transferred) * 100) / 100))
          source.dataset.previousAmount = source.value
        }
        input.dataset.previousAmount = String(entered)
        this.updateSummary()
      }
      this.el.addEventListener("input", this.onInput)
      this.onCartTotal = event => {
        const total = Number(event.detail?.total)
        if (!Number.isFinite(total)) return
        this.el.dataset.saleTotal = String(total)
        this.updateSummary()
      }
      window.addEventListener("pos:checkout-total", this.onCartTotal)
      this.updateSummary()
    },
    updated() { this.updateSummary() },
    destroyed() {
      this.el.removeEventListener("input", this.onInput)
      window.removeEventListener("pos:checkout-total", this.onCartTotal)
    }
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
  const merchandiseTotal = beforeOrderDiscount - orderDiscount
  const total = merchandiseTotal + delivery
  const orderFactor = beforeOrderDiscount ? merchandiseTotal / beforeOrderDiscount : 1
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

  // Checkout is rendered beside the cart, so compute its amount from this
  // same client-side sale sum. In particular, delivery is part of `total` and
  // must never leave #checkout-total at the merchandise-only amount.
  const checkoutTotal = document.querySelector("#checkout-total")
  if (checkoutTotal) checkoutTotal.textContent = money(total)

  const paymentLines = document.querySelector("#payment-lines")
  if (paymentLines) paymentLines.dataset.saleTotal = String(total)
  window.dispatchEvent(new CustomEvent("pos:checkout-total", {detail: {total}}))
}
const liveSocket = new LiveSocket("/live", window.Phoenix.Socket, {
  params: { _csrf_token: csrfToken },
  hooks,
});

liveSocket.connect();
window.liveSocket = liveSocket;
