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
    systemParentMarker = lib.mkOption { type = lib.types.str; };
  };
  config = {
    home.stateVersion = "24.11";
    fixture = {
      integration = "hosted";
      specialArg = fixtureHomeArg;
      parentMarker = osConfig.fixture.parentMarker;
      systemParentMarker = systemConfig.fixture.parentMarker;
    };
  };
}
