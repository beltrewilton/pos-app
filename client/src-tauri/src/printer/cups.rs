//! Generic CUPS transport for receipt printers.
//!
//! CUPS owns the device-specific connection (USB, Bluetooth, or network) and
//! its driver. This keeps the POS independent from a printer's USB IDs.

use std::{
    io::Write,
    process::{Command, Stdio},
};

const PRINTER_QUEUE_ENV: &str = "POS_PRINTER_QUEUE";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Queue {
    pub name: String,
    pub model: String,
}

pub fn selected_queue() -> Result<Option<Queue>, String> {
    if let Some(name) = std::env::var(PRINTER_QUEUE_ENV)
        .ok()
        .map(|v| v.trim().to_owned())
        .filter(|v| !v.is_empty())
    {
        return queue_named(&name).map(Some);
    }
    // `lpstat -d` intentionally exits non-zero when no default exists, which
    // is a normal state while the POS is configured for direct USB fallback.
    let output = Command::new("lpstat")
        .arg("-d")
        .output()
        .map_err(|e| format!("Could not run lpstat: {e}"))?;
    let text = format!(
        "{}{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    match parse_default_queue(&text) {
        Some(name) => queue_named(&name).map(Some),
        None => Ok(None),
    }
}

pub fn print(queue: &Queue, data: &[u8]) -> Result<usize, String> {
    let mut child = Command::new("lp")
        .args(["-d", &queue.name, "-o", "raw"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("Could not start CUPS print command: {e}"))?;
    child
        .stdin
        .take()
        .ok_or("Could not open the CUPS print input")?
        .write_all(data)
        .map_err(|e| format!("Could not send receipt to CUPS: {e}"))?;
    let output = child
        .wait_with_output()
        .map_err(|e| format!("Could not wait for CUPS print command: {e}"))?;
    if output.status.success() {
        Ok(data.len())
    } else {
        Err(command_error("CUPS rejected the print job", &output.stderr))
    }
}

fn queue_named(name: &str) -> Result<Queue, String> {
    let output = run("lpstat", ["-p", name, "-l"])?;
    if output.trim().is_empty() {
        return Err(format!("CUPS printer queue '{name}' was not found"));
    }
    Ok(Queue {
        name: name.to_owned(),
        model: queue_model(&output),
    })
}

fn run<const N: usize>(program: &str, args: [&str; N]) -> Result<String, String> {
    let output = Command::new(program)
        .args(args)
        .output()
        .map_err(|e| format!("Could not run {program}: {e}"))?;
    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).into_owned())
    } else {
        Err(command_error(&format!("{program} failed"), &output.stderr))
    }
}

fn parse_default_queue(output: &str) -> Option<String> {
    output
        .trim()
        .strip_prefix("system default destination: ")
        .map(str::trim)
        .filter(|name| !name.is_empty() && *name != "none")
        .map(str::to_owned)
}
fn queue_model(output: &str) -> String {
    output
        .lines()
        .find_map(|line| line.trim().strip_prefix("Description: "))
        .map(str::to_owned)
        .filter(|v| !v.is_empty())
        .or_else(|| output.lines().next().map(str::to_owned))
        .unwrap_or_else(|| "CUPS printer".to_string())
}
fn command_error(prefix: &str, stderr: &[u8]) -> String {
    let detail = String::from_utf8_lossy(stderr).trim().to_owned();
    if detail.is_empty() {
        prefix.to_string()
    } else {
        format!("{prefix}: {detail}")
    }
}

#[cfg(test)]
mod tests {
    use super::parse_default_queue;
    #[test]
    fn reads_cups_default_destination() {
        assert_eq!(
            parse_default_queue("system default destination: receipt-printer\n"),
            Some("receipt-printer".into())
        );
    }
    #[test]
    fn ignores_missing_default_destination() {
        assert_eq!(parse_default_queue("no system default destination\n"), None);
    }
}
