# A pure scenario: the two tools that open the store, orchestrate-upgrade-
# preflight and orchestrate-relocate, upgrade a store sema-engine wrote as the
# Nexus does, and print the Nexus's own upgrade line when they do. The last
# release whose store sema-engine wrote (orchestrate-sema, 0.37.0) opens a
# fresh store at orchestrate-nexus.sema, takes a meta Configure and one Lock,
# and is stopped with TERM; those bytes are kept aside and the original
# removed. A copy at the memory name is opened first by the preflight: it
# prints the upgrade line and the PathLock count, and a second preflight
# prints the count alone. A fresh copy at the memory name is opened first by
# orchestrate-relocate: it prints the upgrade line and declares the move, and
# the Nexus then serves the Lock 0.37.0 wrote with no upgrade line of its own.
{
  pkgs,
  flake,
  system,
  ...
}:
let
  sema = flake.lib.components.orchestrate-sema.forSystem system;
  orchestrate = flake.lib.components.orchestrate.forSystem system;
in
flake.lib.scenario
  {
    inherit pkgs;
    name = "orchestrate-sema-tools";
  }
  ''
    ${sema.start}
    semaStore="$XDG_STATE_HOME/orchestrate-nexus/orchestrate-nexus.sema"
    memoryStore="$XDG_STATE_HOME/orchestrate-nexus/orchestrate-nexus.memory"
    written="$root/written.sema"
    upgraded="orchestrate-nexus upgraded $memoryStore from the sema format to the memory format"
    heldPath="$root/work/held"
    held="{ 1 Held f1c841 [ $heldPath ] «sema generation» }"

    expect sema-configure 0 "Configured.{ { $ORCHESTRATE_SOCKET $ORCHESTRATE_META_SOCKET } True }" \
      ${sema.metaClient} "Configure.{ «$ORCHESTRATE_SOCKET» «$ORCHESTRATE_META_SOCKET» }"
    expect sema-lock 0 "Locked.$held" \
      ${sema.client} "Lock.{ Held f1c841 [ $heldPath ] «sema generation» }"

    ${sema.stop}
    mv "$semaStore" "$written"
    echo "0.37.0 stopped with TERM; the bytes it wrote kept aside, nothing at its own name"

    cp "$written" "$memoryStore"
    counted="active legacy PathLock rows: 0"
    expect preflight-first 0 "$upgraded"$'\n'"$counted" \
      ${orchestrate.preflight}
    expect preflight-second 0 "$counted" \
      ${orchestrate.preflight}

    rm "$memoryStore"
    cp "$written" "$memoryStore"
    ${orchestrate.relocate} > "$root/relocate.stdout"
    cat "$root/relocate.stdout"
    test "$(head -1 "$root/relocate.stdout")" = "$upgraded" || { echo "relocate: expected the upgrade line first" >&2; exit 1; }
    grep -qF "declared: the store bound at \"$semaStore\" is now at \"$memoryStore\"" "$root/relocate.stdout"

    ${orchestrate.start}
    if grep -q upgraded "$orchestrateNexusOutput"; then
      echo "after relocation: expected no upgrade, got: $(cat "$orchestrateNexusOutput")" >&2
      exit 1
    fi
    expect relocated-locks 0 "Observed.Locks.[ $held ]" \
      ${orchestrate.client} 'Observe.Locks'

    ${orchestrate.stop}
  ''
