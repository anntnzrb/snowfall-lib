{ system, ... }:
builtins.derivation {
  name = "dev-shell";
  inherit system;
  builder = "/bin/sh";
  args = [ ];
  meta.platforms = [ system ];
}
