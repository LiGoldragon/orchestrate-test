{
  description = "Orchestrate scenarios over shared build-base packages and immutable historical fixtures.";

  inputs = {
    base.url = "github:LiGoldragon/build-base";
    orchestrate.url = "github:LiGoldragon/orchestrate";
    orchestrate-previous.url = "github:LiGoldragon/orchestrate";
    orchestrate-live.url = "github:LiGoldragon/orchestrate";
    orchestrate-sema.url = "github:LiGoldragon/orchestrate";
  };

  outputs =
    inputs@{ self, base, ... }:
    let
      perContext =
        context:
        let
          inherit (context) pkgs;
          inherit (pkgs) lib;
          importDirectory =
            directory:
            lib.mapAttrs'
              (
                name: _:
                lib.nameValuePair (lib.removeSuffix ".nix" name) (
                  import (directory + "/${name}") {
                    inherit pkgs;
                    flake = self;
                    system = pkgs.stdenv.hostPlatform.system;
                  }
                )
              )
              (
                lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) (
                  builtins.readDir directory
                )
              );
          scenarios = importDirectory ./checks;
        in
        {
          packages = importDirectory ./packages;
          checks = scenarios // {
            default = pkgs.linkFarm "orchestrate-scenarios" scenarios;
          };
        };
    in
    {
      lib = import ./lib { inherit inputs; };
      packages = base.lib.forSystems (context: (perContext context).packages);
      checks = base.lib.forSystems (context: (perContext context).checks);
      formatter = base.lib.forSystems (context: context.pkgs.nixfmt);
    };
}
