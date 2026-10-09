{
  description = "orchestrate-test — Nix sandboxes that drive the Orchestrate Nexus and its clients. The tested repository is a pinned flake input; scenarios are named by the components they drive.";

  inputs = {
    nixpkgs.url = "github:LiGoldragon/nixpkgs?ref=main";

    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";

    orchestrate.url = "github:LiGoldragon/orchestrate/c7c44cb39934b0727d724a6aa03a36a2a94cacf9";
    orchestrate.inputs.nixpkgs.follows = "nixpkgs";

    # The release before the one under test, for the scenario that resumes
    # its store: 0.36.1.
    orchestrate-previous.url = "github:LiGoldragon/orchestrate/bc5cd36e81df395ed1f84e2e3e98d5a6ee90bf8c";
    orchestrate-previous.inputs.nixpkgs.follows = "nixpkgs";

    # The release the live Nexus runs, for the rollback scenarios: 0.35.0,
    # 9070cbb8, whose package built against this flake's nixpkgs is the very
    # store path the live orchestrate-nexus service executes.
    orchestrate-live.url = "github:LiGoldragon/orchestrate/9070cbb8717813b127e448dd5a43a2095daf7d1b";
    orchestrate-live.inputs.nixpkgs.follows = "nixpkgs";

    # The datom codec Orchestrate's contracts derive through, for the
    # scenario that prints a String alias and a String newtype: 0.32.2. Its
    # pinned rust-build also supplies the compiler every Rust scenario runs.
    datom-codec.url = "github:LiGoldragon/datom-codec/4dff16b4f7412febc3b71aac8b49680cd20988cb";
    datom-codec.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: inputs.blueprint { inherit inputs; };
}
