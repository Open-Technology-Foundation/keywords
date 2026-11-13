#!/usr/bin/env bash
# Test helpers for the keywords test suite; source this file, do not run it
#
# Asserts record a failure and still return 0, so a suite under set -e runs every
# assertion instead of stopping at the first failure; print_summary sets the exit status.

[[ ${BASH_SOURCE[0]} != "$0" ]] || {
  >&2 echo "Error: ${0@Q} must be sourced"
  exit 1
}

# Result counters
declare -gi TESTS_RUN=0 TESTS_PASSED=0 TESTS_FAILED=0
declare -ga FAILED_TESTS=()

if [[ -t 1 ]]; then
  declare -gr GREEN=$'\033[0;32m' RED=$'\033[0;31m' YELLOW=$'\033[0;33m' NC=$'\033[0m'
else
  declare -gr GREEN='' RED='' YELLOW='' NC=''
fi

# Caller's environment, restored by cleanup_test_env
declare -gr ORIGINAL_HOME=$HOME
declare -gr ORIGINAL_XDG_CACHE_HOME=${XDG_CACHE_HOME:-}
declare -gr ORIGINAL_API_KEY=${ANTHROPIC_API_KEY:-}
declare -g -- TEST_DIR='' MOCK_DIR=''

# _record OK NAME [DETAIL...]: count one assertion and print its result
_record() {
  local -i ok=$1
  local -- name=$2 line

  TESTS_RUN+=1
  if ((ok)); then
    TESTS_PASSED+=1
    printf '%s✓%s %s\n' "$GREEN" "$NC" "$name"
    return 0
  fi
  TESTS_FAILED+=1
  FAILED_TESTS+=("$name")
  printf '%s✗%s %s\n' "$RED" "$NC" "$name"
  for line in "${@:3}"; do
    printf '  %s\n' "$line"
  done
}

# Assertion functions

assert_equals() {
  local -i ok=0
  [[ $1 == "$2" ]] && ok=1
  _record "$ok" "${3:-Assertion}" "Expected: ${1@Q}" "Actual:   ${2@Q}"
}

# NEEDLE is a regular expression
assert_contains() {
  local -i ok=0
  [[ $1 =~ $2 ]] && ok=1
  _record "$ok" "${3:-Contains assertion}" "Expected to contain: ${2@Q}" "Actual output: ${1@Q}"
}

assert_not_contains() {
  local -i ok=1
  [[ $1 =~ $2 ]] && ok=0
  _record "$ok" "${3:-Not contains assertion}" "Expected NOT to contain: ${2@Q}" "Actual output: ${1@Q}"
}

assert_exit_code() {
  local -i ok=0
  [[ $1 == "$2" ]] && ok=1
  _record "$ok" "${3:-Exit code assertion}" "Expected exit code: $1" "Actual exit code: $2"
}

assert_file_exists() {
  local -i ok=0
  [[ -f $1 ]] && ok=1
  _record "$ok" "${2:-File exists: ${1@Q}}" "File not found: ${1@Q}"
}

assert_not_empty() {
  local -i ok=0
  [[ -n $1 ]] && ok=1
  _record "$ok" "${2:-Value should not be empty}" 'Expected non-empty value'
}

# Non-numeric input (an empty or failed command substitution) fails the assertion
assert_greater_than() {
  local -i ok=0
  [[ $1 =~ ^-?[0-9]+$ ]] && (($1 > $2)) && ok=1 ||:
  _record "$ok" "${3:-Value should be > $2} (actual: $1)" "Expected: > $2" "Actual: ${1@Q}"
}

# Record a pass for a check done by the caller
pass() {
  _record 1 "$*"
}

skip_test() {
  TESTS_RUN+=1
  TESTS_PASSED+=1
  printf '%s⊘%s SKIPPED: %s\n' "$YELLOW" "$NC" "$*"
}

# Test environment

# must CMD...: run a fixture-setup command and name it if it fails
must() {
  "$@" || { >&2 echo "Test setup failed: ${*@Q}"; return 1; }
}

# must_write FILE: write stdin to FILE and name it if that fails. must cannot cover
# 'must cmd > FILE': bash opens FILE before must runs, so a failed open bypasses it
must_write() {
  cat > "$1" || { >&2 echo "Test setup failed: cannot write ${1@Q}"; return 1; }
}

# A fresh HOME, cache and API key for one test. The keywords script locks PATH to
# ~/.local/bin:/usr/local/bin:/usr/bin:/bin, so mocks go in this HOME's ~/.local/bin
setup_test_env() {
  TEST_DIR=$(mktemp -d) || { >&2 echo 'setup_test_env: cannot create a temp dir'; return 1; }
  MOCK_DIR=$TEST_DIR/home/.local/bin
  export HOME=$TEST_DIR/home XDG_CACHE_HOME=$TEST_DIR/cache ANTHROPIC_API_KEY=test-key
  mkdir -p -- "$MOCK_DIR" "$XDG_CACHE_HOME" || {
    >&2 echo "setup_test_env: cannot create directories in ${TEST_DIR@Q}"
    return 1
  }
}

cleanup_test_env() {
  export HOME=$ORIGINAL_HOME
  if [[ -n $ORIGINAL_XDG_CACHE_HOME ]]; then
    export XDG_CACHE_HOME=$ORIGINAL_XDG_CACHE_HOME
  else
    unset XDG_CACHE_HOME
  fi
  if [[ -n $ORIGINAL_API_KEY ]]; then
    export ANTHROPIC_API_KEY=$ORIGINAL_API_KEY
  else
    unset ANTHROPIC_API_KEY
  fi
  if [[ -n $TEST_DIR && -d $TEST_DIR ]]; then
    rm -rf -- "$TEST_DIR" || >&2 echo "cleanup_test_env: cannot remove ${TEST_DIR@Q}"
  fi
  TEST_DIR=''
  MOCK_DIR=''
}

# Summary reporting

test_section() {
  printf '\n%s━━━ %s ━━━%s\n\n' "$YELLOW" "$*" "$NC"
}

print_summary() {
  local -- rule='━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' name

  printf '\n%s\nTest Summary:\n' "$rule"
  printf '  Total:  %d\n' "$TESTS_RUN"
  printf '  %sPassed: %d%s\n' "$GREEN" "$TESTS_PASSED" "$NC"
  printf '  %sFailed: %d%s\n' "$RED" "$TESTS_FAILED" "$NC"
  if ((TESTS_FAILED)); then
    printf '\nFailed tests:\n'
    for name in "${FAILED_TESTS[@]}"; do
      printf '  %s✗%s %s\n' "$RED" "$NC" "$name"
    done
  fi
  printf '%s\n' "$rule"
  ((TESTS_FAILED == 0))
}

#fin
