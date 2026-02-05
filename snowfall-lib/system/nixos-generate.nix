{ core-inputs }:
args@{
  format,
  modules ? [ ],
  ...
}:
let
  inherit (core-inputs.nixpkgs) lib;
  nixosModulesPath = core-inputs.nixpkgs + "/nixos/modules";

  nixosArgs = builtins.removeAttrs args [ "format" ];

  mkSystem =
    extraModules:
    lib.nixosSystem (
      nixosArgs
      // {
        modules = modules ++ extraModules;
      }
    );

  mkBuild = extraModules: (mkSystem extraModules).config.system.build;

  getImages =
    config:
    assert lib.assertMsg (
      config.system.build ? images
    ) "Virtual system images require nixpkgs with system.build.images (NixOS 25.05+).";
    config.system.build.images;

  imageVariants = {
    amazon = "amazon";
    azure = "azure";
    cloudstack = "cloudstack";
    do = "digital-ocean";
    gce = "google-compute";
    hyperv = "hyperv";
    iso = "iso";
    kexec = "kexec";
    kubevirt = "kubevirt";
    lxc = "lxc";
    lxc-metadata = "lxc-metadata";
    openstack = "openstack";
    proxmox = "proxmox";
    proxmox-lxc = "proxmox-lxc";
    qcow = "qemu";
    qcow-efi = "qemu-efi";
    raw = "raw";
    raw-efi = "raw-efi";
    sd-aarch64 = "sd-card";
    sd-x86_64 = "sd-card";
    vagrant-virtualbox = "vagrant-virtualbox";
    virtualbox = "virtualbox";
    vmware = "vmware";
  };

  getImageVariant =
    variant:
    let
      inherit ((mkSystem [ ])) config;
      images = getImages config;
    in
    assert lib.assertMsg (lib.hasAttr variant images)
      "Virtual system format '${variant}' is not available in this nixpkgs.";
    images.${variant};

  dockerModule =
    { lib, ... }:
    {
      imports = [ "${nixosModulesPath}/virtualisation/docker-image.nix" ];

      boot.loader.grub.enable = lib.mkForce false;
      boot.loader.systemd-boot.enable = lib.mkForce false;
      services.journald.console = "/dev/console";
    };

  vmModule =
    { lib, ... }:
    {
      imports = [ "${nixosModulesPath}/virtualisation/qemu-vm.nix" ];
      virtualisation.diskSize = lib.mkDefault (2 * 1024);
    };

  vmBootloaderModule =
    { ... }:
    {
      imports = [ vmModule ];
      virtualisation.useBootLoader = true;
    };

  vmNoGuiModule =
    { pkgs, ... }:
    let
      resize = pkgs.writeScriptBin "resize" ''
        if [ -e /dev/tty ]; then
          old=$(stty -g)
          stty raw -echo min 0 time 5
          printf '\033[18t' > /dev/tty
          IFS=';t' read -r _ rows cols _ < /dev/tty
          stty "$old"
          stty cols "$cols" rows "$rows"
        fi
      '';
    in
    {
      imports = [ vmModule ];
      virtualisation.graphics = false;
      virtualisation.qemu.options = [ "-serial mon:stdio" ];

      environment.systemPackages = [ resize ];
      environment.loginShellInit = "${resize}/bin/resize";
    };

  isoModule =
    { ... }:
    {
      imports = [ "${nixosModulesPath}/installer/cd-dvd/iso-image.nix" ];

      isoImage.makeEfiBootable = true;
      isoImage.makeUsbBootable = true;
    };

  installIsoModule =
    { lib, ... }:
    {
      imports = [ "${nixosModulesPath}/installer/cd-dvd/installation-cd-base.nix" ];

      systemd.services.wpa_supplicant.wantedBy = lib.mkForce [ "multi-user.target" ];
      systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
    };

  installIsoHypervModule =
    { lib, ... }:
    {
      imports = [ installIsoModule ];

      systemd.services.wpa_supplicant.wantedBy = lib.mkOverride 40 [ ];
      virtualisation.hypervGuest.enable = true;
    };

  sdAarch64InstallerModule =
    { ... }:
    {
      imports = [ "${nixosModulesPath}/installer/sd-card/sd-image-aarch64-installer.nix" ];
    };

  kexecBundleModule =
    { pkgs, config, ... }:
    let
      kexecTarballPath = "${config.system.build.kexecTarball}/${config.image.filePath}";
      selfExtract = pkgs.writeTextFile {
        executable = true;
        name = "kexec-nixos";
        text = ''
          #!/bin/sh
          set -eu
          ARCHIVE=`awk '/^__ARCHIVE_BELOW__/ { print NR + 1; exit 0; }' $0`

          tail -n+$ARCHIVE $0 | tar xJ -C /
          /kexec_nixos

          exit 1

          __ARCHIVE_BELOW__
        '';
      };
    in
    {
      imports = [ "${nixosModulesPath}/installer/netboot/netboot-minimal.nix" ];

      system.build.kexec_bundle = pkgs.runCommand "kexec_bundle" { } ''
        cat ${selfExtract} ${kexecTarballPath} > $out
        chmod +x $out
      '';
    };

  specialHandlers = {
    docker = (mkBuild [ dockerModule ]).tarball;
    inherit ((mkBuild [ vmModule ])) vm;
    vm-bootloader = (mkBuild [ vmBootloaderModule ]).vm;
    vm-nogui = (mkBuild [ vmNoGuiModule ]).vm;
    iso = (mkBuild [ isoModule ]).isoImage;
    install-iso = (mkBuild [ installIsoModule ]).isoImage;
    install-iso-hyperv = (mkBuild [ installIsoHypervModule ]).isoImage;
    sd-aarch64-installer = (mkBuild [ sdAarch64InstallerModule ]).sdImage;
    kexec-bundle = (mkBuild [ kexecBundleModule ]).kexec_bundle;
  };

  imageHandlers = lib.mapAttrs (_: getImageVariant) imageVariants;
  formatHandlers = imageHandlers // specialHandlers;
in
formatHandlers.${format} or (throw "Unsupported virtual system format '${format}'.")
