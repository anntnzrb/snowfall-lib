{
  inputs,
  self,
  systems,
  mkLib,
}:
let
  formatter = import ./formatter.nix { inherit inputs; };
in
inputs.flake-utils-plus.lib.eachSystem systems (
  system:
  let
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    formatting = formatter system;
    pre-commit = inputs.pre-commit-hooks.lib.${system}.run {
      src = self;
      package = pkgs.prek;

      hooks.treefmt = {
        enable = true;
        name = "treefmt";
        entry = "${formatting.wrapper}/bin/treefmt --ci";
        pass_filenames = false;
      };
    };
  in
  {
    formatter = formatting.wrapper;

    devShells.default = pkgs.mkShell {
      inputsFrom = [ formatting.devShell ];
      packages = pre-commit.enabledPackages;
      inherit (pre-commit) shellHook;
    };

    checks = import ./checks.nix {
      inherit
        inputs
        self
        mkLib
        pre-commit
        system
        ;
    };
  }
)
