{ lib, fixtures }:
let
  system = "x86_64-linux";
  pkgs = {
    inherit system;
    stdenv.hostPlatform.system = system;
  };
  channels.nixpkgs = pkgs;
in
{
  create-checks = {
    test-delegates-discovery-and-overrides = {
      expr =
        let
          result = lib.snowfall.check.create-checks {
            src = fixtures.outputs + /checks;
            inherit channels pkgs;
            overrides.extra = builtins.derivation {
              name = "extra-check";
              inherit system;
              builder = "/bin/sh";
              args = [ ];
              meta.platforms = [ system ];
            };
          };
        in
        builtins.map (name: result.${name}.name) (builtins.attrNames result);
      expected = [
        "extra-check"
        "lint-check"
      ];
    };
  };
}
