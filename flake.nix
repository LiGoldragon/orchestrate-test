{
  description = "orchestrate-test — Nix sandboxes that drive the Orchestrate Nexus and its clients. The tested repository is a pinned flake input; scenarios are named by the components they drive.";

  inputs = {
    nixpkgs.url = "github:LiGoldragon/nixpkgs?ref=main";

    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";

    orchestrate.url = "github:LiGoldragon/orchestrate/d80a617f7e03ebade846c41ac540b7d173d3d056";
    orchestrate.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: inputs.blueprint { inherit inputs; };
}
