//! Read-only discovery for Bluetooth devices that macOS classifies as printers.
//!
//! Pairing is not a printable CUPS queue. This module only reports the physical
//! Bluetooth connection so the POS can distinguish "not connected" from
//! "connected but still needs a printer driver/queue".

use std::process::Command;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Device {
    pub name: String,
}

pub fn connected_printer() -> Result<Option<Device>, String> {
    let output = Command::new("system_profiler")
        .arg("SPBluetoothDataType")
        .output()
        .map_err(|error| format!("Could not inspect Bluetooth printers: {error}"))?;
    if !output.status.success() {
        return Err(format!(
            "Could not inspect Bluetooth printers: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }
    Ok(
        parse_connected_printer(&String::from_utf8_lossy(&output.stdout))
            .map(|name| Device { name }),
    )
}

fn parse_connected_printer(output: &str) -> Option<String> {
    let mut in_connected = false;
    let mut name = None;
    for line in output.lines() {
        let trimmed = line.trim();
        if trimmed == "Connected:" {
            in_connected = true;
            name = None;
            continue;
        }
        if trimmed == "Not Connected:" {
            return None;
        }
        if !in_connected {
            continue;
        }
        if let Some(value) = trimmed.strip_prefix("Minor Type: ") {
            if value == "Printer" {
                return name;
            }
            name = None;
        } else if trimmed.ends_with(':') {
            name = Some(trimmed.trim_end_matches(':').to_owned());
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::parse_connected_printer;

    #[test]
    fn finds_a_connected_printer() {
        let output = "  Connected:\n    Thermal-Printer:\n      Address: 60:6E:41\n      Minor Type: Printer\n  Not Connected:\n";
        assert_eq!(parse_connected_printer(output), Some("Thermal-Printer".into()));
    }

    #[test]
    fn ignores_disconnected_printers() {
        let output =
            "  Connected:\n  Not Connected:\n    Thermal-Printer:\n      Minor Type: Printer\n";
        assert_eq!(parse_connected_printer(output), None);
    }
}
