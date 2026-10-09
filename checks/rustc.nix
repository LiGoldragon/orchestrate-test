# A pure scenario: the Rust compiler alone, judging the type, newtype and
# alias claims of the Ethos book. Each fixture under fixtures/rustc is
# compiled as a binary; the expectation names either `pass`, a run whose
# stdout must equal a given text, or the one error code the compile must
# fail with. The output records each fixture's observed outcome.
{
  pkgs,
  flake,
  system,
  ...
}:
let
  rust = flake.lib.components.rust.forSystem system pkgs;
  fixtures = ../fixtures/rustc;
in
flake.lib.scenario
  {
    inherit pkgs;
    name = "rustc";
  }
  ''
    observed="$root/observed"
    ${rust.rustc} --version | tee "$observed"

    # judge <fixture> <expectation> [<stdout>]
    judge() {
      fixture="$1" want="$2"
      binary="$root/$fixture"
      set +e
      ${rust.rustc} --edition 2024 -o "$binary" \
        "${fixtures}/$fixture.rs" 2>"$root/$fixture.stderr"
      code=$?
      set -e
      codes="$(grep -o '^error\[E[0-9]*\]' "$root/$fixture.stderr" \
        | sed 's/^error\[\(.*\)\]$/\1/' | sort -u | tr '\n' ' ')"
      codes="''${codes% }"
      if [ "$code" = 0 ]; then
        if [ "$want" = run ]; then
          got="$("$binary")"
          echo "$fixture: compiled; ran «$got»" | tee -a "$observed"
          [ "$got" = "$3" ] || { echo "$fixture: expected «$3»" >&2; exit 1; }
        else
          echo "$fixture: compiled" | tee -a "$observed"
          [ "$want" = pass ] || { echo "$fixture: expected $want" >&2; exit 1; }
        fi
      else
        echo "$fixture: refused with $codes" | tee -a "$observed"
        cat "$root/$fixture.stderr"
        [ "$codes" = "$want" ] || { echo "$fixture: expected $want" >&2; exit 1; }
      fi
    }

    judge alias-crossing pass
    judge newtype-crossing E0308
    judge alias-display E0117
    judge newtype-display pass
    judge newtype-size run "24 24"
    judge newtype-push E0599
    judge field-push-inside pass
    judge field-push-outside-private E0616
    judge field-push-outside-public pass

    mkdir -p $out
    cp "$observed" $out/observed
  ''
