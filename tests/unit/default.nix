{ lib, nixUnitLib }:
let
  fixtures = {
    pure = ./fixtures/pure;
    builders = ./fixtures/builders;
    outputs = ./fixtures/outputs;
  };
  suites = {
    attrs = import ./attrs.nix { inherit lib fixtures; };
    check = import ./check.nix { inherit lib fixtures; };
    flake = import ./flake.nix { inherit lib fixtures; };
    fp = import ./fp.nix { inherit lib fixtures; };
    fs = import ./fs.nix { inherit lib fixtures; };
    home = import ./home.nix { inherit lib fixtures; };
    internal = import ./internal.nix { inherit lib fixtures; };
    module = import ./module.nix { inherit lib fixtures; };
    overlay = import ./overlay.nix { inherit lib fixtures; };
    package = import ./package.nix { inherit lib fixtures; };
    path = import ./path.nix { inherit lib fixtures; };
    root = import ./root.nix { inherit lib fixtures; };
    shell = import ./shell.nix { inherit lib fixtures; };
    system = import ./system.nix { inherit lib fixtures; };
    template = import ./template.nix { inherit lib fixtures; };
  };
  public = builtins.removeAttrs lib.snowfall [ "internal" ];
  namespaces = lib.filterAttrs (_: builtins.isAttrs) public;
  root-interface = lib.filterAttrs (_: value: !builtins.isAttrs value) public;
  covered = builtins.mapAttrs (
    namespace: interface:
    nixUnitLib.coverage.addCoverage interface suites.${namespace}
  ) namespaces;
in
covered
// {
  internal = nixUnitLib.coverage.addCoverage lib.snowfall.internal suites.internal;
  root = nixUnitLib.coverage.addCoverage root-interface suites.root;
}
