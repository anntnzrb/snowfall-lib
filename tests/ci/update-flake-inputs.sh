#!/usr/bin/env bash

set -euo pipefail

repo_root=${SNOWFALL_REPO_ROOT:-$(git rev-parse --show-toplevel)}
readonly repo_root
readonly updater="${repo_root}/scripts/ci/update-flake-inputs.sh"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/snowfall-updater-test.XXXXXXXX")
readonly test_root
trap 'rm -rf -- "$test_root"' EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_output() {
    local output_file=$1
    local expected=$2

    grep -Fx -- "${expected}" "${output_file}" >/dev/null \
        || fail "missing output '${expected}' in ${output_file}"
}

make_repo() {
    local name=$1
    shift
    local directory="${test_root}/${name}"
    local inputs_json

    mkdir -p "${directory}"
    inputs_json=$(printf '%s\n' "$@" | jq -Rn '[inputs] | map({key: ., value: .}) | from_entries')
    jq -n --argjson inputs "${inputs_json}" '{root: "root", nodes: {root: {inputs: $inputs}}}' \
        >"${directory}/flake.lock"

    git -C "${directory}" init --quiet
    git -C "${directory}" config user.name test
    git -C "${directory}" config user.email test@example.invalid
    git -C "${directory}" add flake.lock
    git -C "${directory}" commit --quiet -m fixture
    printf '%s\n' "${directory}"
}

fake_nix="${test_root}/fake-nix"
fake_check="${test_root}/fake-check"

# These single-quoted strings intentionally generate scripts whose variables
# expand when the fixtures execute, not while this test creates them.
# shellcheck disable=SC2016
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'shift 2' \
    'if [[ ${FAKE_UPDATE_FAIL:-0} == 1 ]]; then exit 1; fi' \
    'if [[ ${FAKE_NO_CHANGE:-0} == 1 ]]; then exit 0; fi' \
    'jq -n --args '\''{selected: $ARGS.positional}'\'' "$@" > flake.lock' \
    >"${fake_nix}"

# shellcheck disable=SC2016
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'mapfile -t selected < <(jq -r '\''.selected[]? '\'' flake.lock)' \
    'for rejected in ${FAKE_REJECT_INPUTS:-}; do' \
    '  for input in "${selected[@]}"; do' \
    '    if [[ $input == "$rejected" ]]; then exit 1; fi' \
    '  done' \
    'done' \
    >"${fake_check}"

chmod +x "${fake_nix}" "${fake_check}"

run_updater() {
    local directory=$1
    local output_file=$2
    local summary_file=$3

    (
        cd "${directory}"
        GITHUB_OUTPUT="${output_file}" \
            GITHUB_STEP_SUMMARY="${summary_file}" \
            SNOWFALL_ATTEMPT_TIMEOUT_SECONDS=30 \
            SNOWFALL_CHECK_SCRIPT="${fake_check}" \
            SNOWFALL_NIX_BIN="${fake_nix}" \
            "${updater}"
    )
}

directory=$(make_repo full-success a b c)
run_updater "${directory}" "${directory}/output" "${directory}/summary"
assert_output "${directory}/output" 'changed=true'
assert_output "${directory}/output" 'selected_inputs=a b c'
assert_output "${directory}/output" 'rejected_inputs='

directory=$(make_repo no-change a b c)
FAKE_NO_CHANGE=1 run_updater "${directory}" "${directory}/output" "${directory}/summary"
assert_output "${directory}/output" 'changed=false'
assert_output "${directory}/output" 'selected_inputs=a b c'

directory=$(make_repo scalable-salvage a b c d e f g h)
FAKE_REJECT_INPUTS='c g' run_updater "${directory}" "${directory}/output" "${directory}/summary"
assert_output "${directory}/output" 'changed=true'
assert_output "${directory}/output" 'selected_inputs=a b d e f h'
assert_output "${directory}/output" 'rejected_inputs=c g'

directory=$(make_repo total-failure a b c)
set +e
FAKE_REJECT_INPUTS='a b c' run_updater \
    "${directory}" "${directory}/output" "${directory}/summary"
failure_status=$?
set -e
if ((failure_status == 0)); then
    fail 'total failure unexpectedly succeeded'
fi
assert_output "${directory}/output" 'changed=false'
assert_output "${directory}/output" 'selected_inputs='
assert_output "${directory}/output" 'rejected_inputs=a b c'

directory=$(make_repo update-command-failure a b)
set +e
FAKE_UPDATE_FAIL=1 run_updater \
    "${directory}" "${directory}/output" "${directory}/summary"
failure_status=$?
set -e
if ((failure_status == 0)); then
    fail 'failed update command was incorrectly accepted by the passing checker'
fi
assert_output "${directory}/output" 'changed=false'
assert_output "${directory}/output" 'selected_inputs='
assert_output "${directory}/output" 'rejected_inputs=a b'

printf 'Updater tests passed.\n'
