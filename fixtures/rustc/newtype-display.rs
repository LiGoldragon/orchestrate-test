// Claim 3, newtype case: FlowId is local, so the impl
// is accepted.
use std::fmt;

struct FlowId(String);

impl fmt::Display for FlowId {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        f.write_str(&self.0)
    }
}

pub fn main() {
    let flow = FlowId(String::from("abc123"));
    println!("{flow}");
}
