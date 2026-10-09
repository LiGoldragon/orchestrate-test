// Claim 3, alias case: Display is foreign and String is
// foreign, so the orphan rule refuses the impl.
use std::fmt;

type FlowId = String;

impl fmt::Display for FlowId {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        f.write_str("flow")
    }
}

pub fn main() {}
