{ lib, fixtures }:
let
  create = lib.snowfall.module.create-modules;
  pkgs.stdenv.hostPlatform.system = "x86_64-linux";
in
{
  create-modules = {
    test-discovers-nested-modules-and-aliases = {
      expr =
        let
          src = builtins.unsafeDiscardStringContext (
            builtins.toString (fixtures.outputs + /modules/nixos)
          );
          modules = create {
            inherit src;
            alias.default = "basic";
          };
          evaluated = modules.basic { inherit pkgs; };
        in
        {
          names = builtins.attrNames modules;
          inherit (evaluated.config.fixture)
            system
            target
            format
            virtual
            ;
          has-file = evaluated ? _file;
        };
      expected = {
        names = [
          "basic"
          "default"
          "static"
        ];
        system = "x86_64-linux";
        target = "x86_64-linux";
        format = "linux";
        virtual = false;
        has-file = true;
      };
    };

    test-override-wins = {
      expr =
        (create {
          src = fixtures.outputs + /modules/nixos;
          overrides.basic = "replacement";
        }).basic;
      expected = "replacement";
    };

    test-empty-input = {
      expr = create { src = fixtures.outputs + /empty; };
      expected = { };
    };

  };
}
