{
  core-inputs,
  user-inputs,
  snowfall-lib,
  snowfall-config,
}:
let
  inherit (core-inputs.flake-utils-plus.lib) filterPackages;
  inherit (core-inputs.nixpkgs.lib)
    fix
    foldl
    callPackageWith
    ;

  user-packages-root = snowfall-lib.fs.get-snowfall-file "packages";
in
{
  package =
    let
      ## Create flake output packages.
      ## Example Usage:
      ## ```nix
      ## create-packages { inherit channels; src = ./my-packages; overrides = { inherit another-package; }; alias.default = "another-package"; }
      ## ```
      ## Result:
      ## ```nix
      ## { another-package = ...; my-package = ...; default = ...; }
      ## ```
      #@ Attrs -> Attrs
      create-packages =
        {
          channels,
          src ? user-packages-root,
          pkgs ? channels.nixpkgs,
          overrides ? { },
          alias ? { },
          namespace ? snowfall-config.namespace,
        }:
        let
          user-packages = snowfall-lib.fs.get-default-nix-files-recursive src;
          merge-packages =
            packages: metadata:
            packages
            // {
              ${metadata.name} = metadata.drv;
            };
          packages-without-aliases = fix (
            packages-without-aliases:
            let
              create-package-metadata =
                package:
                let
                  namespaced-packages = {
                    ${namespace} = packages-without-aliases;
                  };
                  extra-inputs =
                    pkgs
                    // namespaced-packages
                    // {
                      inherit channels namespace;
                      lib = snowfall-lib.internal.system-lib;
                      pkgs = pkgs // namespaced-packages;
                      inputs = user-inputs;
                    };
                in
                {
                  # We are building flake outputs based on file paths. Nix doesn't allow this
                  # so we have to explicitly discard the string's path context to use it as an attribute name.
                  name = builtins.unsafeDiscardStringContext (snowfall-lib.path.get-parent-directory package);
                  drv =
                    let
                      pkg = callPackageWith extra-inputs package { };
                    in
                    pkg
                    // {
                      meta = (pkg.meta or { }) // {
                        snowfall = {
                          path = package;
                        };
                      };
                    };
                };
              packages-metadata = builtins.map create-package-metadata user-packages;
            in
            foldl merge-packages { } packages-metadata
          );
          packages = snowfall-lib.attrs.apply-aliases-and-overrides packages-without-aliases alias overrides;
        in
        filterPackages pkgs.stdenv.hostPlatform.system packages;
    in
    {
      inherit create-packages;
    };
}
