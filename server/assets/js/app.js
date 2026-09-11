// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/pos_server"
import topbar from "../vendor/topbar"
import {receiptPrinter} from "./receipt_printer/service"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const hooks = {
  LoginScreen: window.LoginScreenHook,
  CompanySettings: window.CompanySettingsHook,
  CustomerDialog: dialogHook(),
  CustomerScreen: {
    mounted() {
      this.customerScrollTop = 0
      this.handleEvent("customer:detail-opened", () => {
        const catalog = this.el.querySelector(".catalog-panel")
        this.customerScrollTop = catalog?.scrollTop || 0
        if (catalog) catalog.scrollTop = 0
        requestAnimationFrame(() => this.el.querySelector("#customer-detail-title")?.focus())
      })
      this.handleEvent("customer:list-restored", () => {
        requestAnimationFrame(() => {
          const catalog = this.el.querySelector(".catalog-panel")
          if (catalog) catalog.scrollTop = this.customerScrollTop || 0
          this.el.querySelector("#customers-table-body [phx-click='open_customer_detail']")?.focus()
        })
      })
      requestAnimationFrame(() => {
        this.el.querySelector("#customer-search")?.focus()
      })
    }
  },
  UsersScreen: {
    mounted() {
      this.handleEvent("users:focus-title", () => {
        requestAnimationFrame(() => this.el.querySelector("#users-title")?.focus())
      })
      requestAnimationFrame(() => this.el.querySelector("#users-search")?.focus())
    }
  },
  InventoryScreen: {
    mounted() {
      requestAnimationFrame(() => this.el.querySelector("#inventory-search")?.focus())
    }
  },
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
      installPrinterEvents(this)
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
        if (entries.some(entry => entry.isIntersecting)) this.pushEvent("load_more_products")
      }, {rootMargin: "360px"})
      this.observer.observe(this.el)
    },
    destroyed() { this.observer?.disconnect() }
  },
  PurchaseOrderLines: purchaseOrderLinesHook(),
  PurchaseOrders: purchaseOrdersHook(),
  OrderProductDialog: dialogHook(),
  PosTheme: {
    mounted() {
      this.onTheme = event => document.documentElement.dataset.theme = event.detail.theme
      window.addEventListener("pos:set-theme", this.onTheme)
    },
    destroyed() { window.removeEventListener("pos:set-theme", this.onTheme) }
  },
  PrinterStatus: {
    mounted() {
      installPrinterStatus(this.el)
    },
    destroyed() {
      uninstallPrinterStatus(this.el)
    }
  },
  NetworkStatus: {
    mounted() {
      installNetworkStatus(this.el)
    },
    destroyed() {
      uninstallNetworkStatus(this.el)
    }
  },
  CreditDueDateForm: {
    mounted() {
      this.value = this.el.querySelector("#sale-credit-due-date")?.value || ""
      this.sync = () => {
        const input = this.el.querySelector("#sale-credit-due-date")
        this.value = input?.value || ""
        const complete = this.el.querySelector("#complete-sale")
        if (complete) complete.disabled = !(input?.value && input.validity.valid)
      }
      this.el.addEventListener("input", this.sync)
      this.el.addEventListener("change", this.sync)
      this.sync()
    },
    updated() {
      const input = this.el.querySelector("#sale-credit-due-date")
      if (input && this.value && input.value !== this.value) input.value = this.value
      this.sync()
    },
    destroyed() {
      this.el.removeEventListener("input", this.sync)
      this.el.removeEventListener("change", this.sync)
    }
  },
  PosShell: {
    mounted() {
      installPrinterEvents(this)
      installPrinterStatus(this.el.querySelector("[data-printer-status]"))
      installNetworkStatus(this.el.querySelector("[data-network-status]"))
      requestAnimationFrame(() => this.el.querySelector("#product-search")?.focus())
      this.onKeydown = event => {
        if (event.key === "Escape" && this.el.dataset.mobileCartOpen === "true") this.pushEvent("close_mobile_cart")
      }
      document.addEventListener("keydown", this.onKeydown)
    },
    updated() {
      const panel = this.el.querySelector("#order-panel")
      const catalog = this.el.querySelector(".catalog-panel")
      if (this.el.dataset.mobileCartOpen === "true") {
        panel?.setAttribute("role", "dialog")
        panel?.setAttribute("aria-modal", "true")
        catalog?.setAttribute("inert", "")
      } else {
        panel?.removeAttribute("role")
        panel?.removeAttribute("aria-modal")
        catalog?.removeAttribute("inert")
      }
    },
    destroyed() {
      uninstallPrinterStatus(this.el.querySelector("[data-printer-status]"))
      uninstallNetworkStatus(this.el.querySelector("[data-network-status]"))
      document.removeEventListener("keydown", this.onKeydown)
    }
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
}
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

function printerStatusLabel(state) {
  return {
    disconnected: "Printer disconnected",
    connecting: "Printer connecting",
    connected: "Printer connected",
    error: "Printer error"
  }[state] || "Printer disconnected"
}

function installPrinterStatus(element) {
  if (!element) return
  element.printerStatusInstallCount = (element.printerStatusInstallCount || 0) + 1
  if (element.printerStatusHandler) return
  element.printerStatusHandler = event => {
    const state = event.detail.state
    element.dataset.status = state
    element.setAttribute("aria-label", printerStatusLabel(state))
    element.title = event.detail.device?.productName || printerStatusLabel(state)
  }
  element.printerStatusClickHandler = async () => {
    try {
      await receiptPrinter.connect()
    } catch (error) {
    }
  }
  element.printerStatusRefreshHandler = () => {
    if (document.hidden) return
    receiptPrinter.refreshStatus().catch(() => {})
  }
  receiptPrinter.addEventListener("status", element.printerStatusHandler)
  element.addEventListener("click", element.printerStatusClickHandler)
  window.addEventListener("focus", element.printerStatusRefreshHandler)
  document.addEventListener("visibilitychange", element.printerStatusRefreshHandler)
  navigator.usb?.addEventListener("connect", element.printerStatusRefreshHandler)
  navigator.usb?.addEventListener("disconnect", element.printerStatusRefreshHandler)
  element.printerStatusHandler({detail: {state: receiptPrinter.state, device: receiptPrinter.device}})
  element.printerStatusRefreshHandler()
  element.printerStatusInterval = setInterval(element.printerStatusRefreshHandler, 5_000)
}

function uninstallPrinterStatus(element) {
  if (!element?.printerStatusHandler) return
  element.printerStatusInstallCount = Math.max((element.printerStatusInstallCount || 1) - 1, 0)
  if (element.printerStatusInstallCount > 0) return
  receiptPrinter.removeEventListener("status", element.printerStatusHandler)
  element.removeEventListener("click", element.printerStatusClickHandler)
  window.removeEventListener("focus", element.printerStatusRefreshHandler)
  document.removeEventListener("visibilitychange", element.printerStatusRefreshHandler)
  navigator.usb?.removeEventListener("connect", element.printerStatusRefreshHandler)
  navigator.usb?.removeEventListener("disconnect", element.printerStatusRefreshHandler)
  clearInterval(element.printerStatusInterval)
  delete element.printerStatusHandler
  delete element.printerStatusClickHandler
  delete element.printerStatusRefreshHandler
  delete element.printerStatusInterval
  delete element.printerStatusInstallCount
}

function networkStatusLabel(state) {
  return state === "connected" ? "Network connected" : "Network disconnected"
}

function setNetworkStatus(element, state) {
  element.dataset.status = state
  element.setAttribute("aria-label", networkStatusLabel(state))
  element.title = networkStatusLabel(state)
}

function installNetworkStatus(element) {
  if (!element) return
  element.networkStatusInstallCount = (element.networkStatusInstallCount || 0) + 1
  if (element.networkStatusRefreshHandler) return
  element.networkStatusRefreshHandler = async () => {
    if (document.hidden) return
    element.networkStatusAbortController?.abort()
    element.networkStatusAbortController = new AbortController()
    const timeout = setTimeout(() => element.networkStatusAbortController.abort(), 2_000)
    try {
      await fetch(`${window.location.origin}/?_network_status=${Date.now()}`, {
        method: "HEAD",
        cache: "no-store",
        signal: element.networkStatusAbortController.signal
      })
      setNetworkStatus(element, "connected")
    } catch (error) {
      setNetworkStatus(element, "disconnected")
    } finally {
      clearTimeout(timeout)
    }
  }
  window.addEventListener("online", element.networkStatusRefreshHandler)
  window.addEventListener("offline", element.networkStatusRefreshHandler)
  window.addEventListener("focus", element.networkStatusRefreshHandler)
  document.addEventListener("visibilitychange", element.networkStatusRefreshHandler)
  setNetworkStatus(element, navigator.onLine ? "connected" : "disconnected")
  element.networkStatusRefreshHandler()
  element.networkStatusInterval = setInterval(element.networkStatusRefreshHandler, 5_000)
}

function uninstallNetworkStatus(element) {
  if (!element?.networkStatusRefreshHandler) return
  element.networkStatusInstallCount = Math.max((element.networkStatusInstallCount || 1) - 1, 0)
  if (element.networkStatusInstallCount > 0) return
  window.removeEventListener("online", element.networkStatusRefreshHandler)
  window.removeEventListener("offline", element.networkStatusRefreshHandler)
  window.removeEventListener("focus", element.networkStatusRefreshHandler)
  document.removeEventListener("visibilitychange", element.networkStatusRefreshHandler)
  element.networkStatusAbortController?.abort()
  clearInterval(element.networkStatusInterval)
  delete element.networkStatusAbortController
  delete element.networkStatusRefreshHandler
  delete element.networkStatusInterval
  delete element.networkStatusInstallCount
}

function installPrinterEvents(hook) {
  hook.handleEvent("printer:print-receipt", payload => {
    const sale = payload.receipt || payload.sale
    console.log("[printer] LiveView event printer:print-receipt", {requestId: payload.request_id, sequence: sale?.sequence, hasCopyLabel: sale?.copy === true})
    return hook.printWithResult(payload.request_id, () => receiptPrinter.printReceipt(sale))
  })
  hook.handleEvent("printer:print-payment", payload => {
    console.log("[printer] LiveView event printer:print-payment", {requestId: payload.request_id, sequence: payload.sale?.sequence, paymentId: payload.payment?.id})
    return hook.printWithResult(payload.request_id, () => receiptPrinter.printPayment(payload))
  })
  hook.handleEvent("printer:reprint-invoice", payload => {
    const sale = payload.invoice || payload.receipt || payload.sale
    console.log("[printer] LiveView event printer:reprint-invoice", {requestId: payload.request_id, sequence: sale?.sequence})
    return hook.printWithResult(payload.request_id, () => receiptPrinter.reprintInvoice(sale))
  })
  hook.printWithResult = async (requestId, operation) => {
    try {
      await operation()
      if (requestId) hook.pushEvent("printer_result", {request_id: requestId, status: "success"})
    } catch (error) {
      if (requestId) hook.pushEvent("printer_result", {request_id: requestId, status: "failed", message: error.message})
    }
  }
}

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

  const checkoutTotal = document.querySelector("#checkout-total")
  if (checkoutTotal) checkoutTotal.textContent = money(total)

  const paymentLines = document.querySelector("#payment-lines")
  if (paymentLines) paymentLines.dataset.saleTotal = String(total)
  window.dispatchEvent(new CustomEvent("pos:checkout-total", {detail: {total}}))
}

function dialogHook() {
  return {
    mounted() {
      this.el.showModal()
      this.el.addEventListener("cancel", event => event.preventDefault())
      this.el.addEventListener("click", event => { if (event.target === this.el) event.preventDefault() })
    }
  }
}

function purchaseOrderLinesHook() {
  return {
    mounted() { initializePurchaseOrderLines(this) },
    updated() {
      initializePurchaseOrderLines(this)
      if (!this.focusNewLine) return
      this.focusNewLine = false
      this.el.querySelector("[data-order-line]:last-child [role='combobox']")?.focus()
    }
  }
}

function purchaseOrdersHook() {
  return {
    mounted() {
      this.onObservedKeydown = event => {
        if (!event.target.matches("[data-observed-input], .observed-input")) return
        if (!["Enter", "ArrowDown", "ArrowUp"].includes(event.key)) return
        event.preventDefault()
        event.stopImmediatePropagation()
        const inputs = [...this.el.querySelectorAll("[data-observed-input], .observed-input")].filter(input => !input.disabled)
        const index = inputs.indexOf(event.target)
        const next = inputs[Math.max(0, Math.min(inputs.length - 1, index + (event.key === "ArrowUp" ? -1 : 1)))]
        next?.scrollIntoView({block: "center", behavior: "smooth"})
        next?.focus({preventScroll: true})
      }
      this.el.addEventListener("keydown", this.onObservedKeydown, true)
      this.onProcessOrder = event => {
        const button = event.target.closest("button[form='receive-order-form']")
        if (!button) return
        event.preventDefault()
        event.stopImmediatePropagation()
        button.disabled = true
        const observed = Object.fromEntries([...this.el.querySelectorAll("[name^='observed']")].map(input => [input.name.match(/\[(.+)\]/)?.[1], input.value]).filter(([id]) => id))
        this.pushEvent("receive_order", {observed})
      }
      this.el.addEventListener("click", this.onProcessOrder, true)
    },
    destroyed() { this.el.removeEventListener("keydown", this.onObservedKeydown, true); this.el.removeEventListener("click", this.onProcessOrder, true) }
  }
}

function initializePurchaseOrderLines(hook) {
  hook.boundLines ||= new WeakSet()
  const form = hook.el.closest("form")
  if (form && !form.dataset.purchaseOrderComboboxGuard) {
    form.dataset.purchaseOrderComboboxGuard = "true"
    form.addEventListener("keydown", event => {
      if (event.key === "Enter" && event.target.matches("[role='combobox']")) event.preventDefault()
    }, true)
    form.addEventListener("submit", event => {
      if (form.dataset.comboboxSelecting !== "true") return
      event.preventDefault()
      event.stopImmediatePropagation()
    }, true)
  }
  hook.el.querySelectorAll("[data-order-line]").forEach(line => {
    if (hook.boundLines.has(line)) return
    hook.boundLines.add(line)
    const input = line.querySelector("[role='combobox']")
    const list = line.querySelector("[role='listbox']")
    const options = () => [...list.querySelectorAll("[role='option']")]
    let matches = [], active = -1
    const render = () => {
      const query = input.value.trim().toLowerCase()
      matches = options().filter(option => `${option.dataset.productName} ${option.dataset.productCode}`.toLowerCase().includes(query)).slice(0, 50)
      options().forEach(option => { option.hidden = !matches.includes(option); option.setAttribute("aria-selected", String(matches[active] === option)) })
      list.hidden = matches.length === 0
      input.setAttribute("aria-expanded", String(matches.length > 0))
      input.setAttribute("aria-activedescendant", active >= 0 ? matches[active]?.id || "" : "")
    }
    const close = () => { active = -1; list.hidden = true; input.setAttribute("aria-expanded", "false") }
    const choose = option => {
      if (!option) return
      form && (form.dataset.comboboxSelecting = "true")
      window.setTimeout(() => { if (form) delete form.dataset.comboboxSelecting }, 300)
      input.value = option.dataset.productCode ? `${option.dataset.productName} · ${option.dataset.productCode}` : option.dataset.productName
      close()
      hook.pushEvent("line_product", {id: line.dataset.lineId, product_id: option.dataset.productId})
      line.querySelector("[aria-label='Requested quantity']")?.focus()
    }
    input.addEventListener("input", () => { active = -1; render() })
    input.addEventListener("focus", render)
    input.addEventListener("keydown", event => {
      if (["ArrowDown", "ArrowUp"].includes(event.key)) { event.preventDefault(); render(); active = event.key === "ArrowUp" && active < 0 ? matches.length - 1 : Math.max(0, Math.min(matches.length - 1, active + (event.key === "ArrowDown" ? 1 : -1))); render() }
      else if (event.key === "Home" && matches.length) { event.preventDefault(); active = 0; render() }
      else if (event.key === "End" && matches.length) { event.preventDefault(); active = matches.length - 1; render() }
      else if (event.key === "Enter" && matches.length) { event.preventDefault(); choose(matches[Math.max(active, 0)]) }
      else if (event.key === "Escape") close()
    })
    input.addEventListener("blur", () => setTimeout(close, 120))
    options().forEach(option => option.addEventListener("pointerdown", event => { event.preventDefault(); event.stopPropagation(); choose(option) }))
    const quantity = line.querySelector("[aria-label='Requested quantity']")
    quantity?.addEventListener("keydown", event => {
      if (event.key !== "Enter") return
      event.preventDefault()
      if (line.querySelector("[aria-label='Edit selected product']")?.disabled || !quantity.validity.valid) return
      hook.focusNewLine = true
      hook.pushEvent("add_line", {})
    })
  })
}

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
