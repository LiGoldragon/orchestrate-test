# A pure scenario: the pinned datom-codec's current derive, printing a String
# alias and a one-field String newtype. The crate under fixtures/datom-codec
# sits beside a copy of the datom-codec input and depends on it by path; its
# binary prints each value's datom text in guillemets, and the expected texts
# are written here.
{
  pkgs,
  flake,
  system,
  ...
}:
let
  rust = flake.lib.components.rust.forSystem system pkgs;
  inherit (flake.lib.components) datom-codec;
  fixture = ../fixtures/datom-codec;
  source = pkgs.runCommand "datom-codec-types-source" { } ''
    cp -r ${fixture} $out
    chmod u+w $out
    cp -r ${datom-codec.source} $out/datom-codec
  '';
  probe = rust.craneLib.buildPackage {
    pname = "datom-codec-types";
    version = "0.1.0";
    src = source;
    cargoLock = fixture + "/Cargo.lock";
    # Given apart from `src`: crane would otherwise read Cargo files out of
    # the assembled source, a derivation, at evaluation time.
    cargoVendorDir = rust.craneLib.vendorCargoDeps {
      cargoLock = fixture + "/Cargo.lock";
    };
    cargoToml = fixture + "/Cargo.toml";
    cargoArtifacts = null;
    strictDeps = true;
    doCheck = false;
  };
in
flake.lib.scenario
  {
    inherit pkgs;
    name = "datom-codec";
  }
  ''
    expect "datom-codec" 0 "alias «abc123»
    newtype «{ abc123 }»" ${probe}/bin/datom-codec-types
    mkdir -p $out
    ${probe}/bin/datom-codec-types > $out/observed
  ''
