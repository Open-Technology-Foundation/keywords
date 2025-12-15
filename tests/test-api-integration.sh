#!/usr/bin/env bash
# Test suite for API integration in keywords script
# Includes mocked tests and optional live tests

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
declare -- ORIGINAL_PATH="$PATH"
declare -- ORIGINAL_HOME="$HOME"
declare -- ORIGINAL_XDG_CACHE_HOME="${XDG_CACHE_HOME:-}"
declare -- ORIGINAL_API_KEY="${ANTHROPIC_API_KEY:-}"
declare -- MOCK_DIR=""

setup_test_env() {
  TEST_DIR=$(mktemp -d)
  MOCK_DIR="$TEST_DIR/mocks"
  export HOME="$TEST_DIR/home"
  export XDG_CACHE_HOME="$TEST_DIR/cache"
  mkdir -p "$HOME" "$XDG_CACHE_HOME" "$MOCK_DIR"
}

cleanup_test_env() {
  export PATH="$ORIGINAL_PATH"
  export HOME="$ORIGINAL_HOME"
  [[ -n "$ORIGINAL_XDG_CACHE_HOME" ]] && export XDG_CACHE_HOME="$ORIGINAL_XDG_CACHE_HOME" || unset XDG_CACHE_HOME
  [[ -n "$ORIGINAL_API_KEY" ]] && export ANTHROPIC_API_KEY="$ORIGINAL_API_KEY" || unset ANTHROPIC_API_KEY
  [[ -d "${TEST_DIR:-}" ]] && rm -rf "$TEST_DIR" || true
}

trap cleanup_test_env EXIT

# ═══════════════════════════════════════════════════════════════════════════════
# MOCK CURL SETUP
# ═══════════════════════════════════════════════════════════════════════════════

# Create a mock curl that returns a fixture
mock_curl() {
  local -- fixture_file="$1"
  local -i mock_exit_code="${2:-0}"

  cat > "$MOCK_DIR/curl" << 'MOCK_SCRIPT'
#!/usr/bin/env bash
# Mock curl - returns fixture content
cat "$KEYWORDS_MOCK_FIXTURE"
exit "$KEYWORDS_MOCK_EXIT"
MOCK_SCRIPT

  chmod +x "$MOCK_DIR/curl"
  export KEYWORDS_MOCK_FIXTURE="$fixture_file"
  export KEYWORDS_MOCK_EXIT="$mock_exit_code"
  export PATH="$MOCK_DIR:$ORIGINAL_PATH"
}

unmock_curl() {
  export PATH="$ORIGINAL_PATH"
  unset KEYWORDS_MOCK_FIXTURE KEYWORDS_MOCK_EXIT
}

# ═══════════════════════════════════════════════════════════════════════════════
# MOCKED API TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_mocked_api_success() {
  test_section "Mocked API Success"

  setup_test_env
  local -- output exit_code

  # Test with valid API response fixture
  if [[ -f "$FIXTURES/valid-api-response.json" ]]; then
    mock_curl "$FIXTURES/valid-api-response.json" 0
    export ANTHROPIC_API_KEY="test-mock-key"

    output=$(echo "Test input for mocked API success" | "$KEYWORDS" --no-cache 2>&1) && exit_code=0 || exit_code=$?
    assert_exit_code 0 "$exit_code" "Mocked API call succeeds"
    assert_contains "$output" "RAG" "Returns expected keywords"

    unmock_curl
  else
    skip_test "valid-api-response.json fixture not found"
  fi

  cleanup_test_env
}

test_mocked_api_error() {
  test_section "Mocked API Error"

  setup_test_env
  local -- output exit_code

  # Test with error API response fixture
  if [[ -f "$FIXTURES/error-api-response.json" ]]; then
    mock_curl "$FIXTURES/error-api-response.json" 0
    export ANTHROPIC_API_KEY="test-mock-key"

    output=$(echo "Test input for mocked API error" | "$KEYWORDS" --no-cache 2>&1) && exit_code=0 || exit_code=$?
    assert_exit_code 1 "$exit_code" "API error exits 1"
    assert_contains "$output" "[Ee]rror" "API error message shown"

    unmock_curl
  else
    skip_test "error-api-response.json fixture not found"
  fi

  cleanup_test_env
}

test_mocked_api_connection_failure() {
  test_section "Mocked Connection Failure"

  setup_test_env
  local -- output exit_code

  # Create a mock that fails
  cat > "$MOCK_DIR/curl" << 'MOCK_SCRIPT'
#!/usr/bin/env bash
exit 7  # curl exit code for connection failure
MOCK_SCRIPT
  chmod +x "$MOCK_DIR/curl"
  export PATH="$MOCK_DIR:$ORIGINAL_PATH"
  export ANTHROPIC_API_KEY="test-mock-key"

  output=$(echo "Test input for connection failure" | "$KEYWORDS" --no-cache 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 1 "$exit_code" "Connection failure exits 1"
  assert_contains "$output" "[Ff]ail" "Connection failure message shown"

  cleanup_test_env
}

test_mocked_markdown_response() {
  test_section "Mocked Markdown-Wrapped Response"

  setup_test_env
  local -- output exit_code

  # Test with markdown-wrapped response
  if [[ -f "$FIXTURES/markdown-wrapped-response.json" ]]; then
    mock_curl "$FIXTURES/markdown-wrapped-response.json" 0
    export ANTHROPIC_API_KEY="test-mock-key"

    output=$(echo "Test input for markdown response" | "$KEYWORDS" --no-cache 2>&1) && exit_code=0 || exit_code=$?
    assert_exit_code 0 "$exit_code" "Markdown-wrapped response succeeds"
    assert_contains "$output" "test" "Parses keyword from markdown"

    unmock_curl
  else
    skip_test "markdown-wrapped-response.json fixture not found"
  fi

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# DRY-RUN API TESTS (no mocking needed)
# ═══════════════════════════════════════════════════════════════════════════════

test_dry_run_no_api() {
  test_section "Dry-Run Mode (No API)"

  setup_test_env
  export ANTHROPIC_API_KEY="test-key"
  local -- output exit_code

  # Dry-run should not make API calls
  output=$(echo "Test input for dry-run validation" | "$KEYWORDS" --dry-run 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "Dry-run succeeds"
  assert_contains "$output" "DRY-RUN" "Dry-run message shown"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# OPTIONAL LIVE API TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_live_api() {
  test_section "Live API Tests (Optional)"

  # Skip unless explicitly enabled
  if [[ "${KEYWORDS_TEST_LIVE:-0}" != "1" ]]; then
    echo "  Skipping live tests (set KEYWORDS_TEST_LIVE=1 to enable)"
    return 0
  fi

  # Check for real API key (use original, not test key)
  if [[ -z "$ORIGINAL_API_KEY" ]]; then
    echo "  Skipping live tests (ANTHROPIC_API_KEY not set at startup)"
    return 0
  fi

  # Ensure real API key is set for live tests
  export ANTHROPIC_API_KEY="$ORIGINAL_API_KEY"

  local -- output exit_code

  # Live API test with real input
  output=$(echo "Artificial intelligence and machine learning are transforming technology." | "$KEYWORDS" --no-cache -n 5 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "Live API call succeeds"

  # Verify we got keywords back
  local -- stdout_output
  stdout_output=$(echo "Artificial intelligence and machine learning are transforming technology." | "$KEYWORDS" --no-cache -n 5 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_not_empty "$stdout_output" "Live API returns keywords"

  # Test JSON format
  stdout_output=$(echo "Cloud computing and data analytics enable business insights." | "$KEYWORDS" --no-cache -f json -n 3 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "Live API JSON format works"
  assert_contains "$stdout_output" '"keywords"' "Live API returns JSON structure"
}

# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL TESTS
# ═══════════════════════════════════════════════════════════════════════════════

main() {
  test_mocked_api_success
  test_mocked_api_error
  test_mocked_api_connection_failure
  test_mocked_markdown_response
  test_dry_run_no_api
  test_live_api

  print_summary
}

main "$@"

#fin
