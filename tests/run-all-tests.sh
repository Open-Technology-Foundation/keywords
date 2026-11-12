#!/usr/bin/env bash
# Run every tests/test-*.sh suite and summarise the results
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

declare -rx PATH=/usr/local/bin:/usr/bin:/bin
#shellcheck disable=SC2155  # realpath of our own path does not fail; declare -r needs one statement
declare -r SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*}

# Read by every suite
declare -rx KEYWORDS_SCRIPT=$SCRIPT_DIR/../keywords
declare -rx FIXTURES_DIR=$SCRIPT_DIR/fixtures

if [[ -t 1 && -t 2 ]]; then
  declare -r GREEN=$'\033[0;32m' RED=$'\033[0;31m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  declare -r GREEN='' RED='' YELLOW='' CYAN='' NC=''
fi

declare -r RULE='═══════════════════════════════════════════════════════════════'
declare -i SUITES_RUN=0 SUITES_PASSED=0 SUITES_FAILED=0
declare -a FAILED_SUITES=()

die() {
  (($# < 2)) || >&2 printf '%s✗ %s%s\n' "$RED" "${*:2}" "$NC"
  exit "${1:-0}"
}

# box COLOUR TEXT: a framed banner line
box() {
  printf '%s╔%s╗\n║  %-61s║\n╚%s╝%s\n' "$1" "$RULE" "$2" "$RULE" "$NC"
}

run_test_suite() {
  local -- name=${1##*/}
  name=${name%.sh}

  printf '\n%s%s\nRunning: %s\n%s%s\n' "$CYAN" "$RULE" "$name" "$RULE" "$NC"
  SUITES_RUN+=1
  if bash -- "$1"; then
    SUITES_PASSED+=1
    printf '%s✓ %s PASSED%s\n' "$GREEN" "$name" "$NC"
  else
    SUITES_FAILED+=1
    FAILED_SUITES+=("$name")
    printf '%s✗ %s FAILED%s\n' "$RED" "$name" "$NC"
  fi
}

main() {
  local -a test_files=()
  local -- file suite

  echo
  box "$CYAN" 'keywords Test Suite'

  [[ -x $KEYWORDS_SCRIPT ]] || die 1 "keywords script not found or not executable ${KEYWORDS_SCRIPT@Q}"

  # test-helpers.sh is the shared library, not a suite
  for file in "$SCRIPT_DIR"/test-*.sh; do
    [[ $file == */test-helpers.sh ]] || test_files+=("$file")
  done
  if ((${#test_files[@]} == 0)); then
    >&2 printf '%sNo test-*.sh suites found in %s%s\n' "$YELLOW" "${SCRIPT_DIR@Q}" "$NC"
    return 0
  fi

  printf '\nFound %d test suite(s)\nKeywords script: %s\nFixtures: %s\n' \
    "${#test_files[@]}" "$KEYWORDS_SCRIPT" "$FIXTURES_DIR"
  if [[ ${KEYWORDS_TEST_LIVE:-0} == 1 ]]; then
    printf '%sLive API tests ENABLED%s\n' "$YELLOW" "$NC"
  else
    echo 'Live API tests disabled (set KEYWORDS_TEST_LIVE=1 to enable)'
  fi

  for file in "${test_files[@]}"; do
    run_test_suite "$file"
  done

  printf '\n%s%s\nOverall Test Summary\n%s%s\n' "$CYAN" "$RULE" "$RULE" "$NC"
  printf '  Total Suites:  %d\n' "$SUITES_RUN"
  printf '  %sPassed:        %d%s\n' "$GREEN" "$SUITES_PASSED" "$NC"
  printf '  %sFailed:        %d%s\n' "$RED" "$SUITES_FAILED" "$NC"

  if ((SUITES_FAILED)); then
    printf '\n%sFailed Test Suites:%s\n' "$RED" "$NC"
    for suite in "${FAILED_SUITES[@]}"; do
      printf '  %s✗%s %s\n' "$RED" "$NC" "$suite"
    done
    echo
    box "$RED" 'TEST SUITE FAILED'
    return 1
  fi
  echo
  box "$GREEN" 'ALL TESTS PASSED'
}

main "$@"
#fin
