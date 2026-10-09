// Claim 7: outside the defining module the private
// field is refused.
mod lock {
    pub struct LockPath(pub String);
    pub struct Paths(Vec<LockPath>);

    pub fn empty() -> Paths {
        Paths(Vec::new())
    }
}

pub fn main() {
    let mut paths = lock::empty();
    let path = lock::LockPath(String::from("/git"));
    paths.0.push(path);
}
