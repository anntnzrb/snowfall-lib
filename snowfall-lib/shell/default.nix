{
  snowfall-lib,
}:
{
  shell = {
    ## Create flake output shells.
    ## Example Usage:
    ## ```nix
    ## create-shells { inherit channels; src = ./my-shells; overrides = { inherit another-shell; }; alias = { default = "another-shell"; }; }
    ## ```
    ## Result:
    ## ```nix
    ## { another-shell = ...; my-shell = ...; default = ...; }
    ## ```
    #@ Attrs -> Attrs
    create-shells =
      args: snowfall-lib.internal.create-simple-derivations (args // { type = "shells"; });
  };
}
