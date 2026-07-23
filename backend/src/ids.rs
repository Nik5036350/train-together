use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

// Mirrors the frontend's src/lib/ids.js and the old Kotlin Ids.uid:
// `{prefix}_{base36(millis)}_{base36(counter)}`. Keeps ids short and readable
// and keeps the JSON shape identical.
static COUNTER: AtomicU64 = AtomicU64::new(0);

pub fn uid(prefix: &str) -> String {
    let n = COUNTER.fetch_add(1, Ordering::Relaxed) + 1;
    let millis = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64;
    format!("{}_{}_{}", prefix, to_base36(millis), to_base36(n))
}

fn to_base36(mut v: u64) -> String {
    if v == 0 {
        return "0".to_string();
    }
    const DIGITS: &[u8; 36] = b"0123456789abcdefghijklmnopqrstuvwxyz";
    let mut buf = Vec::new();
    while v > 0 {
        buf.push(DIGITS[(v % 36) as usize]);
        v /= 36;
    }
    buf.reverse();
    String::from_utf8(buf).unwrap()
}
