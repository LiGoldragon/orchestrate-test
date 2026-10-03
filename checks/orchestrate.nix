# A pure scenario: one Orchestrate Nexus on its own runtime and state
# directories with a fresh store, driven through its two stock clients. It
# runs in the build sandbox with no network, no credentials and no model.
#
# Drive: Lock (reason in guillemets) and Release on the ordinary socket,
# Configure on the meta socket, then tear down. Every reply is compared whole
# against the typed reply text the contract documents; the expected texts are
# written here, not computed through the clients.
{
  pkgs,
  flake,
  system,
  ...
}:
let
  orchestrate = flake.lib.components.orchestrate.forSystem system;
in
flake.lib.scenario
  {
    inherit pkgs;
    name = "orchestrate";
  }
  ''
    ${orchestrate.start}
    test -e "$XDG_STATE_HOME/${orchestrate.store}"

    lockedPath="$root/work/probe"
    lock="{ OrchestrateTestProbe 3ec648 [ $lockedPath ] «two words» }"

    expect observe-empty 0 'Observed.Locks.[]' \
      ${orchestrate.client} 'Observe.Locks'
    expect lock 0 "Locked.{ 1 OrchestrateTestProbe 3ec648 [ $lockedPath ] «two words» }" \
      ${orchestrate.client} "Lock.$lock"
    expect release 0 "Released.{ 1 OrchestrateTestProbe 3ec648 [ $lockedPath ] «two words» }" \
      ${orchestrate.client} 'Release.1'
    expect observe-released 0 'Observed.Locks.[]' \
      ${orchestrate.client} 'Observe.Locks'
    expect configure 0 "Configured.{ { $ORCHESTRATE_SOCKET $ORCHESTRATE_META_SOCKET } True }" \
      ${orchestrate.metaClient} "Configure.{ «$ORCHESTRATE_SOCKET» «$ORCHESTRATE_META_SOCKET» }"

    ${orchestrate.stop}
  ''
