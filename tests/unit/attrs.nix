{ lib, fixtures }:
let
  attrs = lib.snowfall.attrs;
in
assert fixtures ? pure;
{
  map-concat-attrs-to-list = {
    testFlattensMappedValues = {
      expr =
        attrs.map-concat-attrs-to-list
          (name: value: [
            name
            value
          ])
          {
            a = 1;
            b = 2;
          };
      expected = [
        "a"
        1
        "b"
        2
      ];
    };
    testEmpty = {
      expr = attrs.map-concat-attrs-to-list (_: _: [ "unreachable" ]) { };
      expected = [ ];
    };
  };

  merge-deep = {
    testRecursiveMerge = {
      expr = attrs.merge-deep [
        { nested.left = 1; }
        { nested.right = 2; }
      ];
      expected = {
        nested = {
          left = 1;
          right = 2;
        };
      };
    };
    testEmpty = {
      expr = attrs.merge-deep [ ];
      expected = { };
    };
    testLaterValueWins = {
      expr = attrs.merge-deep [
        { value = 1; }
        { value = 2; }
      ];
      expected = {
        value = 2;
      };
    };
  };

  merge-shallow = {
    testRootMerge = {
      expr = attrs.merge-shallow [
        { a = 1; }
        { b = 2; }
      ];
      expected = {
        a = 1;
        b = 2;
      };
    };
    testEmpty = {
      expr = attrs.merge-shallow [ ];
      expected = { };
    };
    testReplacesNestedValue = {
      expr = attrs.merge-shallow [
        { nested.a = 1; }
        { nested.b = 2; }
      ];
      expected = {
        nested.b = 2;
      };
    };
  };

  merge-shallow-packages = {
    testMergesOneAttributeLayer = {
      expr = attrs.merge-shallow-packages [
        {
          group.a = 1;
          plain = 1;
        }
        {
          group.b = 2;
          plain = 2;
        }
      ];
      expected = {
        group = {
          a = 1;
          b = 2;
        };
        plain = 2;
      };
    };
    testEmpty = {
      expr = attrs.merge-shallow-packages [ ];
      expected = { };
    };
    testKeepsDerivationOpaque = {
      expr =
        let
          drv = {
            type = "derivation";
            name = "fake";
          };
        in
        (attrs.merge-shallow-packages [
          {
            package = {
              stale = true;
            };
          }
          { package = drv; }
        ]).package;
      expected = {
        type = "derivation";
        name = "fake";
      };
    };
  };

  merge-with-aliases = {
    testAddsAliases = {
      expr = attrs.merge-with-aliases (left: right: left // right) [
        { one = 1; }
        { two = 2; }
      ] { default = "two"; };
      expected = {
        one = 1;
        two = 2;
        default = 2;
      };
    };
    testEmpty = {
      expr = attrs.merge-with-aliases (left: right: left // right) [ ] { };
      expected = { };
    };
  };

  apply-aliases-and-overrides = {
    testAliasAndOverridePrecedence = {
      expr =
        attrs.apply-aliases-and-overrides
          {
            one = 1;
            two = 2;
          }
          { default = "one"; }
          {
            two = 20;
            extra = 3;
          };
      expected = {
        one = 1;
        two = 20;
        default = 1;
        extra = 3;
      };
    };
    testEmptyMetadata = {
      expr = attrs.apply-aliases-and-overrides { one = 1; } { } { };
      expected = {
        one = 1;
      };
    };
    testOverrideReplacesAlias = {
      expr = attrs.apply-aliases-and-overrides { one = 1; } { selected = "one"; } {
        selected = 9;
      };
      expected = {
        one = 1;
        selected = 9;
      };
    };
  };
}
