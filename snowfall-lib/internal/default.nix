{
  core-inputs,
  user-inputs,
  snowfall-lib,
  snowfall-config,
}:
let
  inherit (core-inputs.nixpkgs.lib)
    fix
    filterAttrs
    callPackageWith
    isFunction
    ;

  inherit (core-inputs.flake-utils-plus.lib) filterPackages;

  core-inputs-libs = snowfall-lib.flake.get-libs (snowfall-lib.flake.without-self core-inputs);
  user-inputs-libs = snowfall-lib.flake.get-libs (snowfall-lib.flake.without-self user-inputs);

  snowfall-top-level-lib = filterAttrs (name: value: !builtins.isAttrs value) snowfall-lib;

  base-lib = snowfall-lib.attrs.merge-shallow [
    core-inputs.nixpkgs.lib
    core-inputs-libs
    user-inputs-libs
    snowfall-top-level-lib
    { snowfall = snowfall-lib; }
  ];

  user-lib-root = snowfall-lib.fs.get-snowfall-file "lib";
  user-lib-modules = snowfall-lib.fs.get-default-nix-files-recursive user-lib-root;

  user-lib = fix (
    user-lib:
    let
      attrs = {
        inputs = snowfall-lib.flake.without-snowfall-inputs user-inputs;
        snowfall-inputs = core-inputs;
        namespace = snowfall-config.namespace;
        lib = snowfall-lib.attrs.merge-shallow [
          base-lib
          { "${snowfall-config.namespace}" = user-lib; }
        ];
      };
      libs = builtins.map (
        path:
        let
          imported-module = import path;
        in
        if isFunction imported-module then
          callPackageWith attrs path { }
        # the only difference is that there is no `override` and `overrideDerivation` on returned value
        else
          imported-module
      ) user-lib-modules;
    in
    snowfall-lib.attrs.merge-deep libs
  );

  system-lib = snowfall-lib.attrs.merge-shallow [
    base-lib
    { "${snowfall-config.namespace}" = user-lib; }
  ];
in
{
  internal = {
    inherit system-lib user-lib;

    create-simple-derivations =
      {
        type,
        channels,
        src ? snowfall-lib.fs.get-snowfall-file type,
        pkgs ? channels.nixpkgs,
        overrides ? { },
        alias ? { },
      }:
      let
        user-items = snowfall-lib.fs.get-default-nix-files-recursive src;

        create-metadata = item: {
          name = snowfall-lib.path.get-output-name item;
          drv = callPackageWith (
            pkgs
            // {
              inherit channels;
              lib = system-lib;
              inputs = snowfall-lib.flake.without-src user-inputs;
              namespace = snowfall-config.namespace;
            }
          ) item { };
        };

        items-metadata = builtins.map create-metadata user-items;

        merge-items = items: metadata: items // { ${metadata.name} = metadata.drv; };

        items = snowfall-lib.attrs.merge-with-aliases merge-items items-metadata alias // overrides;
      in
      filterPackages pkgs.stdenv.hostPlatform.system items;
  };
}
