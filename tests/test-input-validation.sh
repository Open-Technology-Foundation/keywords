#!/usr/bin/env bash
# Test suite for input validation in keywords script

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
declare -r FIXTURES=${FIXTURES_DIR:-$SCRIPT_DIR/fixtures}

trap cleanup_test_env EXIT

# ═══════════════════════════════════════════════════════════════════════════════
# FILE INPUT TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_file_input() {
  test_section "File Input Validation"

  setup_test_env
  local -- output exit_code

  # Valid text file (using test-sample.txt from project root)
  local -- sample_file="$SCRIPT_DIR/../test-sample.txt"
  if [[ -f "$sample_file" ]]; then
    output=$("$KEYWORDS" --dry-run -- "$sample_file" 2>&1) && exit_code=0 || exit_code=$?
    assert_exit_code 0 "$exit_code" "Valid text file is accepted"
    assert_contains "$output" "dry-run" "Dry-run processes file"
  else
    skip_test "test-sample.txt not found"
  fi

  # Non-existent file
  output=$("$KEYWORDS" /nonexistent/file.txt 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 1 "$exit_code" "Non-existent file exits 1"
  assert_contains "$output" "not found" "Shows file not found error"

  # Unreadable file
  local -- unreadable="$TEST_DIR/unreadable.txt"
  echo "Some test content for the unreadable file test" > "$unreadable"
  must chmod -- 000 "$unreadable"
  output=$("$KEYWORDS" -- "$unreadable" 2>&1) && exit_code=0 || exit_code=$?
  # Restore permissions for cleanup
  must chmod -- 644 "$unreadable"
  assert_exit_code 1 "$exit_code" "Unreadable file exits 1"
  assert_contains "$output" "not readable" "Shows not readable error"

  # Binary file
  if [[ -f "$FIXTURES/binary-file.bin" ]]; then
    output=$("$KEYWORDS" -- "$FIXTURES"/binary-file.bin 2>&1) && exit_code=0 || exit_code=$?
    assert_exit_code 1 "$exit_code" "Binary file exits 1"
    assert_contains "$output" "binary" "Shows binary file error"
  else
    skip_test "binary-file.bin fixture not found"
  fi

  # A text file that file(1) types as application/json is still text
  echo '{"note": "plain text content about vector search"}' > "$TEST_DIR"/doc.json
  output=$("$KEYWORDS" --dry-run -- "$TEST_DIR"/doc.json 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" 'JSON-typed text file is accepted'

  # An empty file is empty input, not a binary file
  : > "$TEST_DIR"/blank.txt
  output=$("$KEYWORDS" --dry-run -- "$TEST_DIR"/blank.txt 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 1 "$exit_code" 'Empty file exits 1'
  assert_contains "$output" '[Ee]mpty' 'Empty file reported as empty'

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# STDIN INPUT TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_stdin_input() {
  test_section "Stdin Input Validation"

  setup_test_env
  local -- output exit_code

  # Piped input
  output=$(echo "This is some test input text for the keywords extraction tool that should be long enough to pass validation" | "$KEYWORDS" --dry-run 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "Piped stdin input is processed"
  assert_contains "$output" "dry-run" "Dry-run works with stdin"

  # Empty stdin (using /dev/null)
  output=$("$KEYWORDS" < /dev/null 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 1 "$exit_code" "Empty stdin exits 1"
  assert_contains "$output" "[Ee]mpty" "Shows empty input error"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# TEXT LENGTH VALIDATION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_text_length() {
  test_section "Text Length Validation"

  setup_test_env
  local -- output exit_code

  # Text < 30 chars (too short)
  if [[ -f "$FIXTURES/short-input.txt" ]]; then
    output=$("$KEYWORDS" -- "$FIXTURES"/short-input.txt 2>&1) && exit_code=0 || exit_code=$?
    assert_exit_code 1 "$exit_code" "Text < 30 chars exits 1"
    assert_contains "$output" "too short" "Shows too short error"
  else
    # Create inline test
    output=$(echo "Too short" | "$KEYWORDS" 2>&1) && exit_code=0 || exit_code=$?
    assert_exit_code 1 "$exit_code" "Text < 30 chars exits 1 (inline)"
    assert_contains "$output" "too short" "Shows too short error (inline)"
  fi

  # Exactly 30 chars is the minimum
  output=$(printf '%s' 'This text has exactly 30 chars' | "$KEYWORDS" --dry-run 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" 'Text of exactly 30 chars succeeds'

  # Text > 30 chars
  if [[ -f "$FIXTURES/minimum-input.txt" ]]; then
    output=$("$KEYWORDS" --dry-run -- "$FIXTURES"/minimum-input.txt 2>&1) && exit_code=0 || exit_code=$?
    assert_exit_code 0 "$exit_code" "Text > 30 chars (31) succeeds"
  else
    # Create inline test with 31 chars
    output=$(printf '%s' "This text has exactly 31 chars!" | "$KEYWORDS" --dry-run 2>&1) && exit_code=0 || exit_code=$?
    assert_exit_code 0 "$exit_code" "Text > 30 chars (31) succeeds (inline)"
  fi

  # 500 chars, well over the minimum; builtins only, so nothing here can fail
  local -- long_text
  printf -v long_text '%500s' ''
  long_text=${long_text// /x}
  output=$(echo "$long_text" | "$KEYWORDS" --dry-run 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "Long text is processed"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# API KEY VALIDATION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_api_key_validation() {
  test_section "API Key Validation"

  local -- output exit_code

  # Create temp environment without API key
  local -- old_key="${ANTHROPIC_API_KEY:-}"
  unset ANTHROPIC_API_KEY

  # Try to run without API key
  output=$(echo "Test input text for API key validation test" | "$KEYWORDS" 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 1 "$exit_code" "Missing API key exits 1"
  assert_contains "$output" "ANTHROPIC_API_KEY" "Shows API key error"

  # The key is needed only for a real API call
  output=$(echo 'Test input text for a dry run without a key' | "$KEYWORDS" --dry-run 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" 'Dry run works without an API key'

  # Restore API key
  [[ -z $old_key ]] || export ANTHROPIC_API_KEY="$old_key"
}

# ═══════════════════════════════════════════════════════════════════════════════
# STOPWORDS INTEGRATION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_stopwords_integration() {
  test_section "Stopwords Integration"

  setup_test_env
  local -- output exit_code

  # Check if stopwords command exists
  if command -v stopwords >/dev/null 2>&1; then
    # -S with stopwords installed
    output=$(echo "This is some test input text for the keywords extraction tool" | "$KEYWORDS" -S --dry-run 2>&1) && exit_code=0 || exit_code=$?
    assert_exit_code 0 "$exit_code" "-S with stopwords works"
  else
    # -S without stopwords should exit 1
    output=$(echo "Test input" | "$KEYWORDS" -S 2>&1) && exit_code=0 || exit_code=$?
    assert_exit_code 1 "$exit_code" "-S without stopwords exits 1"
    assert_contains "$output" "stopwords" "Shows stopwords not found"
  fi

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL TESTS
# ═══════════════════════════════════════════════════════════════════════════════

main() {
  test_file_input
  test_stdin_input
  test_text_length
  test_api_key_validation
  test_stopwords_integration

  print_summary
}

main "$@"

#fin
