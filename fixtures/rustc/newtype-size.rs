// Claim 4: a newtype over String has String's size.
use std::mem::size_of;

#[allow(dead_code)]
struct FlowId(String);

fn main() {
    println!(
        "{} {}",
        size_of::<FlowId>(),
        size_of::<String>()
    );
}
