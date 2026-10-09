// Claim 6: a newtype does not carry its field's
// methods, so Paths has no push.
struct LockPath(String);
struct Paths(Vec<LockPath>);

pub fn main() {
    let mut paths = Paths(Vec::new());
    let path = LockPath(String::from("/git"));
    paths.push(path);
}
