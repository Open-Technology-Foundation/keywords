#!/usr/bin/env bash
# Test suite for JSON parsing in keywords script

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
  export ANTHROPIC_API_KEY="test-key-for-json"
  mkdir -p "$HOME" "$XDG_CACHE_HOME"
}

cleanup_test_env() {
  [[ -d "${TEST_DIR:-}" ]] && rm -rf "$TEST_DIR" || true
}

trap cleanup_test_env EXIT

# ═══════════════════════════════════════════════════════════════════════════════
# JSON STRUCTURE TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_json_structure() {
  test_section "JSON Structure Validation"

  setup_test_env
  local -- output exit_code

  # Test that output is valid JSON
  output=$(echo "Test input for JSON structure validation" | "$KEYWORDS" --dry-run -f json 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "JSON output generated"

  # Validate with jq if available
  if command -v jq >/dev/null 2>&1; then
    # Parse JSON
    local -- parsed
    parsed=$(echo "$output" | jq -r '.keywords | length' 2>/dev/null) && exit_code=0 || exit_code=$?
    assert_exit_code 0 "$exit_code" "JSON parsed by jq"
    assert_greater_than "$parsed" 0 "JSON has keywords"

    # Check keyword structure
    parsed=$(echo "$output" | jq -r '.keywords[0].term' 2>/dev/null) && exit_code=0 || exit_code=$?
    assert_exit_code 0 "$exit_code" "Keyword has term field"

    parsed=$(echo "$output" | jq -r '.keywords[0].score' 2>/dev/null) && exit_code=0 || exit_code=$?
    assert_exit_code 0 "$exit_code" "Keyword has score field"

    parsed=$(echo "$output" | jq -r '.keywords[0].type' 2>/dev/null) && exit_code=0 || exit_code=$?
    assert_exit_code 0 "$exit_code" "Keyword has type field"

    # Check metadata
    parsed=$(echo "$output" | jq -r '.metadata.model' 2>/dev/null) && exit_code=0 || exit_code=$?
    assert_exit_code 0 "$exit_code" "Metadata has model"
    assert_contains "$parsed" "claude" "Model is Claude variant"
  else
    skip_test "jq not available for JSON validation"
  fi

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# FIXTURE-BASED TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_json_fixtures() {
  test_section "JSON Fixture Validation"

  local -- exit_code

  # Verify fixtures exist
  if [[ -f "$FIXTURES/valid-api-response.json" ]]; then
    # Verify fixture is valid JSON
    if command -v jq >/dev/null 2>&1; then
      jq . "$FIXTURES/valid-api-response.json" >/dev/null 2>&1 && exit_code=0 || exit_code=$?
      assert_exit_code 0 "$exit_code" "valid-api-response.json is valid"
    else
      pass "valid-api-response.json exists"
    fi
  else
    skip_test "valid-api-response.json fixture not found"
  fi

  if [[ -f "$FIXTURES/error-api-response.json" ]]; then
    if command -v jq >/dev/null 2>&1; then
      jq . "$FIXTURES/error-api-response.json" >/dev/null 2>&1 && exit_code=0 || exit_code=$?
      assert_exit_code 0 "$exit_code" "error-api-response.json is valid"
    else
      pass "error-api-response.json exists"
    fi
  else
    skip_test "error-api-response.json fixture not found"
  fi

  if [[ -f "$FIXTURES/markdown-wrapped-response.json" ]]; then
    if command -v jq >/dev/null 2>&1; then
      jq . "$FIXTURES/markdown-wrapped-response.json" >/dev/null 2>&1 && exit_code=0 || exit_code=$?
      assert_exit_code 0 "$exit_code" "markdown-wrapped-response.json is valid"
    else
      pass "markdown-wrapped-response.json exists"
    fi
  else
    skip_test "markdown-wrapped-response.json fixture not found"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPECTED OUTPUT TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_expected_keywords() {
  test_section "Expected Keywords Structure"

  local -- exit_code

  # Verify expected-keywords.json fixture
  if [[ -f "$FIXTURES/expected-keywords.json" ]]; then
    if command -v jq >/dev/null 2>&1; then
      local -- keywords_count
      keywords_count=$(jq '.keywords | length' "$FIXTURES/expected-keywords.json" 2>/dev/null) && exit_code=0 || exit_code=$?
      assert_exit_code 0 "$exit_code" "expected-keywords.json parses"
      assert_greater_than "$keywords_count" 0 "Expected keywords has entries"

      # Verify structure
      local -- first_term
      first_term=$(jq -r '.keywords[0].term' "$FIXTURES/expected-keywords.json" 2>/dev/null) && exit_code=0 || exit_code=$?
      assert_not_empty "$first_term" "First keyword has term"
    else
      pass "expected-keywords.json exists"
    fi
  else
    skip_test "expected-keywords.json fixture not found"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL TESTS
# ═══════════════════════════════════════════════════════════════════════════════

main() {
  test_json_structure
  test_json_fixtures
  test_expected_keywords

  print_summary
}

main "$@"

#fin
