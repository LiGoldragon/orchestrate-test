# orchestrate-claude — a semi-sandbox: a light-model Claude Code flow loads the
# `orchestrate` skill and does one Lock/Release round trip against its own
# Orchestrate Nexus. It needs the living's Claude login and the network, so it
# is a runner, never a check, and it refuses to run unless
# ORCHESTRATE_TEST_LIVE=1 is set.
#
# Everything lives under one fresh `mktemp -d` root, removed in an exit trap.
# The only file copied in is Claude's `.credentials.json` (plus the one skill
# the flow loads). Every process runs under `env -i` with HOME and every XDG
# root pointed into the root. Claude runs as its unwrapped `.claude-wrapped`
# binary: the installed `claude` wrapper prepends
# `--dangerously-skip-permissions`, and here the flow runs in the default
# permission mode with a print-mode allow rule for `Skill` and
# `Bash(orchestrate:*)` only.
#
# What it does not isolate: the filesystem. The flow can still reach the live
# home by absolute path, and it runs as the living's account (the account's
# claude.ai skills sync into the sandbox home).
{
  pkgs,
  flake,
  system,
  ...
}:
let
  orchestrate = flake.lib.components.orchestrate.forSystem system;
in
pkgs.writeShellApplication {
  name = "orchestrate-claude";

  runtimeInputs = [
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.jq
    pkgs.systemd
  ];

  meta.description = "Light-model Claude Code flow doing Lock/Release against its own Orchestrate Nexus (needs ORCHESTRATE_TEST_LIVE=1 and the living's Claude login).";

  text = ''
    if [ "''${ORCHESTRATE_TEST_LIVE:-}" != 1 ]; then
      echo "orchestrate-claude: needs the living's Claude login and a live model; set ORCHESTRATE_TEST_LIVE=1 to run it" >&2
      exit 2
    fi

    model="''${ORCHESTRATE_TEST_MODEL:-${flake.lib.cheapestModel.claude}}"
    liveCredential="''${ORCHESTRATE_TEST_CREDENTIAL:-$HOME/.claude/.credentials.json}"
    skill="''${ORCHESTRATE_TEST_SKILL:-$HOME/primary/.claude/skills/orchestrate/SKILL.md}"

    # The unwrapped Claude binary: given, or found beside the installed
    # wrapper's real store path.
    claudeBinary="''${ORCHESTRATE_TEST_CLAUDE:-}"
    if [ -z "$claudeBinary" ]; then
      wrapper="$(readlink -f "$(command -v claude)")"
      claudeBinary="$(dirname "$wrapper")/.claude-wrapped"
    fi
    test -x "$claudeBinary" || { echo "orchestrate-claude: no unwrapped Claude at $claudeBinary; set ORCHESTRATE_TEST_CLAUDE" >&2; exit 1; }
    test -r "$liveCredential" || { echo "orchestrate-claude: no credential at $liveCredential" >&2; exit 1; }
    test -r "$skill" || { echo "orchestrate-claude: no orchestrate skill at $skill; set ORCHESTRATE_TEST_SKILL" >&2; exit 1; }

    # A refresh inside the sandbox could rotate the refresh token and strand
    # the live copy, so refuse when the access token is near expiry. Only the
    # expiry field is read; the token itself is never printed.
    expiresAt="$(jq -r '.claudeAiOauth.expiresAt // 0' "$liveCredential")"
    if [ $((expiresAt / 1000 - $(date +%s))) -lt 900 ]; then
      echo "orchestrate-claude: the Claude access token expires within 15 minutes; refresh the live login first" >&2
      exit 1
    fi

    # A short root: sun_path holds 108 bytes.
    root="$(mktemp -d /tmp/ot-XXXXXXXX)"
    nexusStarted=
    cleanup() {
      if [ -n "$nexusStarted" ]; then
        kill "$orchestrateNexusPid" 2>/dev/null || true
        wait "$orchestrateNexusPid" 2>/dev/null || true
      fi
      if [ -e "$root/home/.claude/.credentials.json" ] && ! cmp -s "$liveCredential" "$root/home/.claude/.credentials.json"; then
        echo "orchestrate-claude: WARNING the sandbox refreshed the credential; the live copy may be stale" >&2
      fi
      if [ -n "''${ORCHESTRATE_TEST_KEEP:-}" ]; then
        rm -f "$root/home/.claude/.credentials.json"
        echo "orchestrate-claude: kept $root (credential removed)" >&2
      else
        chmod -R u+w "$root" 2>/dev/null || true
        rm -rf "$root"
      fi
    }
    trap cleanup EXIT

    mkdir -p "$root"/{home/.claude,runtime,state,config,cache,data,tmp,transcripts,bin}
    mkdir -p "$root/work/.claude/skills/orchestrate"
    chmod 700 "$root" "$root/runtime" "$root/home" "$root/home/.claude"
    install -m 600 "$liveCredential" "$root/home/.claude/.credentials.json"
    install -m 644 "$skill" "$root/work/.claude/skills/orchestrate/SKILL.md"
    # Only the ordinary client is on the flow's PATH, never the meta client.
    ln -s ${orchestrate.client} "$root/bin/orchestrate"

    user="''${USER:-$(id -un)}"
    realRuntime="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    sandboxEnv=(
      HOME="$root/home"
      XDG_RUNTIME_DIR="$root/runtime"
      XDG_STATE_HOME="$root/state"
      XDG_CONFIG_HOME="$root/config"
      XDG_CACHE_HOME="$root/cache"
      XDG_DATA_HOME="$root/data"
      TMPDIR="$root/tmp"
      ORCHESTRATE_SOCKET="$root/runtime/${orchestrate.ordinarySocket}"
      PATH="$root/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin"
      SHELL="${pkgs.bash}/bin/bash"
      LANG=C.UTF-8
      TERM=dumb
      USER="$user"
      LOGNAME="$user"
      ENABLE_CLAUDEAI_MCP_SERVERS=false
      DISABLE_AUTOUPDATER=1
      DISABLE_NON_ESSENTIAL_MODEL_CALLS=1
      DISABLE_INSTALLATION_CHECKS=1
    )

    export XDG_RUNTIME_DIR="$root/runtime" XDG_STATE_HOME="$root/state"
    ${orchestrate.start}
    nexusStarted=1

    lockedPath="$root/work/probe"
    prompt="Load the orchestrate skill through your Skill tool. Then, using the Bash tool, run exactly:
    orchestrate 'Lock.{ OrchestrateTestProbe 3ec648 [ $lockedPath ] RoundTrip }'
    Read the integer lock ID from the Locked reply, then release it by running orchestrate 'Release.<id>' with that integer. Finish by printing the two replies verbatim and nothing else."

    # Bounded: 2 GiB, 600 s, 12 turns.
    cd "$root/work"
    XDG_RUNTIME_DIR="$realRuntime" systemd-run --user --scope --quiet -p MemoryMax=2G -- \
      timeout 600 env -i "''${sandboxEnv[@]}" \
      "$claudeBinary" -p "$prompt" --model "$model" \
      --output-format stream-json --verbose \
      --permission-mode default --strict-mcp-config \
      --allowedTools Skill 'Bash(orchestrate:*)' \
      --max-turns 12 \
      > "$root/transcripts/run.stream.jsonl" 2> "$root/transcripts/run.stderr" || true

    # Assertions, each against the Nexus or the transcript, not the model's
    # own summary.
    stream="$root/transcripts/run.stream.jsonl"
    result="$(jq -r 'select(.type == "result") | .subtype' "$stream")"
    echo "result: $result"
    test "$result" = success
    jq -e 'select(.type == "system" and .subtype == "init") | .permissionMode == "default"' "$stream" >/dev/null
    jq -e 'select(.type == "result") | (.permission_denials | length) == 0' "$stream" >/dev/null
    toolResults="$(jq -r 'select(.type == "user") | .message.content[]? | select(.type == "tool_result") | .content | if type == "array" then map(.text // "") | join("") else . end' "$stream")"
    grep -Fx "Locked.{ 1 OrchestrateTestProbe 3ec648 [ $lockedPath ] RoundTrip }" <<<"$toolResults"
    grep -Fx "Released.{ 1 OrchestrateTestProbe 3ec648 [ $lockedPath ] RoundTrip }" <<<"$toolResults"
    # The Nexus itself: nothing held, and the next lock is number 2, so the
    # flow's lock was the one and only lock this store issued.
    test "$(${orchestrate.client} 'Observe.Locks')" = 'Observed.Locks.[]'
    test "$(${orchestrate.client} "Lock.{ AfterRun 3ec648 [ $lockedPath ] Check }")" = "Locked.{ 2 AfterRun 3ec648 [ $lockedPath ] Check }"
    ${orchestrate.client} 'Release.2' >/dev/null

    ${orchestrate.stop}
    nexusStarted=
    echo "orchestrate-claude: passed ($model)"
  '';
}
