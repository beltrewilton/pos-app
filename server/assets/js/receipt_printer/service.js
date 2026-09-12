import {ReceiptEncoder, encoderConfig} from "./encoder.js"
import {ReceiptFormatter} from "./formatter.js"
import {WebUSBPrinterTransport} from "./transport.js"
import {t} from "../i18n"

const STORAGE_KEY = "pos.receiptPrinter.device"
const PRINTER_VENDOR_IDS = new Set([0x04b8, 0x0519, 0x1504, 0x0fe6, 0x0483])

export class ReceiptPrinterService extends EventTarget {
  constructor(config = {}) {
    super()
    this.config = {language: "esc-pos", columns: 48, imageMode: "column", feedBeforeCut: 4, ...config}
    this.transport = new WebUSBPrinterTransport()
    this.device = null
    this.state = "disconnected"
    this.refreshingStatus = null
  }

  savedDevice() {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || "null")
  }

  matchingGrantedDevice(devices, saved) {
    if (saved) {
      return devices.find(device =>
        device.vendorId === saved.vendorId &&
        device.productId === saved.productId &&
        (!saved.serialNumber || device.serialNumber === saved.serialNumber)
      )
    }

    return devices.find(device => PRINTER_VENDOR_IDS.has(device.vendorId))
  }

  async reconnect() {
    const saved = this.savedDevice()
    if (!saved) return null
    return this.withState("connecting", async () => {
      const device = await this.transport.reconnect(saved)
      if (device) this.connected(device)
      else this.setState("disconnected")
      return device
    })
  }

  async refreshStatus() {
    if (this.refreshingStatus) return this.refreshingStatus
    this.refreshingStatus = this.checkStatus().catch(error => {
      this.setState("error", {message: error.message})
      return false
    }).finally(() => this.refreshingStatus = null)
    return this.refreshingStatus
  }

  async checkStatus() {
    if (!this.transport.supported()) {
      if (this.state !== "disconnected") this.setState("disconnected")
      return false
    }

    const saved = this.savedDevice()
    const devices = await navigator.usb.getDevices()
    const device = this.matchingGrantedDevice(devices, saved)

    if (!device) {
      this.device = null
      this.transport.device = null
      this.transport.endpointNumber = null
      if (this.state !== "disconnected") this.setState("disconnected")
      return false
    }

    if (this.state !== "connected") {
      await this.transport.open(device)
      this.connected(this.transport.deviceInfo())
    }
    else this.setState("connected", this.device)
    return this.state === "connected"
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
    if (this.state !== "connected") throw new Error(t("js.noReceiptPrinter"))
    console.log("[printer] ReceiptPrinterService.print", {kind, sequence: sale?.sequence, paymentId: payment?.id})
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
