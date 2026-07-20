_: {
  system.stateVersion = "24.11";
  boot.loader.grub.enable = false;
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };
}
