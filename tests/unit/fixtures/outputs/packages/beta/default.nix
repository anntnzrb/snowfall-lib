{ system, ... }:
builtins.derivation {
  name = "beta";
  inherit system;
  builder = "/bin/sh";
  args = [ ];
  meta.platforms = [ system ];
}
