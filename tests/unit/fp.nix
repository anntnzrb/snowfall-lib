{ lib, fixtures }:
let
  fp = lib.snowfall.fp;
in
assert fixtures ? pure;
{
  compose = {
    testCompositionOrder = {
      expr = fp.compose (x: x * 2) (x: x + 3) 4;
      expected = 14;
    };
    testHandlesIdentity = {
      expr = fp.compose (x: x) (x: x) "value";
      expected = "value";
    };
  };
  call = {
    testCallsFunction = {
      expr = fp.call (x: x + 1) 4;
      expected = 5;
    };
    testPassesNull = {
      expr = fp.call (x: x) null;
      expected = null;
    };
  };
  compose-all = {
    testComposesMany = {
      expr = fp.compose-all [
        (x: x * 2)
        (x: x + 3)
        (x: x - 1)
      ] 5;
      expected = 14;
    };
    testEmptyIsIdentity = {
      expr = fp.compose-all [ ] { value = true; };
      expected = {
        value = true;
      };
    };
    testSingleFunction = {
      expr = fp.compose-all [ (x: !x) ] false;
      expected = true;
    };
  };
  apply = {
    testAppliesArgument = {
      expr = fp.apply 4 (x: x + 1);
      expected = 5;
    };
    testAppliesNull = {
      expr = fp.apply null builtins.isNull;
      expected = true;
    };
  };
}
