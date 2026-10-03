# Orchestrate: the Orchestrate Nexus and its `orchestrate` / `orchestrate-meta`
# clients, taken from a pinned orchestrate input: `orchestrate` for the
# generation under test, `orchestrate-previous` for the release before it,
# `orchestrate-live` for the release the live Nexus runs. The Nexus takes no
# arguments; it reads XDG_RUNTIME_DIR for its sockets and XDG_STATE_HOME for
# its store, so a scenario points both at its own root and gets a fresh store
# and its own sockets. The direct clients read ORCHESTRATE_SOCKET and
# ORCHESTRATE_META_SOCKET and have no default of their own.
{ name, input }:
{
  inherit name;

  forSystem = system: rec {
    package = input.packages.${system}.default;

    nexus = "${package}/bin/orchestrate-nexus";
    client = "${package}/bin/orchestrate";
    metaClient = "${package}/bin/orchestrate-meta";

    # Relative to XDG_RUNTIME_DIR and XDG_STATE_HOME, as orchestrate-nexus
    # derives them for a fresh store.
    ordinarySocket = "orchestrate-nexus/orchestrate.sock";
    metaSocket = "orchestrate-nexus/orchestrate-meta.sock";
    store = "orchestrate-nexus/orchestrate-nexus.sema";

    # Starts the Nexus against the caller's exported XDG_RUNTIME_DIR and
    # XDG_STATE_HOME and records its pid in `orchestrateNexusPid`. It waits
    # (bounded) on the Nexus's own `orchestrate-nexus ready` line, printed
    # only once both sockets its store names are bound, never on a socket
    # file existing: on a restart the previous run's files are still there.
    # It exports the default client socket paths unless the caller already
    # set them; a scenario whose store names other paths sets them itself.
    start = ''
      mkdir -p "$XDG_RUNTIME_DIR" "$XDG_STATE_HOME"
      chmod 700 "$XDG_RUNTIME_DIR"
      orchestrateNexusOutput="$XDG_RUNTIME_DIR/orchestrate-nexus.stdout"
      : > "$orchestrateNexusOutput"
      ${nexus} > "$orchestrateNexusOutput" &
      orchestrateNexusPid=$!
      export ORCHESTRATE_SOCKET="''${ORCHESTRATE_SOCKET:-$XDG_RUNTIME_DIR/${ordinarySocket}}"
      export ORCHESTRATE_META_SOCKET="''${ORCHESTRATE_META_SOCKET:-$XDG_RUNTIME_DIR/${metaSocket}}"
      for _ in $(seq 1 200); do
        grep -qx 'orchestrate-nexus ready' "$orchestrateNexusOutput" && break
        kill -0 "$orchestrateNexusPid" || { echo "orchestrate-nexus exited before binding" >&2; exit 1; }
        sleep 0.1
      done
      grep -qx 'orchestrate-nexus ready' "$orchestrateNexusOutput"
      echo "orchestrate-nexus ready (pid $orchestrateNexusPid)"
    '';

    # Starts the Nexus like `start`, but an exit is an outcome rather than a
    # failure: it waits (bounded) until the Nexus prints its ready line or
    # exits, and sets `orchestrateNexusOutcome` to `ready` or `exited <code>`,
    # with the Nexus's stderr in `$orchestrateNexusError`. A scenario that
    # must state what a Nexus answers a store with, refusal included, uses
    # this and asserts the outcome itself.
    attempt = ''
      mkdir -p "$XDG_RUNTIME_DIR" "$XDG_STATE_HOME"
      chmod 700 "$XDG_RUNTIME_DIR"
      orchestrateNexusOutput="$XDG_RUNTIME_DIR/orchestrate-nexus.stdout"
      orchestrateNexusError="$XDG_RUNTIME_DIR/orchestrate-nexus.stderr"
      : > "$orchestrateNexusOutput"
      : > "$orchestrateNexusError"
      ${nexus} > "$orchestrateNexusOutput" 2> "$orchestrateNexusError" &
      orchestrateNexusPid=$!
      export ORCHESTRATE_SOCKET="''${ORCHESTRATE_SOCKET:-$XDG_RUNTIME_DIR/${ordinarySocket}}"
      export ORCHESTRATE_META_SOCKET="''${ORCHESTRATE_META_SOCKET:-$XDG_RUNTIME_DIR/${metaSocket}}"
      orchestrateNexusOutcome=""
      for _ in $(seq 1 200); do
        if grep -qx 'orchestrate-nexus ready' "$orchestrateNexusOutput"; then
          orchestrateNexusOutcome=ready
          break
        fi
        if ! kill -0 "$orchestrateNexusPid" 2>/dev/null; then
          set +e
          wait "$orchestrateNexusPid"
          orchestrateNexusOutcome="exited $?"
          set -e
          break
        fi
        sleep 0.1
      done
      echo "orchestrate-nexus outcome: ''${orchestrateNexusOutcome:-neither ready nor exited in 20 s}"
      echo "orchestrate-nexus stderr: «$(cat "$orchestrateNexusError")»"
    '';

    # Stops the Nexus with TERM and waits (bounded) for it to exit.
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
