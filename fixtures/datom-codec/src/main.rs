// Claim 5: through the derive, an alias of String
// prints as the string itself, and a one-field
// newtype prints as a one-position struct.
use datom_codec::Datomizable;
use protos::{Protosizable, Textualizable};

mod alias {
    pub type FlowId = String;
}

mod newtype {
    use datom_codec::Datomizable;

    #[derive(Datomizable)]
    pub struct FlowId(pub String);
}

fn main() {
    let alias: alias::FlowId = String::from("abc123");
    let newtype = newtype::FlowId(String::from("abc123"));
    println!(
        "alias «{}»",
        alias.datomize(vec![]).protosize().textualize()
    );
    println!(
        "newtype «{}»",
        newtype.datomize(vec![]).protosize().textualize()
    );
}
