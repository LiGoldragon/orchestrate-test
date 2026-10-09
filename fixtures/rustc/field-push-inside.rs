// Claim 7: inside the defining module the private
// field is reachable.
mod lock {
    pub struct LockPath(pub String);
    pub struct Paths(Vec<LockPath>);

    pub fn gather() -> Paths {
        let mut paths = Paths(Vec::new());
        let path = LockPath(String::from("/git"));
        paths.0.push(path);
        paths
    }
}

pub fn main() {
    let _paths = lock::gather();
}
