# Orchestrate test repository

Use the knowledge:nix-rust-builds skill for shared build-base discipline.

This repository holds scenarios and their fixtures. Component source remains
in its own repository. Tests consume the component's packages; they do not
reconstruct or compile its Rust workspace.

Every input URL names its bare repository. flake.lock holds each revision.
Preserve the previous, live, and sema migration fixtures at their recorded
revisions. They are historical fixtures, not candidates to upgrade.

Take pkgs from base.lib.contexts and override none of the component's base
inputs. One file holds one scenario, component, or builder. A scenario takes
its components from flake.lib.components and supplies only drive and assertions.
New component behavior belongs in lib/components/<name>.nix.

A pure scenario is a check without network or credentials. A semi-sandbox
remains a packages/<scenario>.nix runner with its own temporary state root and
exit trap, run only with the living's requested live credentials.

Name packages through pkgs; use no `with pkgs` expression. Format edited Nix
files with nixfmt before committing. Commit only files this flow edited.

Evaluate and build checks on the configured remote builder, using the exact
committed revision and the knowledge:nix-rust-builds remote gate. checks.default
is every pure scenario and lint check. A test edit changes only its scenario
check; component packages and historical fixture inputs remain unchanged.
