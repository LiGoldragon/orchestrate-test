# A pure scenario: a store sema-engine wrote is upgraded on open. The last
# release whose store sema-engine wrote (orchestrate-sema, 0.37.0) opens a
# fresh store at its own name, orchestrate-nexus.sema, takes a meta Configure
# and one Lock, and is stopped with TERM. The release under test then starts
# on the same directories: it moves the file to orchestrate-nexus.memory,
# upgrades it from the sema format to the memory format, says so before its
# ready line, and serves it as it was written: the Lock, its path refused, the
# allocator numbering on, and ordinary Configure shut. A second start finds a
# memory store and upgrades nothing.
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
    name = "orchestrate-sema-orchestrate";
  }
  ''
    ${sema.start}
    semaStore="$XDG_STATE_HOME/orchestrate-nexus/orchestrate-nexus.sema"
    memoryStore="$XDG_STATE_HOME/orchestrate-nexus/orchestrate-nexus.memory"
    upgraded="orchestrate-nexus upgraded $memoryStore from the sema format to the memory format"
    heldPath="$root/work/held"
    held="{ 1 Held f1c841 [ $heldPath ] «sema generation» }"

    expect sema-configure 0 "Configured.{ { $ORCHESTRATE_SOCKET $ORCHESTRATE_META_SOCKET } True }" \
      ${sema.metaClient} "Configure.{ «$ORCHESTRATE_SOCKET» «$ORCHESTRATE_META_SOCKET» }"
    expect sema-lock 0 "Locked.$held" \
      ${sema.client} "Lock.{ Held f1c841 [ $heldPath ] «sema generation» }"
    expect sema-observe 0 "Observed.Locks.[ $held ]" \
      ${sema.client} 'Observe.Locks'

    ${sema.stop}
    test -f "$semaStore"
    test ! -e "$memoryStore"
    echo "0.37.0 stopped with TERM on its sema store; starting the Nexus under test"
    ${orchestrate.start}

    grep -qx "$upgraded" "$orchestrateNexusOutput"
    echo "first open: $(head -1 "$orchestrateNexusOutput")"
    test -f "$memoryStore"
    test ! -e "$semaStore"
    expect upgraded-locks 0 "Observed.Locks.[ $held ]" \
      ${orchestrate.client} 'Observe.Locks'
    expect upgraded-overlap 0 "LockRejected.PathOverlap.{ $heldPath $held }" \
      ${orchestrate.client} "Lock.{ Overlapping f1c841 [ $heldPath ] «same path» }"
    expect upgraded-allocator 0 "Locked.{ 2 Next f1c841 [ $root/work/free ] «free path» }" \
      ${orchestrate.client} "Lock.{ Next f1c841 [ $root/work/free ] «free path» }"
    expect upgraded-meta-configure-done 0 "ConfigurationRefused.{ MetaConfigureOccurred }" \
      ${orchestrate.client} "Configure.{ «$ORCHESTRATE_SOCKET» «$ORCHESTRATE_META_SOCKET» }"

    ${orchestrate.stop}
    echo "stopped; starting the Nexus under test again on the upgraded store"
    ${orchestrate.start}

    if grep -q upgraded "$orchestrateNexusOutput"; then
      echo "second open: expected no upgrade, got: $(cat "$orchestrateNexusOutput")" >&2
      exit 1
    fi
    echo "second open: $(cat "$orchestrateNexusOutput")"
    expect reopened-locks 0 "Observed.Locks.[ $held { 2 Next f1c841 [ $root/work/free ] «free path» } ]" \
      ${orchestrate.client} 'Observe.Locks'

    ${orchestrate.stop}
  ''
