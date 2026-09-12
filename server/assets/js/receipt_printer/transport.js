import {t} from "../i18n"

export class WebUSBPrinterTransport extends EventTarget {
  constructor() {
    super()
    this.device = null
    this.endpointNumber = null
  }

  supported() {
    return "usb" in navigator
  }

  async connect() {
    if (!this.supported()) throw new Error(t("js.webUsbUnsupported"))
    const device = await navigator.usb.requestDevice({filters: usbPrinterFilters()})
    await this.open(device)
    return this.deviceInfo()
  }

  async reconnect(savedDevice) {
    if (!this.supported() || !savedDevice) return null
    const devices = await navigator.usb.getDevices()
    const device = devices.find(item =>
      item.vendorId === savedDevice.vendorId &&
      item.productId === savedDevice.productId &&
      (!savedDevice.serialNumber || item.serialNumber === savedDevice.serialNumber)
    )
    if (!device) return null
    await this.open(device)
    return this.deviceInfo()
  }

  async open(device) {
    this.device = device
    if (!device.opened) await device.open()
    if (device.configuration === null) await device.selectConfiguration(1)
    const iface = device.configuration.interfaces.find(candidate =>
      candidate.alternates.some(alt => alt.endpoints.some(endpoint => endpoint.direction === "out"))
    )
    if (!iface) throw new Error(t("js.noWritableEndpoint"))
    await device.claimInterface(iface.interfaceNumber)
    const alternate = iface.alternates.find(alt => alt.endpoints.some(endpoint => endpoint.direction === "out"))
    this.endpointNumber = alternate.endpoints.find(endpoint => endpoint.direction === "out").endpointNumber
    this.dispatchEvent(new CustomEvent("connected", {detail: this.deviceInfo()}))
  }

  async disconnect() {
    if (this.device?.opened) await this.device.close()
    this.device = null
    this.endpointNumber = null
    this.dispatchEvent(new Event("disconnected"))
  }

  async send(bytes) {
    if (!this.device?.opened || !this.endpointNumber) throw new Error(t("js.printerDisconnected"))
    await this.device.transferOut(this.endpointNumber, bytes)
  }

  deviceInfo() {
    if (!this.device) return null
    return {
      type: "usb",
      vendorId: this.device.vendorId,
      productId: this.device.productId,
      manufacturerName: this.device.manufacturerName,
      productName: this.device.productName,
      serialNumber: this.device.serialNumber,
      language: "esc-pos"
    }
  }
}

function usbPrinterFilters() {
  return [
    {classCode: 0x07},
    {vendorId: 0x04b8},
    {vendorId: 0x0519},
    {vendorId: 0x1504},
    {vendorId: 0x0fe6},
    {vendorId: 0x0483}
  ]
}
