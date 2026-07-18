#!/usr/bin/env bash

set -euo pipefail

# Exact maximum-subset search is exponential. This updater instead tries the
# atomic update first, then salvages compatible groups with a deterministic
# divide-and-conquer search bounded to at most O(number of root inputs) checks.

repo_root=$(git rev-parse --show-toplevel)
readonly repo_root
readonly original_lock="${repo_root}/flake.lock"
readonly check_script="${SNOWFALL_CHECK_SCRIPT:-${repo_root}/scripts/ci/check-flake.sh}"
readonly nix_bin="${SNOWFALL_NIX_BIN:-nix}"
readonly attempt_timeout_seconds="${SNOWFALL_ATTEMPT_TIMEOUT_SECONDS:-1800}"

for command_name in git jq "${nix_bin}"; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "${command_name}" >&2
        exit 1
    fi
done

if [[ ! -f ${original_lock} ]]; then
    printf 'Missing lock file: %s\n' "${original_lock}" >&2
    exit 1
fi

if [[ ! -x ${check_script} ]]; then
    printf 'Check script is not executable: %s\n' "${check_script}" >&2
    exit 1
fi

if [[ ! ${attempt_timeout_seconds} =~ ^[1-9][0-9]*$ ]]; then
    printf 'SNOWFALL_ATTEMPT_TIMEOUT_SECONDS must be a positive integer.\n' >&2
    exit 1
fi

worktree_status=$(git -C "${repo_root}" status --porcelain --untracked-files=normal)
if [[ -n ${worktree_status} ]]; then
    printf 'Refusing to update from a dirty worktree; candidates must match HEAD exactly.\n' >&2
    exit 1
fi

inputs=()
input_lines=$(jq -r '.nodes[.root].inputs | keys[]' "${original_lock}")
if [[ -n ${input_lines} ]]; then
    while IFS= read -r input; do
        if [[ ! ${input} =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
            printf 'Unsupported root input name: %q\n' "${input}" >&2
            exit 1
        fi
        inputs+=("${input}")
    done <<<"${input_lines}"
fi

readonly input_count=${#inputs[@]}
if ((input_count == 0)); then
    printf 'No root flake inputs found.\n' >&2
    exit 1
fi

readonly default_max_attempts=$((3 * input_count + 1))
readonly max_attempts="${SNOWFALL_MAX_ATTEMPTS:-${default_max_attempts}}"
if [[ ! ${max_attempts} =~ ^[1-9][0-9]*$ ]]; then
    printf 'SNOWFALL_MAX_ATTEMPTS must be a positive integer.\n' >&2
    exit 1
fi

temp_root=$(mktemp -d "${TMPDIR:-/tmp}/snowfall-flake-update.XXXXXXXX")
readonly temp_root
readonly selected_lock="${temp_root}/selected.lock"
readonly passing_lock="${temp_root}/passing.lock"
active_worktree=""
attempt_count=0
budget_exhausted=0
selected_inputs=()
rejected_inputs=()

cleanup() {
    if [[ -n ${active_worktree} ]]; then
        git -C "${repo_root}" worktree remove --force "${active_worktree}" >/dev/null 2>&1 || true
    fi
    rm -rf -- "${temp_root}"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

remove_candidate_worktree() {
    if ! git -C "${repo_root}" worktree remove --force "${active_worktree}" >/dev/null; then
        printf 'Failed to remove candidate worktree: %s\n' "${active_worktree}" >&2
        exit 1
    fi
    active_worktree=""
}

run_with_timeout() {
    if command -v timeout >/dev/null 2>&1; then
        timeout --signal=TERM "${attempt_timeout_seconds}" "$@"
    else
        "$@"
    fi
}

try_candidate() {
    local -a candidate_inputs=("$@")
    local candidate_status update_status

    if ((attempt_count >= max_attempts)); then
        budget_exhausted=1
        return 2
    fi

    ((attempt_count += 1))
    active_worktree="${temp_root}/candidate-${attempt_count}"

    printf 'Attempt %d/%d: %s\n' \
        "${attempt_count}" "${max_attempts}" "${candidate_inputs[*]}"
    if ! git -C "${repo_root}" worktree add --detach --quiet "${active_worktree}" HEAD; then
        active_worktree=""
        printf 'Failed to create candidate worktree.\n' >&2
        exit 1
    fi

    (
        cd "${active_worktree}" || exit 1
        run_with_timeout "${nix_bin}" flake update "${candidate_inputs[@]}"
        update_status=$?
        if ((update_status != 0)); then
            exit "${update_status}"
        fi
        run_with_timeout "${check_script}"
    )
    candidate_status=$?

    if ((candidate_status == 0)); then
        cp "${active_worktree}/flake.lock" "${passing_lock}"
        remove_candidate_worktree
        return 0
    fi

    printf 'Candidate failed: %s\n' "${candidate_inputs[*]}" >&2
    remove_candidate_worktree
    return 1
}

accept_passing_candidate() {
    cp "${passing_lock}" "${selected_lock}"
}

salvage_group() {
    local -a group=("$@")
    local -a candidate=("${selected_inputs[@]}" "${group[@]}")
    local -a left right
    local group_size=${#group[@]}
    local midpoint status

    if ((budget_exhausted != 0)); then
        rejected_inputs+=("${group[@]}")
        return
    fi

    set +e
    try_candidate "${candidate[@]}"
    status=$?
    set -e

    if ((status == 0)); then
        selected_inputs+=("${group[@]}")
        accept_passing_candidate
        return
    fi

    if ((status == 2)); then
        rejected_inputs+=("${group[@]}")
        return
    fi

    if ((group_size == 1)); then
        rejected_inputs+=("${group[0]}")
        return
    fi

    midpoint=$((group_size / 2))
    left=("${group[@]:0:midpoint}")
    right=("${group[@]:midpoint}")
    salvage_group "${left[@]}"
    salvage_group "${right[@]}"
}

write_outputs() {
    local changed=$1

    if [[ -n ${GITHUB_OUTPUT:-} ]]; then
        {
            printf 'changed=%s\n' "${changed}"
            printf 'selected_inputs=%s\n' "${selected_inputs[*]}"
            printf 'rejected_inputs=%s\n' "${rejected_inputs[*]}"
        } >>"${GITHUB_OUTPUT}"
    fi
}

write_summary() {
    local result=$1

    if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
        {
            printf '### Flake input selection\n\n'
            printf -- '- Result: %s\n' "${result}"
            printf -- '- Attempts: %d/%d\n' "${attempt_count}" "${max_attempts}"
            printf -- '- Selected: %s\n' "${selected_inputs[*]:-none}"
            printf -- '- Rejected: %s\n' "${rejected_inputs[*]:-none}"
        } >>"${GITHUB_STEP_SUMMARY}"
    fi
}

# Prefer one atomic lock update. Only enter salvage mode when that exact
# candidate fails its update or validation.
set +e
try_candidate "${inputs[@]}"
full_status=$?
set -e

if ((full_status == 0)); then
    selected_inputs=("${inputs[@]}")
    accept_passing_candidate
else
    if ((full_status == 2)); then
        rejected_inputs=("${inputs[@]}")
    elif ((input_count == 1)); then
        rejected_inputs=("${inputs[@]}")
    else
        midpoint=$((input_count / 2))
        salvage_group "${inputs[@]:0:midpoint}"
        salvage_group "${inputs[@]:midpoint}"
    fi

    # One stable retry lets inputs rejected early become compatible after later
    # groups were accepted, while preserving the linear attempt bound.
    if ((${#selected_inputs[@]} > 0 && ${#rejected_inputs[@]} > 0 && budget_exhausted == 0)); then
        first_pass_rejected=("${rejected_inputs[@]}")
        rejected_inputs=()
        for input in "${first_pass_rejected[@]}"; do
            candidate=("${selected_inputs[@]}" "${input}")
            set +e
            try_candidate "${candidate[@]}"
            retry_status=$?
            set -e
            if ((retry_status == 0)); then
                selected_inputs+=("${input}")
                accept_passing_candidate
            else
                rejected_inputs+=("${input}")
            fi
        done
    fi
fi

if ((budget_exhausted != 0)); then
    write_outputs false
    write_summary budget-exhausted
    printf 'Candidate attempt budget exhausted before selection completed.\n' >&2
    exit 1
fi

if ((${#selected_inputs[@]} == 0)); then
    write_outputs false
    write_summary failed
    printf 'No passing flake input update was found.\n' >&2
    exit 1
fi

if cmp -s "${original_lock}" "${selected_lock}"; then
    write_outputs false
    if ((${#rejected_inputs[@]} > 0)); then
        write_summary failed-no-change
        printf 'No compatible input update changed flake.lock.\n' >&2
        exit 1
    fi

    write_summary up-to-date
    printf 'All selected inputs are already up to date: %s\n' "${selected_inputs[*]}"
    exit 0
fi

cp "${selected_lock}" "${original_lock}"
write_outputs true
write_summary updated
printf 'Selected inputs: %s\n' "${selected_inputs[*]}"
if ((${#rejected_inputs[@]} > 0)); then
    printf 'Rejected inputs: %s\n' "${rejected_inputs[*]}"
fi
