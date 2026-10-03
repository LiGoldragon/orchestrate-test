# A pure scenario: a store whose saved meta socket name is not the default,
# the live system's situation (witnesses/orchestrate-meta-socket.md in flow
# 3ec648). A fresh store is configured over the meta client to the legacy
# name `meta-orchestrate.sock` and restarted: the meta client must reach it
# only there. A Configure back to the default name and a restart must restore
# the default and leave the legacy name unserved.
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
    name = "orchestrate-old-meta-name";
  }
  ''
    ${orchestrate.start}
    defaultMeta="$XDG_RUNTIME_DIR/${orchestrate.metaSocket}"
    legacyMeta="$XDG_RUNTIME_DIR/orchestrate-nexus/meta-orchestrate.sock"
    refused="«Unix socket I/O failed: Connection refused (os error 111)»"
    test "$ORCHESTRATE_META_SOCKET" = "$defaultMeta"

    expect configure-legacy 0 "Configured.{ { $ORCHESTRATE_SOCKET $legacyMeta } True }" \
      ${orchestrate.metaClient} "Configure.{ «$ORCHESTRATE_SOCKET» «$legacyMeta» }"

    ${orchestrate.stop}
    export ORCHESTRATE_META_SOCKET="$legacyMeta"
    ${orchestrate.start}

    expect meta-at-legacy 0 "Configured.{ { $ORCHESTRATE_SOCKET $legacyMeta } True }" \
      ${orchestrate.metaClient} "Configure.{ «$ORCHESTRATE_SOCKET» «$legacyMeta» }"
    expectFailure meta-at-default-unreached 1 "Unreachable.{ $defaultMeta $refused }" \
      env ORCHESTRATE_META_SOCKET="$defaultMeta" ${orchestrate.metaClient} \
      "Configure.{ «$ORCHESTRATE_SOCKET» «$defaultMeta» }"
    expect ordinary-unaffected 0 'Observed.Locks.[]' \
      ${orchestrate.client} 'Observe.Locks'
    expect configure-default 0 "Configured.{ { $ORCHESTRATE_SOCKET $defaultMeta } True }" \
      ${orchestrate.metaClient} "Configure.{ «$ORCHESTRATE_SOCKET» «$defaultMeta» }"

    ${orchestrate.stop}
    export ORCHESTRATE_META_SOCKET="$defaultMeta"
    ${orchestrate.start}

    expect meta-at-default 0 "Configured.{ { $ORCHESTRATE_SOCKET $defaultMeta } True }" \
      ${orchestrate.metaClient} "Configure.{ «$ORCHESTRATE_SOCKET» «$defaultMeta» }"
    expectFailure meta-at-legacy-unreached 1 "Unreachable.{ $legacyMeta $refused }" \
      env ORCHESTRATE_META_SOCKET="$legacyMeta" ${orchestrate.metaClient} \
      "Configure.{ «$ORCHESTRATE_SOCKET» «$legacyMeta» }"

    ${orchestrate.stop}
  ''
