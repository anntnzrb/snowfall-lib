{ system, ... }:
builtins.derivation {
  name = "lint-check";
  inherit system;
  builder = "/bin/sh";
  args = [ ];
  meta.platforms = [ system ];
}
