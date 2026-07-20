# Repository Guidelines

You maintain Snowfall Lib: a pure Nix framework generating flake outputs from
filesystem conventions. Favor boring, minimal, compatible changes.

## Critical Gates

- Production behavior and public APIs MUST remain compatible unless requested.
- Every exported API MUST have at least two behavioral unit tests.
- Tests MUST assert observable results or failures.
- Type, existence, and successful-evaluation checks alone NEVER count.
- Ordinary validation MUST NEVER update `flake.lock`.
- Validation MUST introduce no additional tracked diff.
- Coverage claims MUST use reproducible measurements.
- Prefer deletion. Add only the smallest distinct proof.

## Architecture

1. `snowfall-lib/default.nix` validates inputs, normalizes options, imports
   sublibraries, and merges core/user libraries.
2. `snowfall-lib/flake/default.nix` discovers conventional roots, enriches
   channels/arguments, then calls `flake-utils-plus.lib.mkFlake`.
3. Domain libraries discover files, build metadata, apply aliases/overrides,
   filter platforms, and produce outputs.
4. Dependencies flow through function arguments, `specialArgs`, and
   `callPackageWith`; evaluation uses immutable, lazy attrsets.

Keep discovery, metadata construction, and output building separate. Preserve
explicit alias/override stages and platform filtering.

## Repository Map

- `snowfall-lib/`: implementation and public APIs.
- `modules/`: exported NixOS, Darwin, and Home Manager modules.
- `tests/unit/`: `nix-unit` suites and fixtures.
- `tests/integration/`: evaluated output/discovery fixtures.
- `tests/vm/`: booted NixOS tests.
- `tests/ci/`: CI-script behavior harnesses.
- `nix/flake/`: formatter, dev shell, and checks.
- `scripts/ci/`: canonical validation and input automation.

Core entry points: `flake.nix`, `snowfall-lib/default.nix`,
`snowfall-lib/flake/default.nix`, `nix/flake/checks.nix`, and
`scripts/ci/check-flake.sh`.

## Code Conventions

- Nix attributes/functions and discovered outputs SHOULD use kebab-case.
- Dependencies MUST use explicit arguments, `specialArgs`, or `callPackageWith`.
- Globals and hidden environment dependencies MUST NEVER be introduced.
- Required-input assertions MUST preserve actionable messages.
- Public APIs SHOULD retain typed `#@` comments.
- Generated modules SHOULD retain `_file` provenance.
- Private system directories MUST use `_`; exported names remove it.
- Aliases and overrides MUST follow discovery/metadata construction.
- Pinned flake inputs MUST be reused unless updating them is the task.

## Testing Gates

- Unit suites MUST use nested suite/group/test attrsets.
- Expected failures SHOULD assert error type and relevant message.
- New output/discovery behavior MUST include an integration fixture.
- Runtime-sensitive NixOS behavior MUST use a booted VM when evaluation is
  insufficient.
- Darwin runtime claims MUST have macOS evidence.
- Linux evaluation and NixOS VMs NEVER prove Darwin runtime behavior.
- Fixtures MUST remain deterministic and minimal.
- `nix flake check` MUST own all pure gates, including formatting/pre-commit
  enforcement and the flake-updater behavior harness.
- Nix line-coverage percentages MUST NEVER be reported without reproducible
  instrumentation. Enforced measures: exported-API coverage and behavioral
  depth.

## Workflow

1. Inspect affected implementation, tests, fixtures, and public contracts.
2. Run the nearest focused check.
3. Implement the minimum compatible change.
4. Add unit, integration, or VM proof matching the changed behavior.
5. Run `./scripts/ci/check-flake.sh` before completion.
6. Confirm validation created no unintended diff.

## Commands

Run from repository root:

```sh
nix develop
nix fmt
nix fmt -- --ci
nix flake check path:. --print-build-logs
./tests/ci/update-flake-inputs.sh
./scripts/ci/check-flake.sh
```

`nix flake check` owns the pure test, formatting, and updater-harness gates.

## Completion

- Work MUST remain scoped to the request.
- Public compatibility MUST hold unless explicitly changed.
- Required behavioral evidence MUST pass.
- Canonical validation MUST pass without additional tracked changes.
