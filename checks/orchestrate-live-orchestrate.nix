# A pure scenario: the live host's store, forward. The release the live Nexus
# runs (orchestrate-live, 0.35.0) opens a fresh store, is configured over its
# meta client to the legacy meta socket name `meta-orchestrate.sock` (the name
# the live store saves) and takes one Lock; it is stopped with TERM and the
# release under test (orchestrate, 0.37.0) starts on the same directories. It
# must hold the Lock and answer a meta Configure through the legacy name.
{
  pkgs,
  flake,
  system,
  ...
}:
let
  live = flake.lib.components.orchestrate-live.forSystem system;
  orchestrate = flake.lib.components.orchestrate.forSystem system;
in
flake.lib.scenario
  {
    inherit pkgs;
    name = "orchestrate-live-orchestrate";
  }
  ''
    ${live.start}
    legacyMeta="$XDG_RUNTIME_DIR/orchestrate-nexus/meta-orchestrate.sock"
    heldPath="$root/work/held"
    held="{ 1 Held f1c841 [ $heldPath ] «live generation» }"

    expect live-configure-legacy 0 "Configured.{ { $ORCHESTRATE_SOCKET $legacyMeta } True }" \
      ${live.metaClient} "Configure.{ «$ORCHESTRATE_SOCKET» «$legacyMeta» }"
    expect live-lock 0 "Locked.$held" \
      ${live.client} "Lock.{ Held f1c841 [ $heldPath ] «live generation» }"

    ${live.stop}
    export ORCHESTRATE_META_SOCKET="$legacyMeta"
    echo "live release stopped with TERM; starting the Nexus under test on its store"
    ${orchestrate.attempt}

    test "$orchestrateNexusOutcome" = ready || { echo "outcome: expected ready" >&2; exit 1; }
    expect resumed-locks 0 "Observed.Locks.[ $held ]" \
      ${orchestrate.client} 'Observe.Locks'
    expect resumed-allocator 0 "Locked.{ 2 Next f1c841 [ $root/work/free ] «free path» }" \
      ${orchestrate.client} "Lock.{ Next f1c841 [ $root/work/free ] «free path» }"
    expect resumed-meta-at-legacy 0 "Configured.{ { $ORCHESTRATE_SOCKET $legacyMeta } True }" \
      ${orchestrate.metaClient} "Configure.{ «$ORCHESTRATE_SOCKET» «$legacyMeta» }"

    ${orchestrate.stop}
  ''
