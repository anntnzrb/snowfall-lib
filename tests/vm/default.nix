/*
  Two minimal x86_64-linux NixOS VM tests.

  Interface:
    import ./tests/vm {
      snowfall = self; # exposes mkFlake
      inherit inputs;
      pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux; # optional
    }

  Required inputs: nixpkgs, flake-utils-plus, home-manager. The returned attrset
  contains `generated-host` and `hosted-home`, both runNixOSTest derivations.
*/
{
  snowfall,
  inputs,
  pkgs ? inputs.nixpkgs.legacyPackages.x86_64-linux,
}:
assert inputs ? home-manager;
let
  system = "x86_64-linux";
  library = snowfall.mkLib {
    inputs = inputs // {
      self = outputs;
    };
    src = ./fixture;
    snowfall.namespace = "vmfixture";
  };
  outputs = snowfall.mkFlake {
    inputs = inputs // {
      self = outputs;
    };
    src = ./fixture;
    snowfall.namespace = "vmfixture";
    systems.hosts.vm.specialArgs.vmSentinel = "special-arg-discovered";
    homes.users."tester@vm".specialArgs.hmSentinel = "hosted-home-discovered";
  };
  generated = outputs.nixosConfigurations.vm.config;
  hosted = outputs.homeConfigurations."tester@vm".config;
  definition =
    (library.snowfall.system.create-systems {
      systems.hosts.vm.specialArgs.vmSentinel = "special-arg-discovered";
      homes.users."tester@vm".specialArgs.hmSentinel = "hosted-home-discovered";
    }).vm;
  discoveredNode = {
    imports = definition.modules ++ [ ../../modules/nixos/user/default.nix ];
    environment.systemPackages = [ outputs.packages.${system}.vm-package ];
  };
  discoveredSpecialArgs = definition.specialArgs // {
    format = "linux";
  };
in
{
  generated-host =
    assert generated.vmFixture.module == "special-arg-discovered";
    assert outputs.packages.${system}.vm-package.name == "vm-package";
    pkgs.testers.runNixOSTest {
      name = "snowfall-generated-host";
      node.specialArgs = discoveredSpecialArgs;
      nodes.machine = discoveredNode;
      testScript = ''
        start_all()
        machine.wait_for_unit("multi-user.target")
        machine.succeed("test -e /etc/snowfall-vm-module")
        machine.succeed("grep -Fx special-arg-discovered /etc/snowfall-vm-module")
        machine.succeed("vm-package | grep -Fx package-discovered")
      '';
    };

  hosted-home =
    assert hosted.vmFixture.home == "hosted-home-discovered";
    assert hosted.vmFixture.parent == "special-arg-discovered";
    assert hosted.vmFixture.systemParent == "special-arg-discovered";
    pkgs.testers.runNixOSTest {
      name = "snowfall-hosted-home";
      node.specialArgs = discoveredSpecialArgs;
      nodes.machine = discoveredNode;
      testScript = ''
        start_all()
        machine.wait_for_unit("home-manager-tester.service")
        machine.succeed("grep -Fx hosted-home-discovered /home/tester/.snowfall-hosted-home")
        machine.succeed("grep -Fx special-arg-discovered /home/tester/.snowfall-parent-config")
      '';
    };
}
