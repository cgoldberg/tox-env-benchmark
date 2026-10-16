#!/usr/bin/env bash
#
# Copyright (c) 2026 Corey Goldberg (https://github.com/cgoldberg)
# License: MIT
#
# Benchmark tox environment provisioning across Git commits.


set -e

# Number of runs per benchmark.
NUM_RUNS=3

if [[ $# -lt 2 || $# -gt 4 ]]; then
    echo "Usage: $0 <repo_url> <old_commit> [new_commit] [branch]" >&2
    exit 1
fi

REPO_URL="$1"
OLD_COMMIT="$2"
NEW_COMMIT="${3:-HEAD}"
BRANCH="${4:-}"

# Use separate working copies for the two commits.
REPO_NAME="$(basename "${REPO_URL}" .git)"
OLD_DIR="${REPO_NAME}-old"
NEW_DIR="${REPO_NAME}-new"

# Commands executed by Hyperfine.
CMD="tox --notest"
OLD_CMD="cd '${OLD_DIR}' && ${CMD}"
NEW_CMD="cd '${NEW_DIR}' && ${CMD}"

# Remove tox environments between fresh-provisioning runs.
REMOVE_TOX_ENVS="rm -rf -- '${OLD_DIR}/.tox' '${NEW_DIR}/.tox'"

# Populate the package cache before warm-cache benchmarks.
warmup_cache() {
    (cd "${OLD_DIR}" && ${CMD}) >/dev/null &&
    (cd "${NEW_DIR}" && ${CMD}) >/dev/null
}

# Ensure required executables are available.
check_deps() {
    for dep in git hyperfine python tox; do
        if ! command -v "${dep}" &>/dev/null; then
            echo "Error: ${dep} is not installed or not in PATH." >&2
            exit 1
        fi
    done
}

# Create or reuse working copies and synchronize the requested branch.
setup_repos() {
    if ! git -C "${NEW_DIR}" rev-parse --git-dir &>/dev/null; then
        rm -rf -- "${NEW_DIR}"
        git clone -q "${REPO_URL}" "${NEW_DIR}"
    fi
    if ! git -C "${OLD_DIR}" rev-parse --git-dir &>/dev/null; then
        rm -rf -- "${OLD_DIR}"
        cp -a "${NEW_DIR}" "${OLD_DIR}"
    fi

    # Detect the remote's default branch if none was specified.
    if [[ -z "${BRANCH}" ]]; then
        git -C "${NEW_DIR}" remote set-head origin --auto >/dev/null
        BRANCH="$(git -C "${NEW_DIR}" symbolic-ref --short refs/remotes/origin/HEAD)"
        BRANCH="${BRANCH#origin/}"
    fi

    # Fetch the requested branch in both copies.
    git -C "${NEW_DIR}" fetch -q origin "${BRANCH}"
    git -C "${NEW_DIR}" checkout -q -B "${BRANCH}" "origin/${BRANCH}"
    git -C "${OLD_DIR}" fetch -q origin "${BRANCH}"
    git -C "${OLD_DIR}" checkout -q -B "${BRANCH}" "origin/${BRANCH}"

    # Reset each copy to its target commit and remove untracked/ignored files.
    git -C "${NEW_DIR}" reset -q --hard "${NEW_COMMIT}"
    git -C "${NEW_DIR}" clean -q -fdx
    git -C "${OLD_DIR}" reset -q --hard "${OLD_COMMIT}"
    git -C "${OLD_DIR}" clean -q -fdx
}

check_deps

echo
echo "Preparing repositories..."
setup_repos
echo
echo "Repo: [REDACTED]" #${REPO_URL}"
echo "Branch: ${BRANCH}"
echo "Old commit: ${OLD_COMMIT}"
echo "New commit: ${NEW_COMMIT}"
echo
echo "Warming up package cache..."
warmup_cache
echo
echo "Running tox environment provisioning benchmarks..."

# Reuse existing tox environments with a warm package cache.
echo -e "\n========== EXISTING TOX ENVS + WARM PACKAGE CACHE ==========\n"
hyperfine -S \
    --runs "${NUM_RUNS}" \
    --metrics time_wall_clock \
    --command-name "Old (${OLD_COMMIT})" "cd '${OLD_DIR}' && ${CMD}" \
    --command-name "New (${NEW_COMMIT})" "cd '${NEW_DIR}' && ${CMD}"

# Recreate tox environments with a warm package cache.
echo -e "\n========== FRESH TOX ENVS + WARM PACKAGE CACHE ==========\n"
hyperfine -S \
    --runs "${NUM_RUNS}" \
    --metrics time_wall_clock \
    --prepare "${REMOVE_TOX_ENVS}" \
    --command-name "Old (${OLD_COMMIT})" "cd '${OLD_DIR}' && ${CMD}" \
    --command-name "New (${NEW_COMMIT})" "cd '${NEW_DIR}' && ${CMD}"

# Recreate tox environments with a cold package cache.
echo -e "\n========== FRESH TOX ENVS + COLD PACKAGE CACHE ==========\n"
hyperfine -S \
    --runs "${NUM_RUNS}" \
    --metrics time_wall_clock \
    --prepare "pip cache purge &&
        { command -v uv >/dev/null 2>&1 && uv cache clean || true; } && \
        ${REMOVE_TOX_ENVS}" \
    --command-name "Old (${OLD_COMMIT})" "cd '${OLD_DIR}' && ${CMD}" \
    --command-name "New (${NEW_COMMIT})" "cd '${NEW_DIR}' && ${CMD}"
