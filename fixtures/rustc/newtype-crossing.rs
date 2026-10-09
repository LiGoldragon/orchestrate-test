// Claim 2: two newtypes are two types, so a LockName
// is refused where a FlowId is asked for.
struct FlowId(String);
struct LockName(String);

fn hold(_flow: FlowId) {}

pub fn main() {
    let lock = LockName(String::from("orchestrate"));
    hold(lock);
}
