{ lib, fixtures }:
let
  flake = lib.snowfall.flake;
  fixture-present = builtins.pathExists fixtures.builders;
in
{
  without-self = {
    testRemovesOnlySelf = {
      expr =
        assert fixture-present;
        flake.without-self {
          self = "drop";
          src = "keep";
          value = 1;
        };
      expected = {
        src = "keep";
        value = 1;
      };
    };

    testLeavesInputWithoutSelfUnchanged = {
      expr = flake.without-self {
        src = "keep";
        value = 1;
      };
      expected = {
        src = "keep";
        value = 1;
      };
    };
  };

  without-src = {
    testRemovesOnlySrc = {
      expr = flake.without-src {
        self = "keep";
        src = "drop";
        value = 1;
      };
      expected = {
        self = "keep";
        value = 1;
      };
    };

    testLeavesInputWithoutSrcUnchanged = {
      expr = flake.without-src {
        self = "keep";
        value = 1;
      };
      expected = {
        self = "keep";
        value = 1;
      };
    };
  };

  without-snowfall-inputs = {
    testRemovesSelfAndSrc = {
      expr = flake.without-snowfall-inputs {
        self = "drop";
        src = "drop";
        value = 1;
      };
      expected.value = 1;
    };

    testAcceptsEmptyInput = {
      expr = flake.without-snowfall-inputs { };
      expected = { };
    };
  };

  without-snowfall-options = {
    testStripsPrivateOptions = {
      expr = flake.without-snowfall-options {
        systems = { };
        homes = { };
        snowfall = { };
        channels.nixpkgs = { };
        description = "keep";
      };
      expected = {
        channels.nixpkgs = { };
        description = "keep";
      };
    };

    testLeavesOrdinaryFlakeOptions = {
      expr = flake.without-snowfall-options {
        description = "keep";
        inputs.nixpkgs.url = "github:nixos/nixpkgs";
      };
      expected = {
        description = "keep";
        inputs.nixpkgs.url = "github:nixos/nixpkgs";
      };
    };
  };

  resolve-exported-home-host-config = {
    testResolvesExplicitHost = {
      expr = flake.resolve-exported-home-host-config {
        home = {
          system = "x86_64-linux";
          specialArgs = {
            host = "workstation";
            user = "alice";
          };
        };
        systems.workstation = {
          output = "nixosConfigurations";
          system = "x86_64-linux";
        };
        flake-outputs.nixosConfigurations.workstation.config.marker = "host-config";
      };
      expected.marker = "host-config";
    };

    testRejectsAmbiguousHostlessHome = {
      expr = flake.resolve-exported-home-host-config {
        home = {
          system = "x86_64-linux";
          specialArgs = {
            host = "";
            user = "alice";
          };
        };
        systems = {
          first = {
            output = "nixosConfigurations";
            system = "x86_64-linux";
          };
          second = {
            output = "nixosConfigurations";
            system = "x86_64-linux";
          };
        };
        flake-outputs.nixosConfigurations = {
          first.config.home-manager.users.alice = { };
          second.config.home-manager.users.alice = { };
        };
      };
      expected = null;
    };
  };

  resolve-exported-home = {
    testFallsBackToExistingExport = {
      expr = flake.resolve-exported-home {
        home-name = "alice@x86_64-linux";
        home = {
          system = "x86_64-linux";
          specialArgs = {
            host = "";
            user = "alice";
          };
        };
        systems = { };
        flake-outputs.homeConfigurations."alice@x86_64-linux" = "existing";
      };
      expected = "existing";
    };

    testRebuildsAHostedHome = {
      expr = flake.resolve-exported-home {
        home-name = "alice@workstation";
        home = {
          modules = [ "home-module" ];
          system = "x86_64-linux";
          specialArgs = {
            host = "workstation";
            user = "alice";
            original = true;
          };
          builder = args: args;
        };
        systems.workstation = {
          output = "nixosConfigurations";
          system = "x86_64-linux";
        };
        flake-outputs = {
          homeConfigurations."alice@workstation" = "fallback";
          nixosConfigurations.workstation.config = {
            marker = "host-config";
            home-manager.extraSpecialArgs.injected = true;
          };
        };
      };
      expected = {
        modules = [ "home-module" ];
        specialArgs = {
          host = "workstation";
          injected = true;
          original = true;
          osConfig = {
            marker = "host-config";
            home-manager.extraSpecialArgs.injected = true;
          };
          systemConfig = {
            marker = "host-config";
            home-manager.extraSpecialArgs.injected = true;
          };
          user = "alice";
        };
      };
    };
  };

  get-libs = {
    testFiltersAndUnwrapsLibraries = {
      expr = flake.get-libs {
        usable.lib.marker = true;
        missing = { };
        scalar.lib = 1;
      };
      expected.usable.marker = true;
    };

    testAcceptsNoInputs = {
      expr = flake.get-libs { };
      expected = { };
    };
  };
}
