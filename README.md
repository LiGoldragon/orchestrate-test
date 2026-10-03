# orchestrate-test

Nix sandboxes that drive the Orchestrate Nexus and its clients. This repository
holds no component source: it **pins `orchestrate` as a flake input** (its
`nixpkgs` follows this flake's) and drives it. Scenarios change often; the
Nexus changes rarely, so a new or edited scenario never invalidates the Rust
build, and Orchestrate moves forward here only when this repository updates its
input.

Test unpushed Orchestrate code with
`--override-input orchestrate path:/git/github.com/LiGoldragon/orchestrate`.
Once it lands, `nix flake update orchestrate` and commit the lock.

## Layout

Laid out for [numtide blueprint](https://numtide.github.io/blueprint): the
directory tree is the flake's output tree.

    flake.nix                          inputs and `inputs.blueprint { inherit inputs; }`
    lib/default.nix                    flake.lib: components, cheapestModel
    lib/components/orchestrate.nix     the Nexus and both clients: paths, start, stop
    checks/orchestrate.nix             pure scenario (a check)
    packages/orchestrate-claude.nix    semi-sandbox runner (gated)
    checks/lint.nix                    nixfmt --check, deadnix, statix
    formatter.nix                      pkgs.nixfmt

## Scenarios

| scenario | kind | components |
| --- | --- | --- |
| `orchestrate` | pure check | Orchestrate (Nexus, `orchestrate`, `orchestrate-meta`) |
| `orchestrate-claude` | semi-sandbox, gated | Orchestrate, Claude Code on the cheapest model |

### `orchestrate` (pure)

Starts `orchestrate-nexus` with no arguments on its own `XDG_RUNTIME_DIR` and
`XDG_STATE_HOME` inside the build sandbox, so it opens a fresh store and binds
`orchestrate.sock` and `orchestrate-meta.sock` there. It then drives the stock
clients and compares each whole reply and exit code:

1. `Observe.Locks` → `Observed.Locks.[]`
2. `Lock.{ OrchestrateTestProbe 3ec648 [ <path> ] «two words» }` →
   `Locked.{ 1 OrchestrateTestProbe 3ec648 [ <path> ] «two words» }`
3. `Release.1` → `Released.{ 1 … «two words» }`
4. `Observe.Locks` → `Observed.Locks.[]`
5. meta `Configure.{ «<ordinary>» «<meta>» }` →
   `Configured.{ { <ordinary> <meta> } True }`

and then stops the Nexus and requires it to exit on TERM. No network, no
credentials, no model.

### `orchestrate-claude` (semi-sandbox, gated)

A light-model Claude Code flow (Haiku by default) loads the `orchestrate`
skill and does one Lock/Release round trip against its own Nexus. It needs the
living's Claude login and the network, so it is a runner and never a check;
`nix flake check` only builds its script (`pkgs-orchestrate-claude`). It refuses
to run unless `ORCHESTRATE_TEST_LIVE=1`:

    ORCHESTRATE_TEST_LIVE=1 nix run .#orchestrate-claude

| variable | default |
| --- | --- |
| `ORCHESTRATE_TEST_LIVE` | unset: refuse (exit 2) |
| `ORCHESTRATE_TEST_MODEL` | `haiku` |
| `ORCHESTRATE_TEST_CLAUDE` | `.claude-wrapped` beside the installed `claude` wrapper |
| `ORCHESTRATE_TEST_CREDENTIAL` | `$HOME/.claude/.credentials.json` |
| `ORCHESTRATE_TEST_SKILL` | `$HOME/primary/.claude/skills/orchestrate/SKILL.md` |
| `ORCHESTRATE_TEST_KEEP` | unset: remove the root; set: keep it, minus the credential |

It makes a short root with `mktemp -d /tmp/ot-XXXXXXXX` (a socket path must fit
108 bytes), copies in only the credential and the skill, starts the Nexus on
that root, and runs the **unwrapped** Claude binary under `env -i` in the
default permission mode with the print-mode allow rule
`--allowedTools Skill 'Bash(orchestrate:*)'` (the installed `claude` wrapper
prepends `--dangerously-skip-permissions`, which is why it is bypassed), with
`ENABLE_CLAUDEAI_MCP_SERVERS=false` and `--strict-mcp-config`, bounded by
`MemoryMax=2G`, 600 s and 12 turns. Only the ordinary client is on the flow's
PATH. It asserts a `success` result, `permissionMode` `default`, no permission
denials, the exact `Locked.{ 1 … }` and `Released.{ 1 … }` tool results, an
empty `Observe.Locks` afterwards, and that the next lock is number 2. The root
is removed on exit. It refuses to start when the access token expires within
15 minutes, and warns if the sandbox copy of the credential changed.

Not isolated: the filesystem (the flow can reach the live home by absolute
path) and the account (it runs as the living's Claude account; the account's
claude.ai skills sync into the sandbox home).

## Running

    find . -name '*.nix' -exec nix fmt {} +
    nix flake check --no-build --option allow-import-from-derivation false
    nix flake check
    ORCHESTRATE_TEST_LIVE=1 nix run .#orchestrate-claude   # only by hand

Builds go to the remote builder.
