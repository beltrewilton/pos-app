const invoke = window.__TAURI__.core.invoke;

export function status() {
  return invoke("printer_status");
}

export function print(receipt) {
  return invoke("print_receipt", { receipt });
}
