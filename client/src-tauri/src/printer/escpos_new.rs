use super::Receipt;
use base64::{engine::general_purpose::STANDARD, Engine as _};
use image::{imageops::FilterType, ImageReader, Limits};
use std::io::Cursor;

const W: usize = 48;
const PRINTER_WIDTH_DOTS: u32 = 576;
const MAX_LOGO_WIDTH_DOTS: u32 = 384;
const MAX_LOGO_HEIGHT_DOTS: u32 = 256;
const MAX_LOGO_BYTES: usize = 750 * 1024;
pub fn receipt(r: &Receipt) -> Vec<u8> {
 let mut d=vec![0x1b,0x40,0x1b,0x61,0x01]; logo(&mut d, &r.logo); bold(&mut d,true); centered(&mut d,&r.company); bold(&mut d,false); centered(&mut d,&r.store); centered(&mut d,&r.store_address); centered(&mut d,&r.store_slogan); left(&mut d); optional(&mut d,&r.labels.rnc,&r.company_id); if r.copy { center(&mut d); bold(&mut d,true); centered(&mut d,&r.labels.copy); bold(&mut d,false); left(&mut d); } sep(&mut d); pair(&mut d,&r.labels.fiscal_sequence,&r.number); pair(&mut d,&r.labels.date,&r.date_time); optional(&mut d,&r.labels.store,&r.store); optional(&mut d,&r.labels.customer,&r.customer); optional(&mut d,&r.labels.document,&r.customer_document); optional(&mut d,&r.labels.cashier,&r.cashier); center(&mut d); centered(&mut d,&r.sequence_description); left(&mut d); sep(&mut d); line(&mut d,&r.labels.item_header);
 for i in &r.items { wrapped(&mut d,&i.name); if !i.sku.is_empty(){line(&mut d,&format!("{}: {}",r.labels.sku,i.sku));} item_amounts(&mut d,&format!("{} x {}",qty(i.qty),money(i.price,&r.language)),&money(i.tax,&r.language),&money(i.total,&r.language)); if i.discount>0.0{pair(&mut d,&r.labels.discount,&money(i.discount,&r.language));} }
 sep(&mut d); pair(&mut d,&r.labels.subtotal,&money(r.subtotal,&r.language)); if r.tax>0.0{pair(&mut d,&r.labels.tax,&money(r.tax,&r.language));} if r.line_discount>0.0{pair(&mut d,&r.labels.discount,&format!("-{}",money(r.line_discount,&r.language)));} if r.discount>0.0{pair(&mut d,&r.labels.discount,&format!("-{}",money(r.discount,&r.language)));} if r.delivery>0.0{pair(&mut d,&r.labels.delivery,&money(r.delivery,&r.language));} bold(&mut d,true); pair(&mut d,&r.labels.total,&money(r.total,&r.language)); bold(&mut d,false); if r.discount_total>0.0 { pair(&mut d,&r.labels.savings,&money(r.discount_total,&r.language)); } pair(&mut d,&r.labels.items,&r.items.len().to_string());
 if !r.payments.is_empty()||r.paid>0.0||r.balance>0.0||r.change>0.0 {sep(&mut d); for p in &r.payments {pair(&mut d,&p.method,&money(p.amount,&r.language));} if r.paid>0.0{pair(&mut d,&r.labels.paid,&money(r.paid,&r.language));} if r.change>0.0{pair(&mut d,&r.labels.change,&money(r.change,&r.language));} if r.balance>0.0{pair(&mut d,&r.labels.balance,&money(r.balance.max(0.0),&r.language));}}
 sep(&mut d); center(&mut d);centered(&mut d,&r.labels.thank_you);centered(&mut d,&format!("{}: {}",r.labels.receipt,r.number));d.extend_from_slice(b"\n\n\n");d.extend_from_slice(&[0x1d,0x56,0x00]);d
}
fn logo(d: &mut Vec<u8>, encoded: &str) {
 if encoded.trim().is_empty() { return; }
 match raster_logo(encoded) { Ok(data) => d.extend_from_slice(&data), Err(error) => eprintln!("Skipping receipt logo: {error}"), }
}
fn raster_logo(encoded: &str) -> Result<Vec<u8>, String> {
 let (metadata, payload) = encoded.split_once(',').ok_or("logo is not a data URI")?;
 if !metadata.starts_with("data:image/") || !metadata.ends_with(";base64") { return Err("logo is not a Base64 image data URI".into()); }
 let bytes = STANDARD.decode(payload.trim()).map_err(|error| format!("could not decode Base64 logo: {error}"))?;
 if bytes.len() > MAX_LOGO_BYTES { return Err("decoded logo exceeds the 750 KB receipt limit".into()); }
 let mut reader = ImageReader::new(Cursor::new(bytes)).with_guessed_format().map_err(|error| format!("could not identify logo image: {error}"))?;
 let mut limits = Limits::default();
 limits.max_image_width = Some(4_096);
 limits.max_image_height = Some(4_096);
 limits.max_alloc = Some(16 * 1024 * 1024);
 reader.limits(limits);
 let image = reader.decode().map_err(|error| format!("could not decode logo image: {error}"))?;
 let image = image.resize(MAX_LOGO_WIDTH_DOTS, MAX_LOGO_HEIGHT_DOTS, FilterType::Lanczos3).to_rgba8();
 let (width, height) = image.dimensions();
 if width == 0 || height == 0 { return Err("logo image has no dimensions".into()); }
 let bytes_per_row = (PRINTER_WIDTH_DOTS / 8) as usize;
 let mut raster = Vec::with_capacity(bytes_per_row * height as usize);
 let offset = (PRINTER_WIDTH_DOTS - width) / 2;
 for y in 0..height { for byte_x in 0..bytes_per_row { let mut byte = 0_u8; for bit in 0..8 { let x = byte_x as u32 * 8 + bit; if x >= offset && x < offset + width { let pixel = image.get_pixel(x - offset, y); let alpha = u32::from(pixel[3]); let luminance = (u32::from(pixel[0]) * 299 + u32::from(pixel[1]) * 587 + u32::from(pixel[2]) * 114) / 1000; let on_white = (luminance * alpha + 255 * (255 - alpha)) / 255; if on_white < 160 { byte |= 0x80 >> bit; } } } raster.push(byte); } }
 let row_bytes = bytes_per_row as u16;
 let height = height as u16;
 let mut command = vec![0x1d, 0x76, 0x30, 0x00, row_bytes as u8, (row_bytes >> 8) as u8, height as u8, (height >> 8) as u8];
 command.extend_from_slice(&raster);
 Ok(command)
}
fn left(d:&mut Vec<u8>){d.extend_from_slice(&[0x1b,0x61,0]);} fn center(d:&mut Vec<u8>){d.extend_from_slice(&[0x1b,0x61,1]);} fn bold(d:&mut Vec<u8>,on:bool){d.extend_from_slice(&[0x1b,0x45,u8::from(on)]);} fn line(d:&mut Vec<u8>,v:&str){d.extend_from_slice(v.as_bytes());d.push(b'\n');} fn sep(d:&mut Vec<u8>){line(d,&"-".repeat(W));} fn pair(d:&mut Vec<u8>,l:&str,v:&str){let gap=W.saturating_sub(l.len()+v.len()).max(1);line(d,&format!("{l}{}{v}"," ".repeat(gap)));} fn optional(d:&mut Vec<u8>,l:&str,v:&str){if !v.trim().is_empty(){pair(d,l,v);}}
fn item_amounts(d:&mut Vec<u8>,description:&str,tax:&str,total:&str){line(d,&format!("{:<22}{:>10}{:>16}",clip(description,22),clip(tax,10),clip(total,16)));} fn clip(value:&str,width:usize)->String{value.chars().take(width).collect()}
// ESC/POS alignment owns horizontal centering. Adding whitespace here would
// center an already-offset line, which is why the previous header drifted right.
fn centered(d:&mut Vec<u8>,v:&str){if !v.trim().is_empty(){for s in wrap(v){line(d,&s);}}} fn wrapped(d:&mut Vec<u8>,v:&str){for s in wrap(v){line(d,&s);}}
fn wrap(v:&str)->Vec<String>{let(mut out,mut line)=(vec![],String::new());for word in v.split_whitespace(){if !line.is_empty()&&line.len()+word.len()+1>W{out.push(line);line=String::new();}if !line.is_empty(){line.push(' ');}line.push_str(word);}if !line.is_empty(){out.push(line);}out} fn qty(v:f64)->String{if v.fract()==0.0{format!("{v:.0}")}else{format!("{v:.2}")}} fn money(v:f64,lang:&str)->String{let f=format!("{:.2}",v.abs());let(w,frac)=f.split_once('.').unwrap_or((&f,"00"));let sep=if lang=="por"{'.'}else{','};let g=w.chars().rev().enumerate().fold(String::new(),|mut a,(i,c)|{if i>0&&i%3==0{a.push(sep);}a.push(c);a}).chars().rev().collect::<String>();let sign=if v.is_sign_negative(){"-"}else{""};if lang=="por"{format!("{sign}$ {g},{frac}")}else{format!("{sign}${g}.{frac}")}}
