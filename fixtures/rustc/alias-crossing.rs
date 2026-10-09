// Claim 1: an alias names the same type, so a LockName
// is accepted where a FlowId is asked for.
type FlowId = String;
type LockName = String;

fn hold(_flow: FlowId) {}

pub fn main() {
    let lock: LockName = String::from("orchestrate");
    hold(lock);
}
