{ inputs, ... }:
{
  # One entry per tested component. A scenario reaches these as
  # `flake.lib.components.<name>`, takes what it needs, and adds only its own
  # drive and assertions.
  components = {
    orchestrate = import ./components/orchestrate.nix { inherit inputs; };
  };

  # The cheapest model per harness, the semi-sandbox default.
  cheapestModel = {
    claude = "haiku";
    codex = "luna";
  };
}
