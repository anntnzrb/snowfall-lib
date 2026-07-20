{ lib, ... }: {
  mkFlake = {
    testExportedFunction = {
      expr = builtins.isFunction lib.snowfall.mkFlake;
      expected = true;
    };

    testAcceptsAnAttributeSetArgument = {
      expr = builtins.functionArgs lib.snowfall.mkFlake;
      expected = { };
    };
  };
}
