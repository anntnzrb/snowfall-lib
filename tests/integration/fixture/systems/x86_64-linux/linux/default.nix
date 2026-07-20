{ lib, fixtureSpecialArg, ... }: {
  options.fixture = {
    integration = lib.mkOption { type = lib.types.str; };
    specialArg = lib.mkOption { type = lib.types.str; };
    parentMarker = lib.mkOption {
      type = lib.types.str;
      default = "linux-parent";
    };
  };
  config = {
    system.stateVersion = "24.11";
    boot.loader.grub.enable = false;
    fileSystems."/" = {
      device = "none";
      fsType = "tmpfs";
    };
    fixture = {
      integration = "nixos";
      specialArg = fixtureSpecialArg;
    };
  };
}
