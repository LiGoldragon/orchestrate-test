{
  description = "orchestrate-test — Nix sandboxes that drive the Orchestrate Nexus and its clients. The tested repository is a pinned flake input; scenarios are named by the components they drive.";

  inputs = {
    nixpkgs.url = "github:LiGoldragon/nixpkgs?ref=main";

    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";

    orchestrate.url = "github:LiGoldragon/orchestrate/bc5cd36e81df395ed1f84e2e3e98d5a6ee90bf8c";
    orchestrate.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: inputs.blueprint { inherit inputs; };
}
