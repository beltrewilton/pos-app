#[cfg(not(any(target_os = "android", target_os = "ios")))]
mod device;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
mod cups;
#[cfg(target_os = "macos")]
mod bluetooth;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
#[path = "escpos_new.rs"]
mod escpos;

use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
pub struct ReceiptItem {
    pub name: String,
    #[serde(default)] pub sku: String,
    pub qty: f64,
    pub price: f64,
    #[serde(default)] pub discount: f64,
    #[serde(default)] pub tax: f64,
    #[serde(default)] pub total: f64,
}

#[derive(Debug, Deserialize, Default)]
pub struct ReceiptLabels {
    #[serde(default)] pub receipt: String, #[serde(default)] pub copy: String, #[serde(default)] pub invoice: String, #[serde(default)] pub fiscal_sequence: String, #[serde(default)] pub rnc: String, #[serde(default)] pub date: String, #[serde(default)] pub store: String, #[serde(default)] pub customer: String, #[serde(default)] pub document: String, #[serde(default)] pub cashier: String, #[serde(default)] pub sku: String, #[serde(default)] pub discount: String, #[serde(default)] pub tax: String, #[serde(default)] pub subtotal: String, #[serde(default)] pub delivery: String, #[serde(default)] pub total: String, #[serde(default)] pub paid: String, #[serde(default)] pub balance: String, #[serde(default)] pub change: String, #[serde(default)] pub memo: String, #[serde(default)] pub thank_you: String, #[serde(default)] pub item_header: String, #[serde(default)] pub savings: String, #[serde(default)] pub items: String,
}
#[derive(Debug, Deserialize)] pub struct ReceiptPayment { pub method: String, pub amount: f64 }

#[derive(Debug, Deserialize)]
pub struct Receipt {
    pub number: String,
    #[serde(default)] pub sequence_description: String,
    pub items: Vec<ReceiptItem>,
    pub total: f64,
    #[serde(default)]
    pub language: String,
    #[serde(default)] pub copy: bool,
    #[serde(default)] pub labels: ReceiptLabels,
    #[serde(default)] pub company: String, #[serde(default)] pub company_id: String,
    #[serde(default)] pub store: String, #[serde(default)] pub logo: String, #[serde(default)] pub store_address: String, #[serde(default)] pub store_slogan: String,
    #[serde(default)] pub date_time: String, #[serde(default)] pub customer: String, #[serde(default)] pub customer_document: String,
    #[serde(default)] pub cashier: String, #[serde(default)] pub memo: String,
    #[serde(default)] pub subtotal: f64, #[serde(default)] pub tax: f64, #[serde(default)] pub discount: f64, #[serde(default)] pub line_discount: f64, #[serde(default)] pub discount_total: f64, #[serde(default)] pub delivery: f64,
    #[serde(default)] pub payments: Vec<ReceiptPayment>, #[serde(default)] pub paid: f64, #[serde(default)] pub balance: f64, #[serde(default)] pub change: f64,
}

#[derive(Debug, Serialize)]
pub struct PrinterStatus {
    pub connected: bool,
    pub vendor_id: String,
    pub product_id: String,
    pub model: String,
    pub transport: String,
}

pub fn print(receipt: Receipt) -> Result<String, String> {
    #[cfg(any(target_os = "android", target_os = "ios"))]
    {
        let _ = receipt;
        return Err("Direct USB receipt printing is not available on mobile.".to_string());
    }

    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    {
    let data = escpos::receipt(&receipt);
    if let Some(queue) = cups::selected_queue()? {
        let written = cups::print(&queue, &data)?;
        return Ok(format!("Receipt {} sent to {}: {written} bytes written", receipt.number, queue.name));
    }
    #[cfg(target_os = "macos")]
    if let Some(device) = bluetooth::connected_printer()? {
        return Err(format!(
            "{} is connected through Bluetooth, but it has no macOS printer queue. Install its macOS driver, add the queue in Printers & Scanners, then restart the POS.",
            device.name
        ));
    }
    device::write(&data).map(|written| {
        format!(
            "Receipt {} printed: {written} bytes written",
            receipt.number
        )
    })
    }
}

pub fn status() -> Result<PrinterStatus, String> {
    #[cfg(any(target_os = "android", target_os = "ios"))]
    {
        return Ok(PrinterStatus {
            connected: false,
            vendor_id: String::new(),
            product_id: String::new(),
            model: "Direct USB printing is unavailable on mobile".to_string(),
            transport: "unavailable".to_string(),
        });
    }

    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    {
    if let Some(queue) = cups::selected_queue()? {
        return Ok(PrinterStatus { connected: true, vendor_id: String::new(), product_id: String::new(), model: queue.model, transport: "cups".to_string() });
    }
    #[cfg(target_os = "macos")]
    if let Some(device) = bluetooth::connected_printer()? {
        return Ok(PrinterStatus { connected: true, vendor_id: String::new(), product_id: String::new(), model: device.name, transport: "bluetooth".to_string() });
    }
    Ok(PrinterStatus {
        connected: device::connected()?,
        vendor_id: format!("0x{:04x}", device::EPSON_VENDOR_ID),
        product_id: format!("0x{:04x}", device::TM_T20II_PRODUCT_ID),
        model: "EPSON TM-T20II".to_string(),
        transport: "usb".to_string(),
    })
    }
}
