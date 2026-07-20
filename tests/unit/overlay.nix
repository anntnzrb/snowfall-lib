{ lib, fixtures }:
let
  system = "x86_64-linux";
  channels.nixpkgs = {
    inherit system;
    stdenv.hostPlatform.system = system;
  };
  previous = {
    inherit system;
    snowfall.existing = true;
  };
in
{
  create-overlays-builder = {
    test-orders-package-extra-and-discovered-overlays = {
      expr =
        let
          overlays =
            (lib.snowfall.overlay.create-overlays-builder {
              src = fixtures.outputs + /overlays;
              extra-overlays = [ (_final: _prev: { extra = true; }) ];
            })
              channels;
          extra-value = (builtins.elemAt overlays 1 { } previous).extra;
        in
        {
          count = builtins.length overlays;
          extra = extra-value;
          discovered = (builtins.elemAt overlays 2 { } previous).color;
        };
      expected = {
        count = 4;
        extra = true;
        discovered = "blue";
      };
    };

    test-empty-input-keeps-package-overlay = {
      expr = builtins.length (
        (lib.snowfall.overlay.create-overlays-builder {
          src = fixtures.outputs + /empty;
        })
          channels
      );
      expected = 1;
    };
  };

  create-overlays = {
    test-discovers-skips-private-and-merges-extra = {
      expr =
        let
          result = lib.snowfall.overlay.create-overlays {
            src = fixtures.outputs + /overlays;
            packages-src = fixtures.outputs + /empty;
            extra-overlays.extra = _final: _prev: { extra = true; };
          };
          color-value = (result.colors { } previous).color;
          extra-value = (result.extra { } previous).extra;
        in
        {
          names = builtins.attrNames result;
          color = color-value;
          extra = extra-value;
        };
      expected = {
        names = [
          "colors"
          "default"
          "extra"
        ];
        color = "blue";
        extra = true;
      };
    };

    test-empty-input-has-default = {
      expr = builtins.attrNames (
        lib.snowfall.overlay.create-overlays {
          src = fixtures.outputs + /empty;
          packages-src = fixtures.outputs + /empty;
        }
      );
      expected = [ "default" ];
    };
  };
}
