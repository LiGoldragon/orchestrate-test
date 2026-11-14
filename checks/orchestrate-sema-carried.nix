# A pure scenario: a store sema-engine wrote is upgraded on open even when the
# open then refuses it, and the Nexus says so either way. The last release
# whose store sema-engine wrote (orchestrate-sema, 0.37.0) opens a fresh store
# at orchestrate-nexus.sema, takes a meta Configure and one Lock, and is
# stopped with TERM. The file is then copied to orchestrate-nexus.memory and
# the original removed: a second file, so the store's recorded situation names
# a file it is not. The Nexus under test upgrades it, prints the upgrade line,
# and refuses it as a carried store. A second attempt finds a memory store:
# no upgrade line, the same refusal. orchestrate-relocate declares the move,
# and the Nexus then serves the Lock as 0.37.0 wrote it.
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
    name = "orchestrate-sema-carried";
  }
  ''
    ${sema.start}
    semaStore="$XDG_STATE_HOME/orchestrate-nexus/orchestrate-nexus.sema"
    memoryStore="$XDG_STATE_HOME/orchestrate-nexus/orchestrate-nexus.memory"
    upgraded="orchestrate-nexus upgraded $memoryStore from the sema format to the memory format"
    carried="records that it was bound at \"$semaStore\" as a different file from the one opened at \"$memoryStore\""
    heldPath="$root/work/held"
    held="{ 1 Held f1c841 [ $heldPath ] «sema generation» }"

    expect sema-configure 0 "Configured.{ { $ORCHESTRATE_SOCKET $ORCHESTRATE_META_SOCKET } True }" \
      ${sema.metaClient} "Configure.{ «$ORCHESTRATE_SOCKET» «$ORCHESTRATE_META_SOCKET» }"
    expect sema-lock 0 "Locked.$held" \
      ${sema.client} "Lock.{ Held f1c841 [ $heldPath ] «sema generation» }"

    ${sema.stop}
    cp "$semaStore" "$memoryStore"
    rm "$semaStore"
    echo "0.37.0 stopped with TERM; its sema store copied to the memory name as a second file"

    ${orchestrate.attempt}
    test "$orchestrateNexusOutcome" = "exited 1" || { echo "first open: expected exited 1" >&2; exit 1; }
    grep -qx "$upgraded" "$orchestrateNexusOutput" || { echo "first open: no upgrade line" >&2; exit 1; }
    grep -qF "$carried" "$orchestrateNexusError" || { echo "first open: expected the carried-store refusal" >&2; exit 1; }
    echo "first open: upgraded, then refused as carried"

    ${orchestrate.attempt}
    test "$orchestrateNexusOutcome" = "exited 1" || { echo "second open: expected exited 1" >&2; exit 1; }
    if grep -q upgraded "$orchestrateNexusOutput"; then
      echo "second open: expected no upgrade, got: $(cat "$orchestrateNexusOutput")" >&2
      exit 1
    fi
    grep -qF "$carried" "$orchestrateNexusError" || { echo "second open: expected the carried-store refusal" >&2; exit 1; }
    echo "second open: a memory store, refused as carried, no upgrade"

    ${orchestrate.relocate} > "$root/relocate.stdout"
    cat "$root/relocate.stdout"
    grep -qF "declared: the store bound at \"$semaStore\" is now at \"$memoryStore\"" "$root/relocate.stdout"

    ${orchestrate.start}
    if grep -q upgraded "$orchestrateNexusOutput"; then
      echo "after relocation: expected no upgrade, got: $(cat "$orchestrateNexusOutput")" >&2
      exit 1
    fi
    expect relocated-locks 0 "Observed.Locks.[ $held ]" \
      ${orchestrate.client} 'Observe.Locks'
    expect relocated-allocator 0 "Locked.{ 2 Next f1c841 [ $root/work/free ] «free path» }" \
      ${orchestrate.client} "Lock.{ Next f1c841 [ $root/work/free ] «free path» }"

    ${orchestrate.stop}
  ''
