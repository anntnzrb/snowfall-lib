{ lib, ... }: {
  mkFlake.testExportedFunction = {
    expr = builtins.isFunction lib.snowfall.mkFlake;
    expected = true;
  };
}
