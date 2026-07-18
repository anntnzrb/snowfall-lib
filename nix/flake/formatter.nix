{ inputs }:
system:
let
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  shellToolsSupported = system != "riscv64-linux";
  eval = inputs.treefmt-nix.lib.evalModule pkgs {
    projectRootFile = "flake.nix";

    programs = {
      deadnix = {
        enable = true;
        no-lambda-arg = false;
        no-lambda-pattern-names = false;
        no-underscore = false;
      };
      nixfmt = {
        enable = true;
        strict = true;
        width = 80;
      };
      shellcheck = {
        enable = shellToolsSupported;
        external-sources = true;
        extra-checks = [ "all" ];
        severity = "style";
        source-path = "SCRIPTDIR";
      };
      shfmt = {
        enable = shellToolsSupported;
        indent_size = 4;
        simplify = true;
      };
      actionlint.enable = !pkgs.stdenv.isDarwin;
      statix = {
        enable = true;
        disabled-lints = [ ];
      };
    };

    settings.formatter = {
      deadnix.options = [
        "--fail"
        "--warn-used-underscore"
      ];
      nixfmt.options = [ "--verify" ];
      shellcheck.options = [ "--check-sourced" ];
      shfmt.options = [
        "-bn"
        "-ci"
      ];
      statix = {
        command = pkgs.lib.mkForce (
          pkgs.writeShellScriptBin "statix-check" ''
            set -eu
            for file in "$@"; do
              ${pkgs.lib.getExe pkgs.statix} check "$file"
            done
          ''
        );
      };
    };
  };
in
{
  inherit (eval.config.build) devShell wrapper;
  check = eval.config.build.check;
}
