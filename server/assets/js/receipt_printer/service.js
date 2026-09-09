import {ReceiptEncoder, encoderConfig} from "./encoder.js"
import {ReceiptFormatter} from "./formatter.js"
import {WebUSBPrinterTransport} from "./transport.js"

const STORAGE_KEY = "pos.receiptPrinter.device"

export class ReceiptPrinterService extends EventTarget {
  constructor(config = {}) {
    super()
    this.config = {language: "esc-pos", columns: 48, imageMode: "column", feedBeforeCut: 4, ...config}
    this.transport = new WebUSBPrinterTransport()
    this.device = null
    this.state = "disconnected"
  }

  async reconnect() {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null")
    if (!saved) return null
    return this.withState("connecting", async () => {
      const device = await this.transport.reconnect(saved)
      if (device) this.connected(device)
      else this.setState("disconnected")
      return device
    })
  }

  async connect() {
    return this.withState("connecting", async () => {
      const device = await this.transport.connect()
      this.connected(device)
      return device
    })
  }

  async disconnect() {
    await this.transport.disconnect()
    this.device = null
    this.setState("disconnected")
  }

  async printReceipt(sale) {
    return this.print("receipt", sale)
  }

  async printPayment({sale, payment}) {
    return this.print("payment", sale, payment)
  }

  async reprintInvoice(sale) {
    return this.print("invoice", sale)
  }

  async print(kind, sale, payment = null) {
    if (this.state !== "connected") throw new Error("No receipt printer is connected.")
    const formatter = new ReceiptFormatter(this.config)
    const document = kind === "payment" ? formatter.payment(sale, payment) : kind === "invoice" ? formatter.invoice(sale) : formatter.receipt(sale)
    const encoder = new ReceiptEncoder(encoderConfig(this.config, this.device)).initialize()
    for (const line of document) {
      encoder.align(line.align || "left")
      if (line.type === "image") {
        await encoder.image(line.image, {width: line.width, mode: this.config.imageMode})
        continue
      }
      encoder.size(line.width || 1, line.height || 1)
      encoder.bold(Boolean(line.bold))
      for (const part of String(line.text || "").split("\n")) encoder.line(part)
      encoder.bold(false)
      encoder.size(1, 1)
    }
    const bytes = encoder.cut().encode()
    await this.transport.send(bytes)
    return {status: "success", bytes: bytes.length}
  }

  connected(device) {
    this.device = device
    localStorage.setItem(STORAGE_KEY, JSON.stringify(device))
    this.setState("connected", device)
  }

  async withState(state, operation) {
    this.setState(state)
    try {
      return await operation()
    } catch (error) {
      this.setState("error", {message: error.message})
      throw error
    }
  }

  setState(state, detail = {}) {
    this.state = state
    this.dispatchEvent(new CustomEvent("status", {detail: {state, device: this.device, ...detail}}))
  }
}

export const receiptPrinter = new ReceiptPrinterService()
