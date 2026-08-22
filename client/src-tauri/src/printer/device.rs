use rusb::{Context, Device, DeviceHandle, Direction, TransferType, UsbContext};
use std::time::Duration;

pub const EPSON_VENDOR_ID: u16 = 0x04b8;
pub const TM_T20II_PRODUCT_ID: u16 = 0x0e15;
const WRITE_TIMEOUT: Duration = Duration::from_secs(3);

pub fn is_supported(device: &Device<Context>) -> Result<bool, String> {
    let descriptor = device
        .device_descriptor()
        .map_err(|error| format!("Could not read USB device descriptor: {error}"))?;
    Ok(descriptor.vendor_id() == EPSON_VENDOR_ID && descriptor.product_id() == TM_T20II_PRODUCT_ID)
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
    Err("EPSON TM-T20II (04b8:0e15) not found".to_string())
}

pub fn connected() -> Result<bool, String> {
    let context = Context::new().map_err(|error| format!("USB context error: {error}"))?;
    let devices = context
        .devices()
        .map_err(|error| format!("Could not list USB devices: {error}"))?;
    for device in devices.iter() {
        if is_supported(&device)? {
            return Ok(true);
        }
    }
    Ok(false)
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
    Err("EPSON TM-T20II found, but no Bulk OUT endpoint was found".to_string())
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
