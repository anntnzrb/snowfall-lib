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
              home-manager = {
                lib.hm = { };
              };
            };
          };
          standalone-home = lib.snowfall.home.create-home {
            path = ./flake.nix;
            name = "test@${system}";
            inherit system;
          };
          private-systems-lib = mkLib {
            src = ./tests/fixtures/private-systems;
            inputs = inputs // {
              self = { };
              home-manager = {
                lib.hm = { };
                nixosModules.home-manager = "home-manager-module";
                darwinModules.home-manager = "darwin-home-manager-module";
              };
            };
          };
          private-systems-no-home-manager-lib = mkLib {
            src = ./tests/fixtures/private-systems;
            inputs = builtins.removeAttrs (inputs // { self = { }; }) [ "home-manager" ];
          };
          private-system-collision-lib = mkLib {
            src = ./tests/fixtures/private-system-collision;
            inputs = inputs // {
              self = { };
            };
          };
          private-systems = private-systems-lib.snowfall.system.create-systems { };
          private-systems-no-home-manager =
            private-systems-no-home-manager-lib.snowfall.system.create-systems
              { };
          private-system-collision = builtins.tryEval (
            private-system-collision-lib.snowfall.system.create-systems { }
          );
          standalone-special-args = standalone-home.specialArgs;
          exported-home-name = "test@${system}";
          resolved-exported-home = lib.snowfall.flake.resolve-exported-home {
            home-name = exported-home-name;
            home = {
              modules = [ ];
              inherit system;
              specialArgs = {
                host = "";
                user = "test";
                standaloneOnly = true;
              };
              builder = args: args.specialArgs;
            };
            systems = {
              test-host = {
                output = "nixosConfigurations";
                inherit system;
              };
            };
            flake-outputs = {
              nixosConfigurations = {
                test-host = {
                  config = {
                    hostName = "test-host";
                    home-manager = {
                      users.test = { };
                      extraSpecialArgs = {
                        arbitraryName = "ok";
                      };
                    };
                  };
                };
              };
              homeConfigurations = {
                ${exported-home-name} = {
                  fallback = true;
                };
              };
            };
          };
          bare-name-package-alias =
            "homeConfigurations-"
            + (
              if pkgs.lib.hasSuffix "@${system}" exported-home-name then
                pkgs.lib.removeSuffix "@${system}" exported-home-name
              else
                exported-home-name
            );
          eval = builtins.tryEval {
            snowfall-attrs = builtins.attrNames lib.snowfall;
            has-standalone-home-placeholders =
              (standalone-special-args ? osConfig)
              && (standalone-special-args.osConfig == null)
              && (standalone-special-args ? systemConfig)
              && (standalone-special-args.systemConfig == null);
            has-system-config-aliases =
              (
                builtins.length (
                  builtins.split "systemConfig = config;" (builtins.readFile ./modules/nixos/user/default.nix)
                ) > 1
              )
              && (
                builtins.length (
                  builtins.split "systemConfig = config;" (builtins.readFile ./modules/darwin/user/default.nix)
                ) > 1
              );
            resolves-exported-home-extra-special-args =
              resolved-exported-home ? arbitraryName
              && (resolved-exported-home.arbitraryName == "ok")
              && (resolved-exported-home ? systemConfig)
              && (resolved-exported-home.systemConfig.hostName == "test-host")
              && (resolved-exported-home ? osConfig)
              && (resolved-exported-home.osConfig.hostName == "test-host")
              && (resolved-exported-home ? standaloneOnly)
              && resolved-exported-home.standaloneOnly;
            private-system-normalizes-name =
              builtins.attrNames private-systems == [
                "normal"
                "private"
              ];
            private-system-skips-auto-modules = builtins.length private-systems.private.modules == 1;
            normal-system-keeps-auto-modules =
              builtins.length private-systems-no-home-manager.normal.modules
              > builtins.length private-systems-no-home-manager.private.modules;
            private-system-skips-home-manager = !(private-systems.private.specialArgs ? homeManager);
            private-system-rejects-collision = !private-system-collision.success;
            strips-bare-home-package-alias = bare-name-package-alias == "homeConfigurations-test";
          };
        in
        assert eval.success;
        assert eval.value.has-standalone-home-placeholders;
        assert eval.value.has-system-config-aliases;
        assert eval.value.resolves-exported-home-extra-special-args;
        assert eval.value.private-system-normalizes-name;
        assert eval.value.private-system-skips-auto-modules;
        assert eval.value.normal-system-keeps-auto-modules;
        assert eval.value.private-system-skips-home-manager;
        assert eval.value.private-system-rejects-collision;
        assert eval.value.strips-bare-home-package-alias;
        {
          snowfall-lib-eval = pkgs.runCommand "snowfall-lib-eval" { } "mkdir -p $out";
        }
        // inputs.nixpkgs.lib.optionalAttrs (system == "x86_64-linux") (
          let
            nixos-smoke-lib = mkLib {
              src = ./tests/fixtures/nixos-smoke;
              inputs = inputs // {
                self = { };
              };
            };
            nixos-smoke-definition = (nixos-smoke-lib.snowfall.system.create-systems { }).smoke;
            nixos-smoke-system = nixos-smoke-definition.builder {
              inherit (nixos-smoke-definition) system modules specialArgs;
            };
            kernel = nixos-smoke-system.config.boot.kernelPackages.kernel;
          in
          {
            snowfall-lib-nixos-smoke =
              assert kernel ? buildDTBs;
              assert kernel ? target;
              nixos-smoke-system.config.system.build.toplevel;
          }
        )
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
