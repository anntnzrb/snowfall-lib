{
  inputs,
  self,
  mkLib,
  formatting,
  system,
}:
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
    path = ../../flake.nix;
    name = "test@${system}";
    inherit system;
  };
  private-systems-lib = mkLib {
    src = "${self}/tests/fixtures/private-systems";
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
    src = "${self}/tests/fixtures/private-systems";
    inputs = builtins.removeAttrs (inputs // { self = { }; }) [ "home-manager" ];
  };
  private-system-collision-lib = mkLib {
    src = "${self}/tests/fixtures/private-system-collision";
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
      pkgs.lib.hasInfix "systemConfig = config;" (
        builtins.readFile ../../modules/nixos/user/default.nix
      )
      && pkgs.lib.hasInfix "systemConfig = config;" (
        builtins.readFile ../../modules/darwin/user/default.nix
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
    private-system-skips-auto-modules =
      builtins.length private-systems.private.modules == 1;
    normal-system-keeps-auto-modules =
      builtins.length private-systems-no-home-manager.normal.modules
      > builtins.length private-systems-no-home-manager.private.modules;
    private-system-skips-home-manager =
      !(private-systems.private.specialArgs ? homeManager);
    private-system-rejects-collision = !private-system-collision.success;
    strips-bare-home-package-alias =
      bare-name-package-alias == "homeConfigurations-test";
  };
  regression-tests = inputs.nixpkgs.lib.mapAttrs' (
    name: value:
    inputs.nixpkgs.lib.nameValuePair "test-${name}" {
      expr = value;
      expected = true;
    }
  ) (inputs.nixpkgs.lib.filterAttrs (_: builtins.isBool) eval.value);
  regression-failures = inputs.nixpkgs.lib.runTests regression-tests;
  # nixfmt's GHC toolchain cannot bootstrap on the remaining exposed systems.
  strictToolchainSystems = [
    "aarch64-darwin"
    "aarch64-linux"
    "i686-linux"
    "x86_64-linux"
  ];
in
assert eval.success;
{
  snowfall-lib-eval =
    assert inputs.nixpkgs.lib.assertMsg (regression-failures == [ ]) (
      "Snowfall evaluation regressions:\n" + builtins.toJSON regression-failures
    );
    pkgs.runCommand "snowfall-lib-eval" { } "mkdir -p $out";
  unit = import ./unit.nix { inherit inputs self system; };
}
//
  inputs.nixpkgs.lib.optionalAttrs (builtins.elem system strictToolchainSystems)
    { formatting = formatting.check (inputs.nixpkgs.lib.cleanSource ../..); }
// inputs.nixpkgs.lib.optionalAttrs (system == "x86_64-linux") (
  let
    nixos-smoke-lib = mkLib {
      src = "${self}/tests/fixtures/nixos-smoke";
      inputs = inputs // {
        self = { };
      };
    };
    nixos-smoke-definition =
      (nixos-smoke-lib.snowfall.system.create-systems { }).smoke;
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
