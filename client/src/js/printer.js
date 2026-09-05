const invoke = window.__TAURI__?.core?.invoke;

export function status() {
  return typeof invoke === "function"
    ? invoke("printer_status")
    : Promise.resolve({ connected: false });
}

export function print(receipt) {
  if (typeof invoke === "function") return invoke("print_receipt", { receipt });
  window.print();
  return Promise.resolve("Opened the browser print dialog.");
}
