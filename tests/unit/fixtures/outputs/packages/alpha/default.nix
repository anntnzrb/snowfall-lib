{
  system,
  marker ? "alpha",
  ...
}:
builtins.derivation {
  name = marker;
  inherit system;
  builder = "/bin/sh";
  args = [ ];
  meta.platforms = [ system ];
}
