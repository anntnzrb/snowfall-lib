{
  core-inputs,
  user-inputs,
  snowfall-lib,
  snowfall-config,
}:
let
  inherit (builtins) dirOf baseNameOf;
  inherit (core-inputs.nixpkgs.lib)
    assertMsg
    fix
    hasInfix
    concatMap
    foldl
    optionals
    singleton
    ;

  virtual-systems = import ./virtual-systems.nix;

  user-systems-root = snowfall-lib.fs.get-snowfall-file "systems";
  user-modules-root = snowfall-lib.fs.get-snowfall-file "modules";
in
{
  system =
    let
      ## Get the name of a system based on its file path.
      ## Example Usage:
      ## ```nix
      ## get-inferred-system-name "/systems/my-system/default.nix"
      ## ```
      ## Result:
      ## ```nix
      ## "my-system"
      ## ```
      #@ Path -> String
      get-inferred-system-name =
        path:
        if snowfall-lib.path.has-file-extension "nix" path then
          snowfall-lib.path.get-parent-directory path
        else
          baseNameOf path;

      ## Check whether a named system is macOS.
      ## Example Usage:
      ## ```nix
      ## is-darwin "x86_64-linux"
      ## ```
      ## Result:
      ## ```nix
      ## false
      ## ```
      #@ String -> Bool
      is-darwin = hasInfix "darwin";

      ## Check whether a named system is Linux.
      ## Example Usage:
      ## ```nix
      ## is-linux "x86_64-linux"
      ## ```
      ## Result:
      ## ```nix
      ## false
      ## ```
      #@ String -> Bool
      is-linux = hasInfix "linux";

      ## Check whether a named system is virtual.
      ## Example Usage:
      ## ```nix
      ## is-virtual "x86_64-iso"
      ## ```
      ## Result:
      ## ```nix
      ## true
      ## ```
      #@ String -> Bool
      is-virtual = target: (get-virtual-system-type target) != "";

      ## Get the virtual system type of a system target.
      ## Example Usage:
      ## ```nix
      ## get-virtual-system-type "x86_64-iso"
      ## ```
      ## Result:
      ## ```nix
      ## "iso"
      ## ```
      #@ String -> String
      get-virtual-system-type =
        target:
        foldl (
          result: virtual-system:
          if result == "" && hasInfix virtual-system target then virtual-system else result
        ) "" virtual-systems;

      ## Get structured data about all systems for a given target.
      ## Example Usage:
      ## ```nix
      ## get-target-systems-metadata "x86_64-linux"
      ## ```
      ## Result:
      ## ```nix
      ## [ { target = "x86_64-linux"; name = "my-machine"; path = "/systems/x86_64-linux/my-machine"; } ]
      ## ```
      #@ String -> [Attrs]
      get-target-systems-metadata =
        target:
        let
          existing-systems = snowfall-lib.fs.get-directories-with-default target;
          create-system-metadata = path: {
            path = "${path}/default.nix";
            # We are building flake outputs based on file contents. Nix doesn't like this
            # so we have to explicitly discard the string's path context to allow us to
            # use the name as a variable.
            name = builtins.unsafeDiscardStringContext (builtins.baseNameOf path);
            # We are building flake outputs based on file contents. Nix doesn't like this
            # so we have to explicitly discard the string's path context to allow us to
            # use the name as a variable.
            target = builtins.unsafeDiscardStringContext (builtins.baseNameOf target);
          };
          system-configurations = builtins.map create-system-metadata existing-systems;
        in
        system-configurations;

      ## Get the system builder for a given target.
      ## Example Usage:
      ## ```nix
      ## get-system-builder "x86_64-iso"
      ## ```
      ## Result:
      ## ```nix
      ## (args: <system>)
      ## ```
      #@ String -> Function
      get-system-builder =
        target:
        let
          virtual-system-type = get-virtual-system-type target;
          get-image-variant =
            virtual-format:
            {
              "install-iso" = "iso-installer";
              "install-iso-hyperv" = "iso-installer";
              "kexec-bundle" = "kexec";
              "sd-aarch64" = "sd-card";
              "sd-aarch64-installer" = "sd-card";
              "sd-x86_64" = "sd-card";
            }.${virtual-format} or virtual-format;
          nixos-system-builder =
            format:
            args:
            core-inputs.nixpkgs.lib.nixosSystem (
              args
              // {
                specialArgs = args.specialArgs // {
                  inherit format;
                };
                modules = args.modules ++ [
                  ../../modules/nixos/user/default.nix
                ];
              }
            );
          virtual-system-builder =
            args:
            let
              extra-modules =
                if virtual-system-type == "vm-nogui" then
                  [
                    {
                      virtualisation.graphics = false;
                    }
                  ]
                else
                  [ ];
              system-config = nixos-system-builder virtual-system-type (
                args
                // {
                  modules = args.modules ++ extra-modules;
                }
              );
              image-variant = get-image-variant virtual-system-type;
              image-output =
                builtins.attrByPath [
                  "system"
                  "build"
                  "images"
                  image-variant
                ] null system-config.config;
            in
            if virtual-system-type == "vm" then
              system-config.config.system.build.vm
            else if virtual-system-type == "vm-bootloader" then
              system-config.config.system.build.vmWithBootLoader
            else if virtual-system-type == "vm-nogui" then
              system-config.config.system.build.vm
            else
              assert assertMsg (
                image-output != null
              ) "In order to create ${virtual-system-type} systems, nixpkgs must provide the `${image-variant}` image variant. See the NixOS manual for supported nixos-rebuild build-image variants.";
              image-output
          darwin-system-builder =
            args:
            assert assertMsg (
              user-inputs ? darwin
            ) "In order to create virtual systems, you must include `darwin` as a flake input.";
            user-inputs.darwin.lib.darwinSystem (
              (builtins.removeAttrs args [
                "system"
                "modules"
              ])
              // {
                specialArgs = args.specialArgs // {
                  format = "darwin";
                };
                modules = args.modules ++ [
                  ../../modules/darwin/user/default.nix
                ];
              }
            );
          linux-system-builder =
            nixos-system-builder "linux";
        in
        if virtual-system-type != "" then
          virtual-system-builder
        else if is-darwin target then
          darwin-system-builder
        else
          linux-system-builder;

      ## Get the flake output attribute for a system target.
      ## Example Usage:
      ## ```nix
      ## get-system-output "aarch64-darwin"
      ## ```
      ## Result:
      ## ```nix
      ## "darwinConfigurations"
      ## ```
      #@ String -> String
      get-system-output =
        target:
        let
          virtual-system-type = get-virtual-system-type target;
        in
        if virtual-system-type != "" then
          "${virtual-system-type}Configurations"
        else if is-darwin target then
          "darwinConfigurations"
        else
          "nixosConfigurations";

      ## Get the resolved (non-virtual) system target.
      ## Example Usage:
      ## ```nix
      ## get-resolved-system-target "x86_64-iso"
      ## ```
      ## Result:
      ## ```nix
      ## "x86_64-linux"
      ## ```
      #@ String -> String
      get-resolved-system-target =
        target:
        let
          virtual-system-type = get-virtual-system-type target;
        in
        if virtual-system-type != "" then
          builtins.replaceStrings [ virtual-system-type ] [ "linux" ] target
        else
          target;

      ## Create a system.
      ## Example Usage:
      ## ```nix
      ## create-system { path = ./systems/my-system; }
      ## ```
      ## Result:
      ## ```nix
      ## <flake-utils-plus-system-configuration>
      ## ```
      #@ Attrs -> Attrs
      create-system =
        {
          target ? "x86_64-linux",
          system ? get-resolved-system-target target,
          path,
          name ? builtins.unsafeDiscardStringContext (get-inferred-system-name path),
          modules ? [ ],
          specialArgs ? { },
          channelName ? "nixpkgs",
          builder ? get-system-builder target,
          output ? get-system-output target,
          systems ? { },
          homes ? { },
        }:
        let
          lib = snowfall-lib.internal.system-lib;
          home-system-modules = snowfall-lib.home.create-home-system-modules homes;
          home-manager-module =
            if is-darwin system then
              user-inputs.home-manager.darwinModules.home-manager
            else
              user-inputs.home-manager.nixosModules.home-manager;
          home-manager-modules = [ home-manager-module ] ++ home-system-modules;
        in
        {
          inherit
            channelName
            system
            builder
            output
            ;

          modules = [ path ] ++ modules ++ (optionals (user-inputs ? home-manager) home-manager-modules);

          specialArgs = specialArgs // {
            inherit
              target
              system
              systems
              lib
              ;
            host = name;

            virtual = (get-virtual-system-type target) != "";
            inputs = snowfall-lib.flake.without-src user-inputs;
            namespace = snowfall-config.namespace;
          };
        };

      ## Create all available systems.
      ## Example Usage:
      ## ```nix
      ## create-systems { hosts.my-host.specialArgs.x = true; modules.nixos = [ my-shared-module ]; }
      ## ```
      ## Result:
      ## ```nix
      ## { my-host = <flake-utils-plus-system-configuration>; }
      ## ```
      #@ Attrs -> Attrs
      create-systems =
        {
          systems ? { },
          homes ? { },
        }:
        let
          targets = snowfall-lib.fs.get-directories user-systems-root;
          target-systems-metadata = concatMap get-target-systems-metadata targets;
          user-nixos-modules = snowfall-lib.module.create-modules {
            src = "${user-modules-root}/nixos";
          };
          user-darwin-modules = snowfall-lib.module.create-modules {
            src = "${user-modules-root}/darwin";
          };
          nixos-modules = systems.modules.nixos or [ ];
          darwin-modules = systems.modules.darwin or [ ];

          create-system' =
            created-systems: system-metadata:
            let
              overrides = systems.hosts.${system-metadata.name} or { };
              user-modules = if is-darwin system-metadata.target then user-darwin-modules else user-nixos-modules;
              user-modules-list = builtins.attrValues user-modules;
              system-modules = if is-darwin system-metadata.target then darwin-modules else nixos-modules;
            in
            {
              ${system-metadata.name} = create-system (
                overrides
                // system-metadata
                // {
                  systems = created-systems;
                  modules = user-modules-list ++ (overrides.modules or [ ]) ++ system-modules;
                  inherit homes;
                }
              );
            };
          created-systems = fix (
            created-systems:
            foldl (
              systems: system-metadata: systems // (create-system' created-systems system-metadata)
            ) { } target-systems-metadata
          );
        in
        created-systems;
    in
    {
      inherit
        get-inferred-system-name
        is-darwin
        is-linux
        is-virtual
        get-virtual-system-type
        get-target-systems-metadata
        get-system-builder
        get-system-output
        get-resolved-system-target
        create-system
        create-systems
        ;
    };
}
