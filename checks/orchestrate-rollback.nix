# A pure scenario: the morning rollback path. The release under test
# (orchestrate, 0.37.0) opens a fresh store, takes a meta Configure and one
# Lock, and is stopped with TERM; the release the live Nexus runs
# (orchestrate-live, 0.35.0) then starts on the same runtime and state
# directories. The scenario states what 0.35.0 answers that store with: it
# resumes it, holding the Lock, refusing its path, numbering on from it,
# keeping ordinary Configure shut, and serving the meta socket the store
# names. Witnessed in flow f1c841
# (reports/orchestrate-rollback-witness.md); were 0.35.0 to refuse the store,
# its exit and stderr would be the expectation here instead.
{
  pkgs,
  flake,
  system,
  ...
}:
let
  orchestrate = flake.lib.components.orchestrate.forSystem system;
  live = flake.lib.components.orchestrate-live.forSystem system;
in
flake.lib.scenario
  {
    inherit pkgs;
    name = "orchestrate-rollback";
  }
  ''
    ${orchestrate.start}
    heldPath="$root/work/held"
    held="{ 1 Held f1c841 [ $heldPath ] «under test» }"

    expect configure 0 "Configured.{ { $ORCHESTRATE_SOCKET $ORCHESTRATE_META_SOCKET } True }" \
      ${orchestrate.metaClient} "Configure.{ «$ORCHESTRATE_SOCKET» «$ORCHESTRATE_META_SOCKET» }"
    expect lock 0 "Locked.$held" \
      ${orchestrate.client} "Lock.{ Held f1c841 [ $heldPath ] «under test» }"

    ${orchestrate.stop}
    echo "Nexus under test stopped with TERM; starting the live release on its store"
    ${live.attempt}

    test "$orchestrateNexusOutcome" = ready || { echo "outcome: expected ready" >&2; exit 1; }
    expect live-locks 0 "Observed.Locks.[ $held ]" \
      ${live.client} 'Observe.Locks'
    expect live-overlap 0 "LockRejected.PathOverlap.{ $heldPath $held }" \
      ${live.client} "Lock.{ Overlapping f1c841 [ $heldPath ] «same path» }"
    expect live-allocator 0 "Locked.{ 2 Next f1c841 [ $root/work/free ] «free path» }" \
      ${live.client} "Lock.{ Next f1c841 [ $root/work/free ] «free path» }"
    expect live-ordinary-configure-shut 0 "ConfigurationRefused.{ MetaConfigureOccurred }" \
      ${live.client} "Configure.{ «$ORCHESTRATE_SOCKET» «$ORCHESTRATE_META_SOCKET» }"
    expect live-meta 0 "Configured.{ { $ORCHESTRATE_SOCKET $ORCHESTRATE_META_SOCKET } True }" \
      ${live.metaClient} "Configure.{ «$ORCHESTRATE_SOCKET» «$ORCHESTRATE_META_SOCKET» }"

    ${live.stop}
  ''
