{
  description = "Snowfall Lib";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils-plus.url = "github:gytis-ivaskevicius/flake-utils-plus/master";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      ...
    }@inputs:
    let
      core-inputs = inputs // {
        src = self;
      };
      systems = inputs.nixpkgs.lib.systems.flakeExposed;
      inherit (inputs.flake-utils-plus.lib) eachSystemMap;
      treefmtEval = eachSystemMap systems (
        system:
        inputs.treefmt-nix.lib.evalModule inputs.nixpkgs.legacyPackages.${system} {
          projectRootFile = "flake.nix";

          programs = {
            deadnix = {
              enable = true;
              no-lambda-arg = false;
              no-lambda-pattern-names = false;
              no-underscore = false;
            };
            nixfmt.enable = true;
            statix = {
              enable = true;
              disabled-lints = [ ];
            };
          };
        }
      );

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
          lib = mkLib {
            inherit inputs src snowfall;
          };
          flake-options = builtins.removeAttrs flake-and-lib-options [
            "inputs"
            "src"
          ];
        in
        lib.mkFlake flake-options;
    in
    {
      inherit mkLib mkFlake;

      nixosModules = {
        user = ./modules/nixos/user/default.nix;
      };

      darwinModules = {
        user = ./modules/darwin/user/default.nix;
      };

      homeModules = {
        user = ./modules/home/user/default.nix;
      };

      formatter = eachSystemMap systems (system: treefmtEval.${system}.config.build.wrapper);

      # Regression check: force snowfall-lib evaluation so unexpected-arg errors fail in `nix flake check`.
      checks = eachSystemMap systems (
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
          lib = mkLib {
            src = self;
            inputs = inputs // {
              self = { };
            };
          };
          eval = builtins.tryEval (builtins.attrNames lib.snowfall);
        in
        assert eval.success;
        {
          snowfall-lib-eval = pkgs.runCommand "snowfall-lib-eval" { } "mkdir -p $out";
        }
      );

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

              inputs = inputs // {
                self = { };
              };
            };
          in
          builtins.removeAttrs lib.snowfall [ "internal" ];
      };
    };
}
