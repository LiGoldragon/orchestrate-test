# A pure scenario: a store the previous release served resumes under the
# release under test. The previous Nexus (orchestrate-previous) opens a fresh
# store, takes a meta Configure and one Lock, and answers the client under
# test as well as its own, since the contract digests did not change. It is
# stopped with TERM, and the Nexus under test starts on the same runtime and
# state directories: it must hold the Lock, refuse its path, go on numbering
# from it, and keep ordinary Configure shut by the meta Configure the
# previous Nexus took.
{
  pkgs,
  flake,
  system,
  ...
}:
let
  previous = flake.lib.components.orchestrate-previous.forSystem system;
  orchestrate = flake.lib.components.orchestrate.forSystem system;
in
flake.lib.scenario
  {
    inherit pkgs;
    name = "orchestrate-previous-orchestrate";
  }
  ''
    ${previous.start}
    heldPath="$root/work/held"
    held="{ 1 Held f1c841 [ $heldPath ] «previous generation» }"

    expect previous-configure 0 "Configured.{ { $ORCHESTRATE_SOCKET $ORCHESTRATE_META_SOCKET } True }" \
      ${previous.metaClient} "Configure.{ «$ORCHESTRATE_SOCKET» «$ORCHESTRATE_META_SOCKET» }"
    expect previous-lock 0 "Locked.$held" \
      ${previous.client} "Lock.{ Held f1c841 [ $heldPath ] «previous generation» }"
    expect client-under-test-on-previous 0 "Observed.Locks.[ $held ]" \
      ${orchestrate.client} 'Observe.Locks'

    ${previous.stop}
    echo "previous Nexus stopped with TERM; starting the Nexus under test on its store"
    ${orchestrate.start}

    expect resumed-locks 0 "Observed.Locks.[ $held ]" \
      ${orchestrate.client} 'Observe.Locks'
    expect resumed-overlap 0 "LockRejected.PathOverlap.{ $heldPath $held }" \
      ${orchestrate.client} "Lock.{ Overlapping f1c841 [ $heldPath ] «same path» }"
    expect resumed-allocator 0 "Locked.{ 2 Next f1c841 [ $root/work/free ] «free path» }" \
      ${orchestrate.client} "Lock.{ Next f1c841 [ $root/work/free ] «free path» }"
    expect resumed-meta-configure-done 0 "ConfigurationRefused.{ MetaConfigureOccurred }" \
      ${orchestrate.client} "Configure.{ «$ORCHESTRATE_SOCKET» «$ORCHESTRATE_META_SOCKET» }"

    ${orchestrate.stop}
  ''
