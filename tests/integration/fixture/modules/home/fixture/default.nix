{ lib, ... }: {
  options.fixture.sharedHomeModule = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
  config.fixture.sharedHomeModule = true;
}
