// Claim 7: outside the defining module a pub field is
// reachable.
mod lock {
    pub struct LockPath(pub String);
    pub struct Paths(pub Vec<LockPath>);
}

pub fn main() {
    let mut paths = lock::Paths(Vec::new());
    let path = lock::LockPath(String::from("/git"));
    paths.0.push(path);
}
