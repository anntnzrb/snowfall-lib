{ lib, fixtures }:
let
  home = lib.snowfall.home;
in
{
  home-lib = {
    testExportedAsAnAttributeSet = {
      expr = builtins.isAttrs home.home-lib;
      expected = true;
    };
  };

  split-user-and-host = {
    testHosted = {
      expr = home.split-user-and-host "alice@workstation";
      expected = {
        user = "alice";
        host = "workstation";
      };
    };

    testHostless = {
      expr = home.split-user-and-host "alice";
      expected = {
        user = "alice";
        host = "";
      };
    };
  };

  create-home = {
    testRequiresHomeManagerInput = {
      expr = home.create-home {
        path = "${fixtures.builders}/homes/x86_64-linux/alice/default.nix";
        name = "alice@workstation";
      };
      expectedError = {
        type = "ThrownError";
        msg = "include `home-manager` as a flake input";
      };
    };
  };

  get-target-homes-metadata = {
    testNormalizesHostlessNames = {
      expr = home.get-target-homes-metadata "${fixtures.builders}/homes/x86_64-linux";
      expected = [
        {
          name = "alice@x86_64-linux";
          path = "${fixtures.builders}/homes/x86_64-linux/alice/default.nix";
          system = "x86_64-linux";
        }
        {
          name = "bob@workstation";
          path = "${fixtures.builders}/homes/x86_64-linux/bob@workstation/default.nix";
          system = "x86_64-linux";
        }
      ];
    };
  };

  create-homes = {
    testReturnsAnAttributeSet = {
      expr = builtins.isAttrs (home.create-homes { });
      expected = true;
    };
  };

  create-home-system-modules = {
    testReturnsModules = {
      expr = builtins.isList (home.create-home-system-modules { });
      expected = true;
    };
  };
}
