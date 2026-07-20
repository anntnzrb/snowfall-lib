{ lib, vmSentinel, ... }: {
  options.vmFixture.module = lib.mkOption { type = lib.types.str; };
  config = {
    vmFixture.module = vmSentinel;
    environment.etc."snowfall-vm-module".text = vmSentinel;
  };
}
