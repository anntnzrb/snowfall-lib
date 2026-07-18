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
    formatting = formatter system;
  in
  {
    formatter = formatting.wrapper;

    devShells.default = formatting.devShell;

    checks = import ./checks.nix {
      inherit
        inputs
        self
        mkLib
        formatting
        system
        ;
    };
  }
)
