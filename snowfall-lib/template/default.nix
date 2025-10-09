{
  core-inputs,
  user-inputs,
  snowfall-lib,
  snowfall-config,
}:
let
  inherit (builtins) baseNameOf;
  inherit (core-inputs.nixpkgs.lib) assertMsg foldl mapAttrs;

  user-templates-root = snowfall-lib.fs.get-snowfall-file "templates";
in
{
  template = {
    ## Create flake templates.
    ##
    ## Example Usage:
    ## ```nix
    ## create-templates { src = ./my-templates; overrides = { inherit another-template; }; alias = { default = "another-template"; }; }
    ## ```
    ##
    ## Result:
    ## ```nix
    ## { another-template = ...; my-template = ...; default = ...; }
    ## ```
    #@ Attrs -> Attrs
    create-templates =
      {
        src ? user-templates-root,
        overrides ? { },
        alias ? { },
      }:
      let
        user-templates = snowfall-lib.fs.get-directories src;
        create-template-metadata =
          template:
          let
            flake-file = template + "/flake.nix";
            has-flake = builtins.pathExists flake-file;
            flake-attrs = if has-flake then import flake-file else { };
            description = flake-attrs.description or null;
          in
          {
            name = snowfall-lib.path.get-directory-name template;
            path = template;
          }
          // (if description != null then { inherit description; } else { });
        templates-metadata = builtins.map create-template-metadata user-templates;
        merge-templates =
          templates: metadata:
          templates
          // {
            ${metadata.name} =
              (overrides.${metadata.name} or { }) // (builtins.removeAttrs metadata [ "name" ]);
          };
        unused-overrides = builtins.removeAttrs overrides (
          builtins.map (metadata: metadata.name) templates-metadata
        );
        templates =
          snowfall-lib.attrs.merge-with-aliases merge-templates templates-metadata alias // unused-overrides;
      in
      templates;
  };
}
