{ lib, fixtures }:
let
  home = lib.snowfall.home;
  lib-with-home-manager =
    import ../../snowfall-lib
      {
        nixpkgs.lib = lib;
        flake-utils-plus.lib.filterPackages = _system: attrs: attrs;
        src = ../..;
      }
      {
        inputs = {
          self.pkgs.x86_64-linux.nixpkgs = { };
          home-manager.lib = {
            hm = { };
            homeManagerConfiguration = args: args;
          };
        };
        src = fixtures.builders;
      };
  home-with-input = lib-with-home-manager.snowfall.home;
in
{
  home-lib = {
    testExportedAsAnAttributeSet = {
      expr = builtins.isAttrs home.home-lib;
      expected = true;
    };

    testIsEmptyWithoutHomeManagerInput = {
      expr = home.home-lib;
      expected = { };
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

    testCreatesHostlessMetadataWithDefaults = {
      expr =
        let
          created = home-with-input.create-home {
            path = "${fixtures.builders}/homes/x86_64-linux/alice/default.nix";
            name = "alice";
          };
        in
        {
          inherit (created) channelName output system;
          moduleCount = builtins.length created.modules;
          specialArgs = builtins.removeAttrs created.specialArgs [
            "inputs"
            "lib"
            "pkgs"
          ];
        };
      expected = {
        channelName = "nixpkgs";
        moduleCount = 2;
        output = "homeConfigurations";
        specialArgs = {
          format = "home";
          host = "";
          name = "alice@x86_64-linux";
          namespace = "internal";
          osConfig = null;
          system = "x86_64-linux";
          systemConfig = null;
          user = "alice";
        };
        system = "x86_64-linux";
      };
    };

    testRejectsHostlessNameContainingAt = {
      expr = home-with-input.create-home {
        path = "${fixtures.builders}/homes/x86_64-linux/alice/default.nix";
        name = "alice@";
      };
      expectedError = {
        type = "ThrownError";
        msg = "must be named with the format: user@system";
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

    testMissingTargetHasNoHomes = {
      expr = home.get-target-homes-metadata "${fixtures.builders}/homes/aarch64-linux";
      expected = [ ];
    };
  };

  create-homes = {
    testReturnsAnAttributeSet = {
      expr = builtins.isAttrs (home.create-homes { });
      expected = true;
    };

    testHasNoHomesWhenNoneAreDiscovered = {
      expr = home.create-homes { modules = [ "unused-without-discovered-homes" ]; };
      expected = { };
    };
  };

  create-home-system-modules = {
    testReturnsModules = {
      expr = builtins.isList (home.create-home-system-modules { });
      expected = true;
    };

    testIncludesBootstrapAndDiscoveredModules = {
      expr = builtins.length (home.create-home-system-modules { });
      expected = 3;
    };
  };
}
