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
                "  {:.2} x ${:.2} = ${:.2}",
                item.qty,
                item.price,
                item.qty * item.price
            ),
        );
    }
    append_line(&mut data, &"-".repeat(LINE_WIDTH));
    bold(&mut data, true);
    append_line(&mut data, &format!("TOTAL: ${:.2}", receipt.total));
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
