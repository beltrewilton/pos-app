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
        const target = window.matchMedia("(max-width: 640px)").matches ? "#customer-search" : "#customers-title"
        this.el.querySelector(target)?.focus()
      })
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
      this.setPrinterStatus = event => {
        const state = event.detail.state
        this.el.dataset.status = state
        this.el.setAttribute("aria-label", printerStatusLabel(state))
        this.el.title = event.detail.device?.productName || printerStatusLabel(state)
      }
      this.onPrinterClick = async () => {
        try {
          await receiptPrinter.connect()
        } catch (error) {
        }
      }
      receiptPrinter.addEventListener("status", this.setPrinterStatus)
      this.el.addEventListener("click", this.onPrinterClick)
      receiptPrinter.reconnect().catch(() => {})
    },
    destroyed() {
      receiptPrinter.removeEventListener("status", this.setPrinterStatus)
      this.el.removeEventListener("click", this.onPrinterClick)
    }
  },
  PosShell: {
    mounted() {
      installPrinterEvents(this)
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
      document.removeEventListener("keydown", this.onKeydown)
    }
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

function installPrinterEvents(hook) {
  hook.handleEvent("printer:print-receipt", payload => hook.printWithResult(payload.request_id, () => receiptPrinter.printReceipt(payload.receipt || payload.sale)))
  hook.handleEvent("printer:print-payment", payload => hook.printWithResult(payload.request_id, () => receiptPrinter.printPayment(payload)))
  hook.handleEvent("printer:reprint-invoice", payload => hook.printWithResult(payload.request_id, () => receiptPrinter.reprintInvoice(payload.invoice || payload.receipt || payload.sale)))
  hook.printWithResult = async (requestId, operation) => {
    try {
      await operation()
      if (requestId) hook.pushEvent("printer_result", {request_id: requestId, status: "success"})
    } catch (error) {
      if (requestId) hook.pushEvent("printer_result", {request_id: requestId, status: "failed", message: error.message})
    }
  }
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
