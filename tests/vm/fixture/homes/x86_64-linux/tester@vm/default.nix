{
  lib,
  hmSentinel,
  osConfig,
  systemConfig,
  ...
}:
{
  options.vmFixture = {
    home = lib.mkOption { type = lib.types.str; };
    parent = lib.mkOption { type = lib.types.str; };
    systemParent = lib.mkOption { type = lib.types.str; };
  };
  config = {
    home = {
      stateVersion = "24.11";
      file.".snowfall-hosted-home".text = hmSentinel;
      file.".snowfall-parent-config".text = osConfig.vmFixture.module;
    };
    vmFixture = {
      home = hmSentinel;
      parent = osConfig.vmFixture.module;
      systemParent = systemConfig.vmFixture.module;
    };
  };
}
