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
  shallow-groups =
    _namespace: interface: suite:
    builtins.filter (
      name:
      let
        group = suite.${name} or { };
      in
      !builtins.isAttrs group || builtins.length (builtins.attrNames group) < 2
    ) (builtins.attrNames interface);
  qualified-shallow-groups =
    namespace: interface: suite:
    builtins.map (name: "${namespace}.${name}") (
      shallow-groups namespace interface suite
    );
  missing-depth =
    lib.concatMap (
      namespace:
      qualified-shallow-groups namespace namespaces.${namespace} suites.${namespace}
    ) (builtins.attrNames namespaces)
    ++ qualified-shallow-groups "internal" lib.snowfall.internal suites.internal
    ++ qualified-shallow-groups "root" root-interface suites.root;
  covered = builtins.mapAttrs (
    namespace: interface:
    nixUnitLib.coverage.addCoverage interface suites.${namespace}
  ) namespaces;
in
assert lib.assertMsg (missing-depth == [ ])
  "Every exported Snowfall API must have at least two behavioral tests. Missing: ${builtins.concatStringsSep ", " missing-depth}";
covered
// {
  internal = nixUnitLib.coverage.addCoverage lib.snowfall.internal suites.internal;
  root = nixUnitLib.coverage.addCoverage root-interface suites.root;
}
