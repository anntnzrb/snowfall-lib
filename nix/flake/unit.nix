{
  inputs,
  self,
  system,
}:
let
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  nix-unit = inputs.nix-unit.packages.${system}.default.overrideAttrs (old: {
    nativeBuildInputs = pkgs.lib.flatten (old.nativeBuildInputs or [ ]);
  });
in
pkgs.runCommand "snowfall-lib-unit-tests" { nativeBuildInputs = [ nix-unit ]; }
  ''
    export HOME="$TMPDIR"
    nix-unit \
      --eval-store "$HOME" \
      --extra-experimental-features flakes \
      --override-input nixpkgs ${inputs.nixpkgs} \
      --flake path:${self}#tests
    touch "$out"
  ''
