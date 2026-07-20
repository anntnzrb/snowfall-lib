{ lib, fixtures }:
let
  system = "x86_64-linux";
  pkgs = {
    inherit system;
    stdenv.hostPlatform.system = system;
  };
  channels.nixpkgs = pkgs;
  create = lib.snowfall.package.create-packages;
in
{
  create-packages = {
    test-discovers-aliases-and-overrides = {
      expr =
        let
          result = create {
            src = fixtures.outputs + /packages;
            inherit channels pkgs;
            alias.default = "alpha";
            overrides.beta = builtins.derivation {
              name = "replacement";
              inherit system;
              builder = "/bin/sh";
              args = [ ];
              meta.platforms = [ system ];
            };
          };
        in
        {
          names = builtins.attrNames result;
          alias = result.default.name;
          override = result.beta.name;
          source = builtins.baseNameOf (builtins.dirOf result.alpha.meta.snowfall.path);
        };
      expected = {
        names = [
          "alpha"
          "beta"
          "default"
        ];
        alias = "alpha";
        override = "replacement";
        source = "alpha";
      };
    };

    test-empty-input = {
      expr = create {
        src = fixtures.outputs + /empty;
        inherit channels pkgs;
      };
      expected = { };
    };

  };
}
