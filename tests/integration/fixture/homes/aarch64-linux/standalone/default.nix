{
  lib,
  fixtureHomeArg,
  osConfig,
  systemConfig,
  ...
}:
{
  options.fixture = {
    integration = lib.mkOption { type = lib.types.str; };
    specialArg = lib.mkOption { type = lib.types.str; };
    parentMarker = lib.mkOption { type = lib.types.str; };
  };
  config = {
    home.stateVersion = "24.11";
    fixture = {
      integration = "standalone";
      specialArg = fixtureHomeArg;
      parentMarker =
        if osConfig == null && systemConfig == null then
          "standalone"
        else
          "unexpected-parent";
    };
  };
}
