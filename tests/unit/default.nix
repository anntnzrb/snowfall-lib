{ lib, nixUnitLib }:
{
  root = nixUnitLib.coverage.addCoverage { inherit (lib.snowfall) mkFlake; } (
    import ./root.nix { inherit lib; }
  );
}
