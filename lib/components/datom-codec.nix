# datom-codec: the source of the pinned datom-codec input. A scenario places
# it beside its own crate and depends on it by path, so the codec under test
# is the input, never a second pin in a Cargo manifest.
{ input }:
{
  source = input.outPath;
}
