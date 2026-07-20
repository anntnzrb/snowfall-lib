{ lib, fixtures }:
let
  system = lib.snowfall.system;
  builder = args: args;
in
{
  get-inferred-system-name = {
    testDirectory = {
      expr = system.get-inferred-system-name "${fixtures.builders}/systems/x86_64-linux/alpha";
      expected = "alpha";
    };

    testNixFile = {
      expr = system.get-inferred-system-name "${fixtures.builders}/systems/x86_64-linux/alpha/default.nix";
      expected = "alpha";
    };
  };

  is-darwin = {
    testDetectsDarwin = {
      expr = system.is-darwin "aarch64-darwin";
      expected = true;
    };

    testRejectsLinux = {
      expr = system.is-darwin "x86_64-linux";
      expected = false;
    };
  };

  is-linux = {
    testDetectsLinux = {
      expr = system.is-linux "x86_64-linux";
      expected = true;
    };

    testRejectsDarwin = {
      expr = system.is-linux "aarch64-darwin";
      expected = false;
    };
  };

  is-virtual = {
    testDetectsIso = {
      expr = system.is-virtual "x86_64-iso";
      expected = true;
    };

    testRejectsNative = {
      expr = system.is-virtual "x86_64-linux";
      expected = false;
    };
  };

  get-virtual-system-type = {
    testIso = {
      expr = system.get-virtual-system-type "x86_64-iso";
      expected = "iso";
    };

    testNative = {
      expr = system.get-virtual-system-type "x86_64-linux";
      expected = "";
    };
  };

  get-target-systems-metadata = {
    testDiscoversPublicAndPrivate = {
      expr = system.get-target-systems-metadata "${fixtures.builders}/systems/x86_64-linux";
      expected = [
        {
          name = "private";
          path = "${fixtures.builders}/systems/x86_64-linux/_private/default.nix";
          private = true;
          target = "x86_64-linux";
        }
        {
          name = "alpha";
          path = "${fixtures.builders}/systems/x86_64-linux/alpha/default.nix";
          private = false;
          target = "x86_64-linux";
        }
      ];
    };
  };

  get-system-builder = {
    testReturnsABuilder = {
      expr = builtins.isFunction (system.get-system-builder "x86_64-linux");
      expected = true;
    };
  };

  get-system-output = {
    testLinux = {
      expr = system.get-system-output "x86_64-linux";
      expected = "nixosConfigurations";
    };

    testDarwin = {
      expr = system.get-system-output "aarch64-darwin";
      expected = "darwinConfigurations";
    };

    testVirtual = {
      expr = system.get-system-output "x86_64-iso";
      expected = "isoConfigurations";
    };
  };

  get-resolved-system-target = {
    testNative = {
      expr = system.get-resolved-system-target "aarch64-darwin";
      expected = "aarch64-darwin";
    };

    testVirtual = {
      expr = system.get-resolved-system-target "x86_64-iso";
      expected = "x86_64-linux";
    };
  };

  create-system = {
    testConstructsALightweightDefinition = {
      expr =
        let
          result = system.create-system {
            path = "${fixtures.builders}/systems/x86_64-linux/alpha/default.nix";
            inherit builder;
            homeManager = false;
            modules = [ "extra-module" ];
            specialArgs.marker = true;
          };
        in
        {
          inherit (result) channelName output system;
          builder-result = result.builder { marker = true; };
          module-count = builtins.length result.modules;
          special-args = {
            inherit (result.specialArgs)
              host
              marker
              target
              virtual
              ;
          };
        };
      expected = {
        channelName = "nixpkgs";
        output = "nixosConfigurations";
        system = "x86_64-linux";
        builder-result.marker = true;
        module-count = 2;
        special-args = {
          host = "alpha";
          marker = true;
          target = "x86_64-linux";
          virtual = false;
        };
      };
    };
  };

  create-systems = {
    testReturnsAnAttributeSet = {
      expr = builtins.isAttrs (system.create-systems { });
      expected = true;
    };
  };
}
