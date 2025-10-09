{
  core-inputs,
  user-inputs,
  snowfall-lib,
  snowfall-config,
}:
let
  inherit (core-inputs.nixpkgs.lib)
    assertMsg
    mapAttrsToList
    mapAttrs
    flatten
    foldl
    recursiveUpdate
    mergeAttrs
    isDerivation
    ;
in
{
  attrs = {
    ## Map and flatten an attribute set into a list.
    ## Example Usage:
    ## ```nix
    ## map-concat-attrs-to-list (name: value: [name value]) { x = 1; y = 2; }
    ## ```
    ## Result:
    ## ```nix
    ## [ "x" 1 "y" 2 ]
    ## ```
    #@ (a -> b -> [c]) -> Attrs -> [c]
    map-concat-attrs-to-list = f: attrs: flatten (mapAttrsToList f attrs);

    ## Recursively merge a list of attribute sets.
    ## Example Usage:
    ## ```nix
    ## merge-deep [{ x = 1; } { x = 2; }]
    ## ```
    ## Result:
    ## ```nix
    ## { x = 2; }
    ## ```
    #@ [Attrs] -> Attrs
    merge-deep = foldl recursiveUpdate { };

    ## Merge the root of a list of attribute sets.
    ## Example Usage:
    ## ```nix
    ## merge-shallow [{ x = 1; } { x = 2; }]
    ## ```
    ## Result:
    ## ```nix
    ## { x = 2; }
    ## ```
    #@ [Attrs] -> Attrs
    merge-shallow = foldl mergeAttrs { };

    ## Merge shallow for packages, but allow one deeper layer of attribute sets.
    ## Example Usage:
    ## ```nix
    ## merge-shallow-packages [ { inherit (pkgs) vim; some.value = true; } { some.value = false; } ]
    ## ```
    ## Result:
    ## ```nix
    ## { vim = ...; some.value = false; }
    ## ```
    #@ [Attrs] -> Attrs
    merge-shallow-packages =
      items:
      foldl (
        result: item:
        result
        // (mapAttrs (
          name: value:
          if isDerivation value then
            value
          else if builtins.isAttrs value then
            (result.${name} or { }) // value
          else
            value
        ) item)
      ) { } items;

    ## Merge items with a merge function and apply aliases
    ## Example Usage:
    ## ```nix
    ## merge-with-aliases merge-packages packages-metadata alias
    ## ```
    ## Result: Merged items with aliases applied
    #@ (Attrs -> Attrs -> Attrs) -> [Attrs] -> Attrs -> Attrs
    merge-with-aliases = merge-fn: items: alias:
      let
        items-without-aliases = foldl merge-fn { } items;
        aliased-items = mapAttrs (name: value: items-without-aliases.${value}) alias;
      in
      items-without-aliases // aliased-items;
  };
}
