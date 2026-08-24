#[cfg(not(target_os = "android"))]
mod device;
mod escpos;

use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
pub struct ReceiptItem {
    pub name: String,
    pub qty: f64,
    pub price: f64,
}

#[derive(Debug, Deserialize)]
pub struct Receipt {
    pub number: String,
    pub items: Vec<ReceiptItem>,
    pub total: f64,
    #[serde(default)]
    pub language: String,
}

#[derive(Debug, Serialize)]
pub struct PrinterStatus {
    pub connected: bool,
    pub vendor_id: String,
    pub product_id: String,
    pub model: String,
}

pub fn print(receipt: Receipt) -> Result<String, String> {
    #[cfg(target_os = "android")]
    {
        let _ = receipt;
        return Err("Receipt printing is not available on Android yet.".to_string());
    }

    #[cfg(not(target_os = "android"))]
    {
    let data = escpos::receipt(&receipt);
    device::write(&data).map(|written| {
        format!(
            "Receipt {} printed: {written} bytes written",
            receipt.number
        )
    })
    }
}

pub fn status() -> Result<PrinterStatus, String> {
    #[cfg(target_os = "android")]
    {
        return Ok(PrinterStatus {
            connected: false,
            vendor_id: String::new(),
            product_id: String::new(),
            model: "Printing is unavailable on Android".to_string(),
        });
    }

    #[cfg(not(target_os = "android"))]
    {
    Ok(PrinterStatus {
        connected: device::connected()?,
        vendor_id: format!("0x{:04x}", device::EPSON_VENDOR_ID),
        product_id: format!("0x{:04x}", device::TM_T20II_PRODUCT_ID),
        model: "EPSON TM-T20II".to_string(),
    })
    }
}
