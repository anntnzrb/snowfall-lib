#!/bin/sh

set -eu

nix fmt -- --ci

if [ "$(uname -s)" = "Linux" ]; then
  nix flake check path:. \
    --all-systems \
    --no-build \
    --no-eval-cache \
    --no-update-lock-file \
    --no-write-lock-file
fi

nix flake check path:. \
  --no-eval-cache \
  --no-update-lock-file \
  --no-write-lock-file \
  --print-build-logs
