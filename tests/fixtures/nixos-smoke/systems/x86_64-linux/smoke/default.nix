_: {
  boot.loader.grub.enable = false;

  fileSystems."/" = {
    device = "/dev/null";
    fsType = "ext4";
  };

  system.stateVersion = "26.11";
}
