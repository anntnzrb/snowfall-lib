{ lib, fixtures }:
let
  create = lib.snowfall.template.create-templates;
in
{
  create-templates = {
    test-discovers-descriptions-aliases-and-overrides = {
      expr =
        let
          result = create {
            src = fixtures.outputs + /templates;
            alias.default = "basic";
            overrides = {
              basic.extra = true;
              external = {
                path = ./fixtures/outputs/templates/bare;
                description = "External";
              };
            };
          };
        in
        {
          names = builtins.attrNames result;
          description = result.basic.description;
          extra = result.basic.extra;
          alias-description = result.default.description;
          external-description = result.external.description;
          bare-has-description = result.bare ? description;
        };
      expected = {
        names = [
          "bare"
          "basic"
          "default"
          "external"
        ];
        description = "Basic fixture";
        extra = true;
        alias-description = "Basic fixture";
        external-description = "External";
        bare-has-description = false;
      };
    };

    test-empty-input-and-unused-override = {
      expr = create {
        src = fixtures.outputs + /empty;
        overrides.only = {
          path = fixtures.outputs + /templates/bare;
        };
      };
      expected.only.path = fixtures.outputs + /templates/bare;
    };

  };
}
