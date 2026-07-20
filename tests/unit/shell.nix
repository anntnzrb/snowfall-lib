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
  create-shells = {
    test-delegates-discovery-and-aliases = {
      expr =
        let
          result = lib.snowfall.shell.create-shells {
            src = fixtures.outputs + /shells;
            inherit channels pkgs;
            alias.default = "dev";
          };
        in
        {
          names = builtins.attrNames result;
          default = result.default.name;
        };
      expected = {
        names = [
          "default"
          "dev"
        ];
        default = "dev-shell";
      };
    };

    test-empty-input = {
      expr = lib.snowfall.shell.create-shells {
        src = fixtures.outputs + /empty;
        inherit channels pkgs;
      };
      expected = { };
    };
  };
}
