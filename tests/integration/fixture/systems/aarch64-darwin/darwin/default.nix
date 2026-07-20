{ lib, fixtureSpecialArg, ... }: {
  options.fixture = {
    integration = lib.mkOption { type = lib.types.str; };
    specialArg = lib.mkOption { type = lib.types.str; };
  };
  config = {
    system.stateVersion = 5;
    fixture = {
      integration = "darwin";
      specialArg = fixtureSpecialArg;
    };
  };
}
