# Orchestrate: the Orchestrate Nexus and its `orchestrate` / `orchestrate-meta`
# clients, taken from the pinned `orchestrate` input. The Nexus takes no
# arguments; it reads XDG_RUNTIME_DIR for its sockets and XDG_STATE_HOME for
# its store, so a scenario points both at its own root and gets a fresh store
# and its own sockets. The direct clients read ORCHESTRATE_SOCKET and
# ORCHESTRATE_META_SOCKET and have no default of their own.
{ inputs }:
{
  name = "orchestrate";

  forSystem = system: rec {
    package = inputs.orchestrate.packages.${system}.default;

    nexus = "${package}/bin/orchestrate-nexus";
    client = "${package}/bin/orchestrate";
    metaClient = "${package}/bin/orchestrate-meta";

    # Relative to XDG_RUNTIME_DIR and XDG_STATE_HOME, as orchestrate-nexus
    # derives them.
    ordinarySocket = "orchestrate-nexus/orchestrate.sock";
    metaSocket = "orchestrate-nexus/orchestrate-meta.sock";
    store = "orchestrate-nexus/orchestrate-nexus.sema";

    # Starts the Nexus against the caller's exported XDG_RUNTIME_DIR and
    # XDG_STATE_HOME, records its pid in `orchestrateNexusPid`, exports both
    # client socket variables, and waits (bounded) until both sockets are
    # bound. The caller must start from a fresh state root: a populated store
    # resumes the socket paths it persisted.
    start = ''
      mkdir -p "$XDG_RUNTIME_DIR" "$XDG_STATE_HOME"
      chmod 700 "$XDG_RUNTIME_DIR"
      ${nexus} &
      orchestrateNexusPid=$!
      export ORCHESTRATE_SOCKET="$XDG_RUNTIME_DIR/${ordinarySocket}"
      export ORCHESTRATE_META_SOCKET="$XDG_RUNTIME_DIR/${metaSocket}"
      for _ in $(seq 1 200); do
        test -S "$ORCHESTRATE_SOCKET" && test -S "$ORCHESTRATE_META_SOCKET" && break
        kill -0 "$orchestrateNexusPid" || { echo "orchestrate-nexus exited before binding" >&2; exit 1; }
        sleep 0.1
      done
      test -S "$ORCHESTRATE_SOCKET"
      test -S "$ORCHESTRATE_META_SOCKET"
    '';

    # Stops the Nexus and waits (bounded) for it to exit.
    stop = ''
      kill "$orchestrateNexusPid" 2>/dev/null || true
      for _ in $(seq 1 100); do
        kill -0 "$orchestrateNexusPid" 2>/dev/null || break
        sleep 0.1
      done
      if kill -0 "$orchestrateNexusPid" 2>/dev/null; then
        echo "orchestrate-nexus did not stop on TERM" >&2
        kill -9 "$orchestrateNexusPid" 2>/dev/null || true
        exit 1
      fi
      wait "$orchestrateNexusPid" 2>/dev/null || true
    '';
  };
}
