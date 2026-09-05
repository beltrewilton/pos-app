use rusb::{Context, Device, DeviceHandle, Direction, TransferType, UsbContext};
use std::time::Duration;

pub const EPSON_VENDOR_ID: u16 = 0x04b8;
pub const TM_T20II_PRODUCT_ID: u16 = 0x0e15;
pub const TM_T88V_PRODUCT_ID: u16 = 0x0202;
const WRITE_TIMEOUT: Duration = Duration::from_secs(3);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct SupportedPrinter {
    pub product_id: u16,
    pub model: &'static str,
    pub receipt_columns: usize,
}

const TM_T20II: SupportedPrinter = SupportedPrinter {
    product_id: TM_T20II_PRODUCT_ID,
    model: "EPSON TM-T20II",
    receipt_columns: 48,
};

const TM_T88V: SupportedPrinter = SupportedPrinter {
    product_id: TM_T88V_PRODUCT_ID,
    model: "EPSON TM-T88V",
    // This printer's configured printable area is 42 characters wide.
    receipt_columns: 42,
};

fn supported_printer(vendor_id: u16, product_id: u16) -> Option<SupportedPrinter> {
    if vendor_id != EPSON_VENDOR_ID {
        return None;
    }

    match product_id {
        TM_T20II_PRODUCT_ID => Some(TM_T20II),
        TM_T88V_PRODUCT_ID => Some(TM_T88V),
        _ => None,
    }
}

pub fn is_supported(device: &Device<Context>) -> Result<bool, String> {
    let descriptor = device
        .device_descriptor()
        .map_err(|error| format!("Could not read USB device descriptor: {error}"))?;
    Ok(supported_printer(descriptor.vendor_id(), descriptor.product_id()).is_some())
}

pub fn write(data: &[u8]) -> Result<usize, String> {
    let context = Context::new().map_err(|error| format!("USB context error: {error}"))?;
    let devices = context
        .devices()
        .map_err(|error| format!("Could not list USB devices: {error}"))?;
    for device in devices.iter() {
        if is_supported(&device)? {
            return write_to_device(device, data);
        }
    }
    Err(
        "Supported EPSON USB receipt printer not found (TM-T20II 04b8:0e15 or TM-T88V 04b8:0202)"
            .to_string(),
    )
}

pub fn connected_printer() -> Result<Option<SupportedPrinter>, String> {
    let context = Context::new().map_err(|error| format!("USB context error: {error}"))?;
    let devices = context
        .devices()
        .map_err(|error| format!("Could not list USB devices: {error}"))?;
    for device in devices.iter() {
        let descriptor = device
            .device_descriptor()
            .map_err(|error| format!("Could not read USB device descriptor: {error}"))?;
        if let Some(printer) = supported_printer(descriptor.vendor_id(), descriptor.product_id()) {
            return Ok(Some(printer));
        }
    }
    Ok(None)
}

fn write_to_device(device: Device<Context>, data: &[u8]) -> Result<usize, String> {
    let handle = device
        .open()
        .map_err(|error| format!("Could not open EPSON TM-T20II: {error}"))?;
    let config = device
        .active_config_descriptor()
        .map_err(|error| format!("Could not read active USB configuration: {error}"))?;
    for interface in config.interfaces() {
        for descriptor in interface.descriptors() {
            if let Some(endpoint) = descriptor.endpoint_descriptors().find(|endpoint| {
                endpoint.direction() == Direction::Out
                    && endpoint.transfer_type() == TransferType::Bulk
            }) {
                return write_bulk(handle, interface.number(), endpoint.address(), data);
            }
        }
    }
    Err("Supported EPSON receipt printer found, but no Bulk OUT endpoint was found".to_string())
}

fn write_bulk(
    handle: DeviceHandle<Context>,
    interface_number: u8,
    endpoint_address: u8,
    data: &[u8],
) -> Result<usize, String> {
    handle.claim_interface(interface_number).map_err(|error| {
        format!("Could not claim printer interface {interface_number}: {error}")
    })?;
    let write_result = handle.write_bulk(endpoint_address, data, WRITE_TIMEOUT);
    let _ = handle.release_interface(interface_number);
    write_result.map_err(|error| format!("USB write to printer failed: {error}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn recognizes_supported_epson_receipt_printers() {
        assert_eq!(
            supported_printer(EPSON_VENDOR_ID, TM_T20II_PRODUCT_ID),
            Some(TM_T20II)
        );
        assert_eq!(
            supported_printer(EPSON_VENDOR_ID, TM_T88V_PRODUCT_ID),
            Some(TM_T88V)
        );
    }

    #[test]
    fn rejects_other_usb_devices() {
        assert_eq!(supported_printer(EPSON_VENDOR_ID, 0xffff), None);
        assert_eq!(supported_printer(0xffff, TM_T88V_PRODUCT_ID), None);
    }
}
