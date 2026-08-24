use super::Receipt;

const LINE_WIDTH: usize = 48;

pub fn receipt(receipt: &Receipt) -> Vec<u8> {
    let mut data = initialize_and_center();
    bold(&mut data, true);
    data.extend_from_slice(b"POS\n");
    bold(&mut data, false);
    data.extend_from_slice(b"\n");
    left(&mut data);
    append_line(&mut data, &format!("Receipt: {}", receipt.number));
    append_line(&mut data, &"-".repeat(LINE_WIDTH));
    for item in &receipt.items {
        append_line(&mut data, &item.name);
        append_line(
            &mut data,
            &format!(
                "  {:.2} x {} = {}",
                item.qty,
                currency(item.price, &receipt.language),
                currency(item.qty * item.price, &receipt.language)
            ),
        );
    }
    append_line(&mut data, &"-".repeat(LINE_WIDTH));
    bold(&mut data, true);
    append_line(&mut data, &format!("TOTAL: {}", currency(receipt.total, &receipt.language)));
    bold(&mut data, false);
    data.extend_from_slice(b"\n\n\n");
    cut(&mut data);
    data
}

fn initialize_and_center() -> Vec<u8> {
    vec![0x1b, 0x40, 0x1b, 0x61, 0x01]
}
fn left(data: &mut Vec<u8>) {
    data.extend_from_slice(&[0x1b, 0x61, 0x00]);
}
fn bold(data: &mut Vec<u8>, enabled: bool) {
    data.extend_from_slice(&[0x1b, 0x45, u8::from(enabled)]);
}
fn cut(data: &mut Vec<u8>) {
    data.extend_from_slice(&[0x1d, 0x56, 0x00]);
}
fn append_line(data: &mut Vec<u8>, line: &str) {
    data.extend_from_slice(line.as_bytes());
    data.push(b'\n');
}

fn currency(value: f64, language: &str) -> String {
    let formatted = format!("{:.2}", value.abs());
    let (whole, fraction) = formatted.split_once('.').unwrap_or((&formatted, "00"));
    let separator = if language == "por" { '.' } else { ',' };
    let grouped = whole
        .chars()
        .rev()
        .enumerate()
        .fold(String::new(), |mut result, (index, character)| {
            if index > 0 && index % 3 == 0 { result.push(separator); }
            result.push(character);
            result
        })
        .chars()
        .rev()
        .collect::<String>();
    let sign = if value.is_sign_negative() { "-" } else { "" };
    if language == "por" { format!("{sign}$ {grouped},{fraction}") } else { format!("{sign}${grouped}.{fraction}") }
}
