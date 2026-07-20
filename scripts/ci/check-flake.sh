#!/bin/sh

set -eu

nix run \
    --no-update-lock-file \
    --no-write-lock-file \
    --inputs-from path:. \
    nixpkgs#flake-checker -- \
    --fail-mode \
    --check-outdated \
    --check-owner \
    flake.lock

kernel_name=$(uname -s)
if [ "${kernel_name}" = "Linux" ]; then
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
