{
  description = "orchestrate-test — Nix sandboxes that drive the Orchestrate Nexus and its clients. The tested repository is a pinned flake input; scenarios are named by the components they drive.";

  inputs = {
    nixpkgs.url = "github:LiGoldragon/nixpkgs?ref=main";

    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";

    orchestrate.url = "github:LiGoldragon/orchestrate/a6c84bcaa097d4b6e9e0bb74900dc5e69a189b99";
    orchestrate.inputs.nixpkgs.follows = "nixpkgs";

    # The release before the one under test, for the scenario that resumes
    # its store: 0.38.0.
    orchestrate-previous.url = "github:LiGoldragon/orchestrate/0f9961460f84b752fa9605ebf0e2b6e1c685aa91";
    orchestrate-previous.inputs.nixpkgs.follows = "nixpkgs";

    # The release the live Nexus runs, for the rollback scenarios: 0.38.0,
    # 0f996146, the source of the live orchestrate-nexus service's package
    # (orchestrate-0.38.0).
    orchestrate-live.url = "github:LiGoldragon/orchestrate/0f9961460f84b752fa9605ebf0e2b6e1c685aa91";
    orchestrate-live.inputs.nixpkgs.follows = "nixpkgs";

    # The last release whose store sema-engine wrote, for the scenario that
    # upgrades it: 0.37.0, c7c44cb3, the release zeus and ouranos ran before
    # 0.38.0 (orchestrate-0.37.0); it keeps its store at orchestrate-nexus.sema.
    orchestrate-sema.url = "github:LiGoldragon/orchestrate/c7c44cb39934b0727d724a6aa03a36a2a94cacf9";
    orchestrate-sema.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: inputs.blueprint { inherit inputs; };
}
