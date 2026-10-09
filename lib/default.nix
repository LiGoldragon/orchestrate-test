{ inputs, ... }:
{
  # One entry per tested component. A scenario reaches these as
  # `flake.lib.components.<name>`, takes what it needs, and adds only its own
  # drive and assertions.
  components = {
    orchestrate = import ./components/orchestrate.nix {
      name = "orchestrate";
      input = inputs.orchestrate;
    };
    orchestrate-previous = import ./components/orchestrate.nix {
      name = "orchestrate-previous";
      input = inputs.orchestrate-previous;
    };
    orchestrate-live = import ./components/orchestrate.nix {
      name = "orchestrate-live";
      input = inputs.orchestrate-live;
    };
    rust = import ./components/rust.nix { input = inputs.datom-codec; };
    datom-codec = import ./components/datom-codec.nix {
      input = inputs.datom-codec;
    };
  };

  # The shared frame of a pure scenario: `flake.lib.scenario { pkgs, name }
  # drive` is a check that runs `drive` in a fresh root.
  scenario = import ./scenario.nix;

  # The cheapest model per harness, the semi-sandbox default.
  cheapestModel = {
    claude = "haiku";
    codex = "luna";
  };
}
