#!/usr/bin/env bash
# Test runner for keywords test suite
# Adapted from BCS run-all-tests.sh

set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Script metadata
SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Keywords script location
KEYWORDS_SCRIPT="$SCRIPT_DIR/../keywords"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
readonly -- KEYWORDS_SCRIPT FIXTURES_DIR

# Export for test files
export KEYWORDS_SCRIPT FIXTURES_DIR

# Colors
if [[ -t 1 ]]; then
  declare -r GREEN=$'\033[0;32m' RED=$'\033[0;31m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  declare -r GREEN='' RED='' YELLOW='' CYAN='' NC=''
fi

# Test suite counters
declare -gi SUITES_RUN=0 SUITES_PASSED=0 SUITES_FAILED=0
declare -a FAILED_SUITES=()

# Verify keywords script exists
verify_keywords_script() {
  if [[ ! -x "$KEYWORDS_SCRIPT" ]]; then
    echo "${RED}ERROR: keywords script not found or not executable${NC}"
    echo "  Expected: $KEYWORDS_SCRIPT"
    exit 1
  fi
}

# Run a single test suite
run_test_suite() {
  local -- test_file="$1"
  local -- test_name
  test_name=$(basename "$test_file" .sh)

  echo
  echo "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo "${CYAN}Running: $test_name${NC}"
  echo "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

  SUITES_RUN+=1

  if bash "$test_file"; then
    SUITES_PASSED+=1
    echo "${GREEN}✓ $test_name PASSED${NC}"
    return 0
  else
    SUITES_FAILED+=1
    FAILED_SUITES+=("$test_name")
    echo "${RED}✗ $test_name FAILED${NC}"
    return 1
  fi
}

# Main test runner
main() {
  echo
  echo "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
  echo "${CYAN}║         keywords Test Suite                                   ║${NC}"
  echo "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"

  verify_keywords_script

  # Find all test files (excluding test-helpers.sh and this script)
  local -a test_files=()
  while IFS= read -r -d '' file; do
    # Skip test-helpers.sh and run-all-tests.sh
    local -- basename
    basename=$(basename "$file")
    [[ "$basename" == "test-helpers.sh" ]] && continue
    [[ "$basename" == "run-all-tests.sh" ]] && continue
    test_files+=("$file")
  done < <(find "$SCRIPT_DIR" -maxdepth 1 -name 'test-*.sh' -type f -print0 | sort -z)

  if ((${#test_files[@]} == 0)); then
    echo "${YELLOW}No test files found!${NC}"
    echo "  Looking in: $SCRIPT_DIR"
    echo "  Pattern: test-*.sh"
    exit 0
  fi

  echo
  echo "Found ${#test_files[@]} test suite(s)"
  echo "Keywords script: $KEYWORDS_SCRIPT"
  echo "Fixtures: $FIXTURES_DIR"

  # Check for live test mode
  if [[ "${KEYWORDS_TEST_LIVE:-0}" == "1" ]]; then
    echo "${YELLOW}Live API tests ENABLED${NC}"
  else
    echo "Live API tests disabled (set KEYWORDS_TEST_LIVE=1 to enable)"
  fi

  # Run each test suite
  local -- test_file
  local -i continue_on_failure=1

  for test_file in "${test_files[@]}"; do
    if ! run_test_suite "$test_file"; then
      # Continue running other tests even if one fails
      ((continue_on_failure)) || break
    fi
  done

  # Print overall summary
  echo
  echo "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo "${CYAN}Overall Test Summary${NC}"
  echo "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo "  Total Suites:  $SUITES_RUN"
  echo "  ${GREEN}Passed:        $SUITES_PASSED${NC}"
  echo "  ${RED}Failed:        $SUITES_FAILED${NC}"

  if ((SUITES_FAILED > 0)); then
    echo
    echo "${RED}Failed Test Suites:${NC}"
    local -- suite
    for suite in "${FAILED_SUITES[@]}"; do
      echo "  ${RED}✗${NC} $suite"
    done
    echo
    echo "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo "${RED}║  TEST SUITE FAILED                                            ║${NC}"
    echo "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    return 1
  else
    echo
    echo "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo "${GREEN}║  ALL TESTS PASSED                                             ║${NC}"
    echo "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    return 0
  fi
}

main "$@"

#fin
