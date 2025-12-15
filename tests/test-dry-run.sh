#!/usr/bin/env bash
# Test suite for dry-run mode in keywords script

set -euo pipefail
shopt -s inherit_errexit extglob nullglob

# Script metadata
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Source test helpers
#shellcheck source=test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

# Keywords script
KEYWORDS="${KEYWORDS_SCRIPT:-$SCRIPT_DIR/../keywords}"
FIXTURES="${FIXTURES_DIR:-$SCRIPT_DIR/fixtures}"

# Test environment
setup_test_env() {
  TEST_DIR=$(mktemp -d)
  export HOME="$TEST_DIR/home"
  export XDG_CACHE_HOME="$TEST_DIR/cache"
  export ANTHROPIC_API_KEY="test-key-for-dry-run"
  mkdir -p "$HOME" "$XDG_CACHE_HOME"
}

cleanup_test_env() {
  [[ -d "${TEST_DIR:-}" ]] && rm -rf "$TEST_DIR" || true
}

trap cleanup_test_env EXIT

# ═══════════════════════════════════════════════════════════════════════════════
# DRY-RUN BEHAVIOR TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_dry_run_behavior() {
  test_section "Dry-Run Behavior"

  setup_test_env
  local -- output exit_code

  # --dry-run flag works
  output=$(echo "Test input text for dry-run mode validation" | "$KEYWORDS" --dry-run 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--dry-run succeeds without API call"

  # Dry-run shows info message
  assert_contains "$output" "DRY-RUN" "--dry-run shows DRY-RUN message"

  # Dry-run returns fake result (should contain 'dry-run' keyword)
  local -- stdout_output
  stdout_output=$(echo "Test input text for dry-run mode validation" | "$KEYWORDS" --dry-run 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_contains "$stdout_output" "dry-run" "--dry-run returns fake keyword"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# DRY-RUN OUTPUT FORMAT TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_dry_run_formats() {
  test_section "Dry-Run Output Formats"

  setup_test_env
  local -- output exit_code

  # Text format (default)
  output=$(echo "Test input text for format validation" | "$KEYWORDS" --dry-run -f text 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--dry-run with text format"
  assert_contains "$output" "dry-run" "Text format shows keyword"

  # JSON format
  output=$(echo "Test input text for format validation" | "$KEYWORDS" --dry-run -f json 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--dry-run with JSON format"
  assert_contains "$output" '"keywords"' "JSON format has keywords array"
  assert_contains "$output" '"metadata"' "JSON format has metadata"

  # CSV format
  output=$(echo "Test input text for format validation" | "$KEYWORDS" --dry-run -f csv 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--dry-run with CSV format"
  assert_contains "$output" "term" "CSV format has header"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# DRY-RUN WITH OPTIONS TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_dry_run_with_options() {
  test_section "Dry-Run with Options"

  setup_test_env
  local -- output exit_code

  # Dry-run with scores
  output=$(echo "Test input text for options validation" | "$KEYWORDS" --dry-run -s 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--dry-run with -s works"

  # Dry-run with types
  output=$(echo "Test input text for options validation" | "$KEYWORDS" --dry-run -t 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--dry-run with -t works"

  # Dry-run with entities
  output=$(echo "Test input text for options validation" | "$KEYWORDS" --dry-run -e 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--dry-run with -e works"

  # Dry-run with max-keywords
  output=$(echo "Test input text for options validation" | "$KEYWORDS" --dry-run -n 5 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--dry-run with -n 5 works"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL TESTS
# ═══════════════════════════════════════════════════════════════════════════════

main() {
  test_dry_run_behavior
  test_dry_run_formats
  test_dry_run_with_options

  print_summary
}

main "$@"

#fin
