{
  snowfall-lib,
}:
{
  check = {
    ## Create flake output checks.
    ## Example Usage:
    ## ```nix
    ## create-checks { inherit channels; src = ./my-checks; overrides = { inherit another-check; }; alias = { default = "another-check"; }; }
    ## ```
    ## Result:
    ## ```nix
    ## { another-check = ...; my-check = ...; default = ...; }
    ## ```
    #@ Attrs -> Attrs
    create-checks =
      args: snowfall-lib.internal.create-simple-derivations (args // { type = "checks"; });
  };
}
