mod printer;

#[tauri::command]
fn read_dropped_image(path: String) -> Result<Vec<u8>, String> {
    let metadata = std::fs::metadata(&path).map_err(|error| error.to_string())?;

    if metadata.len() > 10 * 1024 * 1024 {
        return Err("Image must be 10 MB or smaller.".into());
    }

    std::fs::read(path).map_err(|error| error.to_string())
}

#[tauri::command]
fn print_receipt(receipt: printer::Receipt) -> Result<String, String> {
    printer::print(receipt)
}

#[tauri::command]
fn printer_status() -> Result<printer::PrinterStatus, String> {
    printer::status()
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![print_receipt, printer_status, read_dropped_image])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
