# Snowfall Lib

<p>
  <a href="https://nixos.wiki/wiki/Flakes" target="_blank"><img alt="Nix Flakes Ready" src="https://img.shields.io/static/v1?logo=nixos&logoColor=d8dee9&label=Nix%20Flakes&labelColor=5e81ac&message=Ready&color=d8dee9&style=for-the-badge"></a>
  <a href="https://nixos.org" target="_blank"><img alt="Linux Ready" src="https://img.shields.io/static/v1?logo=linux&logoColor=d8dee9&label=Linux&labelColor=5e81ac&message=Ready&color=d8dee9&style=for-the-badge"></a>
  <a href="https://github.com/lnl7/nix-darwin" target="_blank"><img alt="macOS Ready" src="https://img.shields.io/static/v1?logo=apple&logoColor=d8dee9&label=macOS&labelColor=5e81ac&message=Ready&color=d8dee9&style=for-the-badge"></a>
  <a href="https://deepwiki.com/anntnzrb/snowfall-lib" target="_blank"><img alt="Ask DeepWiki" src="https://deepwiki.com/badge.svg"></a>
</p>

&nbsp;

> Unified configuration for systems, packages, modules, shells, templates, and more with Nix Flakes.
>
> _Snowfall Lib is built on top of [flake-utils-plus](https://github.com/gytis-ivaskevicius/flake-utils-plus)._

## Get Started

See the Snowfall Lib [Quickstart](https://snowfall.org/guides/lib/quickstart/) guide to start using Snowfall Lib.

## Reference

Looking for Snowfall Lib documentation? See the Snowfall Lib [Reference](https://snowfall.org/reference/lib/).

## Continuous Integration

`./scripts/ci/check-flake.sh` runs the same formatting and flake checks locally and in GitHub Actions.
Pull requests, pushes to `main`, and merge-queue candidates are checked on Linux and macOS.

The weekly lock updater first validates an atomic update of every root input. If that fails, it uses
a bounded divide-and-conquer search to retain compatible inputs without exponential subset enumeration.
Run it manually with **Integrate** disabled to validate and retain the candidate artifact without publishing it.

On an unprotected branch, a validated candidate is integrated with an atomic fast-forward. On a protected
branch, the workflow leaves the pull request to the configured auto-merge or merge-queue policy. Set the
optional `SNOWFALL_AUTOMATION_TOKEN` secret to a fine-grained PAT when automated pull
requests must trigger CI without manual workflow approval.
