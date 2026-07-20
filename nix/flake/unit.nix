{
  inputs,
  self,
  system,
}:
let
  pkgs = inputs.nixpkgs.legacyPackages.${system};
in
pkgs.runCommand "snowfall-lib-unit-tests"
  { nativeBuildInputs = [ inputs.nix-unit.packages.${system}.default ]; }
  ''
    export HOME="$TMPDIR"
    nix-unit \
      --eval-store "$HOME" \
      --extra-experimental-features flakes \
      --override-input nixpkgs ${inputs.nixpkgs} \
      --flake path:${self}#tests
    touch "$out"
  ''
