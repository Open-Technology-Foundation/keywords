#!/usr/bin/env bash
# Test suite for error handling in keywords script

set -euo pipefail
shopt -s inherit_errexit extglob nullglob

declare -rx PATH=/usr/local/bin:/usr/bin:/bin
#shellcheck disable=SC2155  # realpath of our own path does not fail; declare -r needs one statement
declare -r SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*}

declare -r HELPERS=$SCRIPT_DIR/test-helpers.sh
[[ -f $HELPERS ]] || { >&2 echo "Missing ${HELPERS@Q}"; exit 1; }
#shellcheck source=SCRIPTDIR/test-helpers.sh
source -- "$HELPERS" || { >&2 echo "Cannot source ${HELPERS@Q}"; exit 1; }

declare -r KEYWORDS=${KEYWORDS_SCRIPT:-$SCRIPT_DIR/../keywords}

trap cleanup_test_env EXIT

# ═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCY CHECKS
# ═══════════════════════════════════════════════════════════════════════════════

test_dependency_checks() {
  test_section "Dependency Checks"

  local -- output exit_code

  # The script checks for curl and jq at startup
  # These tests verify the error messages are correct when showing help
  # (We can't easily mock missing dependencies without modifying PATH)

  # Check that curl is mentioned in requirements
  output=$("$KEYWORDS" --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--help works (dependencies present)"

  # Verify the script runs with current dependencies
  setup_test_env
  export ANTHROPIC_API_KEY="test-key"
  output=$(echo "This is a test input text for dependency validation" | "$KEYWORDS" --dry-run 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "Script runs with all dependencies"
  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXIT CODE TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_exit_codes() {
  test_section "Exit Codes"

  local -- output exit_code

  # Exit 0: Success
  setup_test_env
  export ANTHROPIC_API_KEY="test-key"
  output=$(echo "This is a test input text for exit code validation" | "$KEYWORDS" --dry-run 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "Success returns exit code 0"
  cleanup_test_env

  # Exit 1: Runtime error (missing API key)
  unset ANTHROPIC_API_KEY
  output=$(echo "Test input" | "$KEYWORDS" 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 1 "$exit_code" "Runtime error returns exit code 1"

  # Exit 2: Usage error (invalid option)
  output=$("$KEYWORDS" --invalid-option 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "Usage error returns exit code 2"

  # Exit 2: Usage error (invalid format)
  output=$("$KEYWORDS" -f invalid 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "Invalid format returns exit code 2"

  # Exit 2: Usage error (invalid model)
  output=$("$KEYWORDS" -m invalid-model 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "Invalid model returns exit code 2"

  # Exit 1: File not found
  setup_test_env
  export ANTHROPIC_API_KEY="test-key"
  output=$("$KEYWORDS" /nonexistent/file.txt 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 1 "$exit_code" "File not found returns exit code 1"
  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# ERROR MESSAGE FORMATTING
# ═══════════════════════════════════════════════════════════════════════════════

test_error_message_format() {
  test_section "Error Message Formatting"

  local -- output exit_code

  # Error messages should go to stderr
  output=$("$KEYWORDS" --invalid-option 2>&1 1>/dev/null) && exit_code=0 || exit_code=$?
  assert_not_empty "$output" "Error messages go to stderr"

  # Error messages should include script name
  output=$("$KEYWORDS" --invalid-option 2>&1) && exit_code=0 || exit_code=$?
  assert_contains "$output" "keywords" "Error includes script name"

  # Error messages should include error indicator
  assert_contains "$output" "✗" "Error includes ✗ symbol"

  # Warning messages format
  setup_test_env
  export ANTHROPIC_API_KEY="test-key"
  # Past the 200,000-char "may be slow" warning; builtins only, so nothing here can fail
  local -- large_input
  printf -v large_input '%201000s' ''
  large_input=${large_input// /a}
  output=$(echo "$large_input" | "$KEYWORDS" --dry-run -q 2>&1) && exit_code=0 || exit_code=$?
  # Large input should trigger warning but still succeed
  assert_exit_code 0 "$exit_code" "Large input warning doesn't fail"
  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# VERBOSE/QUIET MODE TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_verbose_quiet_modes() {
  test_section "Verbose/Quiet Mode"

  local -- output exit_code

  setup_test_env
  export ANTHROPIC_API_KEY="test-key"

  # Verbose mode (default)
  output=$(echo "Test input text for verbose mode validation" | "$KEYWORDS" --dry-run 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "Verbose mode works"
  assert_contains "$output" "◉" "Verbose mode shows info messages"

  # Quiet mode
  output=$(echo "Test input text for quiet mode validation" | "$KEYWORDS" --dry-run -q 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "Quiet mode works"
  assert_not_contains "$output" "◉" "Quiet mode suppresses info messages"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL TESTS
# ═══════════════════════════════════════════════════════════════════════════════

main() {
  test_dependency_checks
  test_exit_codes
  test_error_message_format
  test_verbose_quiet_modes

  print_summary
}

main "$@"

#fin
