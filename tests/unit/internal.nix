{ lib, fixtures }:
let
  system = "x86_64-linux";
  pkgs = {
    inherit system;
    stdenv.hostPlatform.system = system;
  };
  channels.nixpkgs = pkgs;
  create = lib.snowfall.internal.create-simple-derivations;
in
{
  system-lib = {
    test-exposes-snowfall = {
      expr = lib.snowfall.internal.system-lib ? snowfall;
      expected = true;
    };

    test-includes-nixpkgs-library = {
      expr = lib.snowfall.internal.system-lib ? mkOption;
      expected = true;
    };
  };

  user-lib = {
    test-is-an-attribute-set = {
      expr = builtins.isAttrs lib.snowfall.internal.user-lib;
      expected = true;
    };

    test-empty-when-no-user-library-is-discovered = {
      expr = builtins.attrNames lib.snowfall.internal.user-lib;
      expected = [ ];
    };
  };

  create-simple-derivations = {
    test-discovers-aliases-and-overrides = {
      expr =
        let
          result = create {
            type = "shells";
            src = fixtures.outputs + /shells;
            inherit channels pkgs;
            alias.default = "dev";
            overrides.extra = builtins.derivation {
              name = "extra";
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
          override = result.extra.name;
        };
      expected = {
        names = [
          "default"
          "dev"
          "extra"
        ];
        alias = "dev-shell";
        override = "extra";
      };
    };

    test-empty-input = {
      expr = create {
        type = "shells";
        src = fixtures.outputs + /empty;
        inherit channels pkgs;
      };
      expected = { };
    };

  };
}
