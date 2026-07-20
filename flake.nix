{
  description = "Snowfall Lib";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-unit = {
      url = "github:nix-community/nix-unit/v2.34.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils-plus.url = "github:gytis-ivaskevicius/flake-utils-plus/master";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, ... }@inputs:
    let
      test-input-names = [
        "darwin"
        "home-manager"
        "nix-unit"
      ];
      library-inputs = builtins.removeAttrs inputs test-input-names;
      core-inputs = library-inputs // {
        src = self;
      };
      systems = inputs.nixpkgs.lib.systems.flakeExposed;

      # Create the library, extending the nixpkgs library and merging
      # libraries from other inputs to make them available like
      # `lib.flake-utils-plus.mkApp`.
      # Usage: mkLib { inherit inputs; src = ./.; }
      #   result: lib
      mkLib = import ./snowfall-lib core-inputs;

      # A convenience wrapper to create the library and then call `lib.mkFlake`.
      # Usage: mkFlake { inherit inputs; src = ./.; ... }
      #   result: <flake-outputs>
      mkFlake =
        flake-and-lib-options@{
          inputs,
          src,
          snowfall ? { },
          ...
        }:
        let
          lib = mkLib { inherit inputs src snowfall; };
          flake-options = builtins.removeAttrs flake-and-lib-options [
            "inputs"
            "src"
          ];
        in
        lib.mkFlake flake-options;

      perSystemOutputs = import ./nix/flake/per-system.nix {
        inherit
          inputs
          self
          systems
          mkLib
          ;
      };
      test-lib = mkLib {
        src = self;
        inputs = library-inputs // {
          self = { };
        };
      };
      tests = import ./tests/unit {
        lib = test-lib;
        nixUnitLib = inputs.nix-unit.lib;
      };
    in
    {
      inherit mkLib mkFlake tests;

      nixosModules = {
        user = ./modules/nixos/user/default.nix;
      };

      darwinModules = {
        user = ./modules/darwin/user/default.nix;
      };

      homeModules = {
        user = ./modules/home/user/default.nix;
      };

      snowfall = rec {
        raw-config = config;

        config = {
          root = self;
          src = self;
          namespace = "snowfall";
          lib-dir = "snowfall-lib";

          meta = {
            name = "snowfall-lib";
            title = "Snowfall Lib";
          };
        };

        internal-lib =
          let
            lib = mkLib {
              src = self;

              inputs = library-inputs // {
                self = { };
              };
            };
          in
          builtins.removeAttrs lib.snowfall [ "internal" ];
      };
    }
    // perSystemOutputs;
}
