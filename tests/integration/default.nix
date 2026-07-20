/*
  Reusable end-to-end fixture for Snowfall Lib.

  Callable interface:

    import ./tests/integration {
      snowfall = self; # an attrset exposing mkFlake and mkLib
      inputs = {
        inherit nixpkgs flake-utils-plus home-manager darwin;
      };
      linuxSystem = "x86_64-linux";   # optional
      darwinSystem = "aarch64-darwin"; # optional
    }

  The result is `{ outputs, assertions }`. `outputs` is the complete generated
  flake. `assertions` is a lazy attrset of booleans intended for `lib.runTests`
  or direct `assert` use. Supplying `home-manager` and `darwin` is mandatory:
  this fixture deliberately exercises both integrations instead of silently
  reducing coverage when an input is absent.
*/
{
  snowfall,
  inputs,
  linuxSystem ? "x86_64-linux",
  darwinSystem ? "aarch64-darwin",
}:
assert inputs ? nixpkgs;
assert inputs ? flake-utils-plus;
assert inputs ? home-manager;
assert inputs ? darwin;
let
  fixturePkgs = inputs.nixpkgs.legacyPackages.${linuxSystem};
  outputs = snowfall.mkFlake {
    inputs = inputs // {
      self = outputs;
    };
    src = ./fixture;

    snowfall = {
      namespace = "fixture";
      meta = {
        name = "snowfall-integration-fixture";
        title = "Snowfall integration fixture";
      };
    };

    systems.hosts = {
      linux.specialArgs.fixtureSpecialArg = "linux-special-arg";
      darwin.specialArgs.fixtureSpecialArg = "darwin-special-arg";
    };

    homes.users = {
      "hosted@linux".specialArgs.fixtureHomeArg = "hosted-home-arg";
      "standalone@aarch64-linux".specialArgs.fixtureHomeArg = "standalone-home-arg";
    };

    channels-config.allowUnfree = false;
    channels.nixpkgs.config.permittedInsecurePackages = [ ];
    channels.unstable.input = inputs.nixpkgs;

    packages.injected = fixturePkgs.writeText "injected" "injected";
    shells.injected = fixturePkgs.mkShell { name = "injected"; };
    checks.injected = fixturePkgs.runCommand "injected-check" { } "touch $out";
    templates.injected = {
      path = ./fixture/templates/example;
      description = "Injected template";
    };

    alias = {
      modules = {
        nixos.fixture-alias = "fixture";
        darwin.fixture-alias = "fixture";
        home.fixture-alias = "fixture";
      };
      packages.default = "hello-fixture";
      shells.default = "fixture-shell";
      checks.default = "fixture-check";
      templates.default = "example";
    };
  };

  linux = outputs.nixosConfigurations.linux.config;
  darwin = outputs.darwinConfigurations.darwin.config;
  hosted = outputs.homeConfigurations."hosted@linux".config;
  standalone = outputs.homeConfigurations."standalone@aarch64-linux".config;
  collisionLib = snowfall.mkLib {
    inputs = inputs // {
      self = { };
    };
    src = ./collision-fixture;
    snowfall.namespace = "collision";
  };
  collisionAttempt = builtins.tryEval (
    builtins.deepSeq (collisionLib.snowfall.system.create-systems { }) true
  );
  virtualOutputs = snowfall.mkFlake {
    inputs = inputs // {
      self = virtualOutputs;
    };
    src = ./virtual-fixture;
    snowfall.namespace = "virtualfixture";
  };
in
{
  inherit outputs;

  assertions = {
    nixos-system =
      outputs.nixosConfigurations.linux.pkgs.stdenv.hostPlatform.system
      == linuxSystem;
    darwin-system =
      outputs.darwinConfigurations.darwin.pkgs.stdenv.hostPlatform.system
      == darwinSystem;
    nixos-discovery = linux.fixture.integration == "nixos";
    darwin-discovery = darwin.fixture.integration == "darwin";
    hosted-home = hosted.fixture.integration == "hosted";
    standalone-home = standalone.fixture.integration == "standalone";
    hosted-os-config = hosted.fixture.parentMarker == "linux-parent";
    hosted-system-config = hosted.fixture.systemParentMarker == "linux-parent";
    standalone-null-configs = standalone.fixture.parentMarker == "standalone";
    system-special-args = linux.fixture.specialArg == "linux-special-arg";
    home-special-args = hosted.fixture.specialArg == "hosted-home-arg";
    channel-config =
      outputs.pkgs.${linuxSystem}.nixpkgs.config.allowUnfree == false;
    multiple-channels = outputs.pkgs.${linuxSystem} ? unstable;
    overlay-discovery =
      outputs.pkgs.${linuxSystem}.nixpkgs.fixtureOverlay == "discovered";
    package-discovery =
      outputs.packages.${linuxSystem}."hello-fixture".name == "hello-fixture";
    package-alias =
      outputs.packages.${linuxSystem}.default
      == outputs.packages.${linuxSystem}."hello-fixture";
    package-override = outputs.packages.${linuxSystem}.injected.name == "injected";
    shell-discovery =
      outputs.devShells.${linuxSystem}."fixture-shell".name == "fixture-shell";
    shell-override = outputs.devShells.${linuxSystem}.injected.name == "injected";
    check-discovery =
      outputs.checks.${linuxSystem}."fixture-check".name == "fixture-check";
    check-override =
      outputs.checks.${linuxSystem}.injected.name == "injected-check";
    template-discovery =
      outputs.templates.example.description
      == "Snowfall integration fixture template";
    template-override =
      outputs.templates.injected.description == "Injected template";
    nixos-alias = outputs.nixosModules ? fixture-alias;
    darwin-alias = outputs.darwinModules ? fixture-alias;
    home-alias = outputs.homeModules ? fixture-alias;
    private-system = outputs.nixosConfigurations ? private;
    private-skips-public-module =
      !((outputs.nixosConfigurations.private.config.fixture or { }).publicModule
        or false
      );
    normalized-name-collision = collisionAttempt.success == false;
    virtual-system =
      virtualOutputs.isoConfigurations.virtual.system == "x86_64-linux";
  };
}
