{
  core-inputs,
  user-inputs,
  snowfall-lib,
  snowfall-config,
}:
let
  inherit (builtins) readDir pathExists;
  inherit (core-inputs.nixpkgs.lib)
    filterAttrs
    mapAttrsToList
    pipe
    ;
in
{
  fs = rec {
    ## Matchers for file kinds. These are often used with `readDir`.
    ## Example Usage:
    ## ```nix
    ## is-file-kind "directory"
    ## ```
    ## Result:
    ## ```nix
    ## false
    ## ```
    #@ String -> Bool
    is-file-kind = kind: kind == "regular";
    is-symlink-kind = kind: kind == "symlink";
    is-directory-kind = kind: kind == "directory";
    is-unknown-kind = kind: kind == "unknown";

    ## Get a file path relative to the user's flake.
    ## Example Usage:
    ## ```nix
    ## get-file "systems"
    ## ```
    ## Result:
    ## ```nix
    ## "/user-source/systems"
    ## ```
    #@ String -> String
    get-file = path: "${user-inputs.src}/${path}";

    ## Get a file path relative to the user's snowfall directory.
    ## Example Usage:
    ## ```nix
    ## get-snowfall-file "systems"
    ## ```
    ## Result:
    ## ```nix
    ## "/user-source/snowfall-dir/systems"
    ## ```
    #@ String -> String
    get-snowfall-file = path: "${snowfall-config.root}/${path}";

    ## Get a file path relative to the this flake.
    ## Example Usage:
    ## ```nix
    ## get-file "systems"
    ## ```
    ## Result:
    ## ```nix
    ## "/user-source/systems"
    ## ```
    #@ String -> String
    internal-get-file = path: "${core-inputs.src}/${path}";

    ## Safely read from a directory if it exists.
    ## Example Usage:
    ## ```nix
    ## safe-read-directory ./some/path
    ## ```
    ## Result:
    ## ```nix
    ## { "my-file.txt" = "regular"; }
    ## ```
    #@ Path -> Attrs
    safe-read-directory = path: if pathExists path then readDir path else { };

    ## Get entries at a given path filtered by kind predicate.
    ## Example Usage:
    ## ```nix
    ## get-entries-by-kind is-directory-kind ./something
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/a-directory" ]
    ## ```
    #@ (String -> Bool) -> Path -> [Path]
    get-entries-by-kind =
      kind-predicate: path:
      pipe (safe-read-directory path) [
        (filterAttrs (_name: kind-predicate))
        (mapAttrsToList (name: _: "${path}/${name}"))
      ];

    ## Get directories at a given path.
    ## Example Usage:
    ## ```nix
    ## get-directories ./something
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/a-directory" ]
    ## ```
    #@ Path -> [Path]
    get-directories = get-entries-by-kind is-directory-kind;

    ## Get directories containing default.nix at a given path.
    ## Example Usage:
    ## ```nix
    ## get-directories-with-default ./systems/x86_64-linux
    ## ```
    ## Result:
    ## ```nix
    ## [ "./systems/x86_64-linux/my-host" ]
    ## ```
    #@ Path -> [Path]
    get-directories-with-default =
      path: builtins.filter (dir: pathExists "${dir}/default.nix") (get-directories path);

    ## Get files at a given path.
    ## Example Usage:
    ## ```nix
    ## get-files ./something
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/a-file" ]
    ## ```
    #@ Path -> [Path]
    get-files = get-entries-by-kind is-file-kind;

    ## Get files at a given path, traversing any directories within.
    ## Example Usage:
    ## ```nix
    ## get-files-recursive ./something
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/some-directory/a-file" ]
    ## ```
    #@ Path -> [Path]
    get-files-recursive =
      path:
      let
        entries = safe-read-directory path;
        filtered-entries = filterAttrs (
          _name: kind: (is-file-kind kind) || (is-directory-kind kind)
        ) entries;
        map-file =
          name: kind:
          let
            path' = "${path}/${name}";
          in
          if is-directory-kind kind then get-files-recursive path' else path';
        files = snowfall-lib.attrs.map-concat-attrs-to-list map-file filtered-entries;
      in
      files;

    ## Filter files at a given path by a predicate.
    ## Example Usage:
    ## ```nix
    ## filter-files (f: baseNameOf f == "foo.nix") ./something
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/foo.nix" ]
    ## ```
    #@ (Path -> Bool) -> Path -> [Path]
    filter-files = predicate: path: builtins.filter predicate (get-files path);

    ## Filter files recursively at a given path by a predicate.
    ## Example Usage:
    ## ```nix
    ## filter-files-recursive (f: baseNameOf f == "foo.nix") ./something
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/sub/foo.nix" ]
    ## ```
    #@ (Path -> Bool) -> Path -> [Path]
    filter-files-recursive = predicate: path: builtins.filter predicate (get-files-recursive path);

    ## Get nix files at a given path.
    ## Example Usage:
    ## ```nix
    ## get-nix-files "./something"
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/a.nix" ]
    ## ```
    #@ Path -> [Path]
    get-nix-files = filter-files (snowfall-lib.path.has-file-extension "nix");

    ## Get nix files at a given path, traversing any directories within.
    ## Example Usage:
    ## ```nix
    ## get-nix-files "./something"
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/a.nix" ]
    ## ```
    #@ Path -> [Path]
    get-nix-files-recursive = filter-files-recursive (snowfall-lib.path.has-file-extension "nix");

    ## Get nix files at a given path named "default.nix".
    ## Example Usage:
    ## ```nix
    ## get-default-nix-files "./something"
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/default.nix" ]
    ## ```
    #@ Path -> [Path]
    get-default-nix-files = filter-files (f: builtins.baseNameOf f == "default.nix");

    ## Get nix files at a given path named "default.nix", traversing any directories within.
    ## Example Usage:
    ## ```nix
    ## get-default-nix-files-recursive "./something"
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/some-directory/default.nix" ]
    ## ```
    #@ Path -> [Path]
    get-default-nix-files-recursive = filter-files-recursive (
      f: builtins.baseNameOf f == "default.nix"
    );

    ## Get nix files at a given path not named "default.nix".
    ## Example Usage:
    ## ```nix
    ## get-non-default-nix-files "./something"
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/a.nix" ]
    ## ```
    #@ Path -> [Path]
    get-non-default-nix-files = filter-files (
      f: snowfall-lib.path.has-file-extension "nix" f && builtins.baseNameOf f != "default.nix"
    );

    ## Get nix files at a given path not named "default.nix", traversing any directories within.
    ## Example Usage:
    ## ```nix
    ## get-non-default-nix-files-recursive "./something"
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/some-directory/a.nix" ]
    ## ```
    #@ Path -> [Path]
    get-non-default-nix-files-recursive = filter-files-recursive (
      f: snowfall-lib.path.has-file-extension "nix" f && builtins.baseNameOf f != "default.nix"
    );
  };
}
