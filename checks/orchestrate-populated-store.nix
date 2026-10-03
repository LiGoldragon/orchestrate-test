# A pure scenario: the Nexus restarted on a populated store. A fresh store
# takes one Lock; the Nexus is stopped with TERM and started again on the same
# runtime and state directories. The restarted Nexus must still hold the Lock,
# go on numbering from it, and serve both sockets again; the previous run's
# socket files are still on disk, so only a reply on each proves a bind.
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
    name = "orchestrate-populated-store";
  }
  ''
    ${orchestrate.start}
    lockedPath="$root/work/probe"

    expect lock 0 "Locked.{ 1 OrchestrateTestProbe 3ec648 [ $lockedPath ] «two words» }" \
      ${orchestrate.client} "Lock.{ OrchestrateTestProbe 3ec648 [ $lockedPath ] «two words» }"

    ${orchestrate.stop}
    echo "stopped with TERM; restarting on the same directories"
    ${orchestrate.start}

    expect observe-after-restart 0 "Observed.Locks.[ { 1 OrchestrateTestProbe 3ec648 [ $lockedPath ] «two words» } ]" \
      ${orchestrate.client} 'Observe.Locks'
    expect lock-after-restart 0 "Locked.{ 2 SecondProbe 3ec648 [ $root/work/second ] «after restart» }" \
      ${orchestrate.client} "Lock.{ SecondProbe 3ec648 [ $root/work/second ] «after restart» }"
    expect meta-after-restart 0 "Configured.{ { $ORCHESTRATE_SOCKET $ORCHESTRATE_META_SOCKET } True }" \
      ${orchestrate.metaClient} "Configure.{ «$ORCHESTRATE_SOCKET» «$ORCHESTRATE_META_SOCKET» }"

    ${orchestrate.stop}
  ''
