# Rust: the compiler and crane, taken from the rust-build that the pinned
# datom-codec input builds with, so a scenario compiles with the toolchain
# the codec itself is checked under.
{ input }:
{
  forSystem =
    system: pkgs:
    let
      rust = input.inputs.rust-build.lib.${system}.fromPkgs pkgs;
    in
    {
      inherit (rust) craneLib toolchain;
      rustc = "${rust.toolchain}/bin/rustc";
    };
}
