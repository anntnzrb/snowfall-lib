{ lib, ... }: {
  options.fixture.publicModule = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
  config.fixture.publicModule = true;
}
