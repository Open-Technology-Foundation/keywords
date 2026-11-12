#!/usr/bin/env bash
# Test suite for output format handling in keywords script

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

# Test input
TEST_INPUT="Test input text for output format validation testing"

# ═══════════════════════════════════════════════════════════════════════════════
# TEXT FORMAT TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_text_format() {
  test_section "Text Output Format"

  setup_test_env
  local -- output exit_code

  # Default text format (one keyword per line)
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run -f text 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "Text format succeeds"
  assert_contains "$output" "dry-run" "Text format outputs keyword"

  # Text with scores (-s)
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run -f text -s 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "Text with scores succeeds"
  assert_contains "$output" "|" "Text with scores uses pipe delimiter"

  # Text with types (-t)
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run -f text -t 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "Text with types succeeds"
  assert_contains "$output" "|" "Text with types uses pipe delimiter"

  # Text with both scores and types (-st)
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run -f text -st 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "Text with scores and types succeeds"
  # Should have two pipe delimiters (term|score|type). Counted with an expansion: a
  # grep pipeline fails when there is no match, which would end the suite under set -e
  local -- pipes=${output//[^|]/}
  assert_greater_than "${#pipes}" 1 "Text with both has multiple delimiters"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# CSV FORMAT TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_csv_format() {
  test_section "CSV Output Format"

  setup_test_env
  local -- output exit_code

  # CSV format: header goes to stderr (appended batches get no repeated header).
  # The stderr captures end in ||: because the exit status was already asserted above
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run -f csv 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "CSV format succeeds"
  assert_not_contains "$output" "term" "CSV rows on stdout carry no header"
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run -f csv 2>&1 >/dev/null) ||:
  assert_contains "$output" "term" "CSV has term header on stderr"

  # CSV with scores (-s)
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run -f csv -s 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "CSV with scores succeeds"
  assert_not_contains "$output" "term,score" "CSV -s rows on stdout carry no header"
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run -f csv -s 2>&1 >/dev/null) ||:
  assert_contains "$output" "term,score" "CSV has score header on stderr"

  # CSV with types (-t)
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run -f csv -t 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "CSV with types succeeds"
  assert_not_contains "$output" "term,type" "CSV -t rows on stdout carry no header"
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run -f csv -t 2>&1 >/dev/null) ||:
  assert_contains "$output" "term,type" "CSV has type header on stderr"

  # CSV with both (-st)
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run -f csv -st 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "CSV with scores and types succeeds"
  assert_not_contains "$output" "term,score,type" "CSV -st rows on stdout carry no header"
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run -f csv -st 2>&1 >/dev/null) ||:
  assert_contains "$output" "term,score,type" "CSV has all headers on stderr"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# JSON FORMAT TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_json_format() {
  test_section "JSON Output Format"

  setup_test_env
  local -- output exit_code

  # JSON format structure
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run -f json 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "JSON format succeeds"

  # Validate JSON structure
  assert_contains "$output" '"keywords"' "JSON has keywords array"
  assert_contains "$output" '"metadata"' "JSON has metadata object"

  # Validate metadata fields
  assert_contains "$output" '"model"' "JSON metadata has model"
  assert_contains "$output" '"timestamp"' "JSON metadata has timestamp"
  assert_contains "$output" '"api_calls"' "JSON metadata has api_calls"
  assert_contains "$output" '"cache_hits"' "JSON metadata has cache_hits"

  # Verify it's valid JSON using jq
  if command -v jq >/dev/null 2>&1; then
    echo "$output" | jq . >/dev/null 2>&1 && exit_code=0 || exit_code=$?
    assert_exit_code 0 "$exit_code" "JSON is valid (jq parse)"
  fi

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# OUTPUT FILE TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_output_file() {
  test_section "Output File Option"

  setup_test_env
  local -- output exit_code
  local -- output_file="$TEST_DIR/output.txt"

  # -o option writes to file
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run -o "$output_file" 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-o option succeeds"
  assert_file_exists "$output_file" "Output file created"

  # File contains output
  # Read only if present: a failed $(< file) would end the suite under set -e
  local -- file_content=''
  [[ ! -f $output_file ]] || file_content=$(< "$output_file")
  assert_contains "$file_content" "dry-run" "Output file has content"

  # Test with different formats
  local -- json_file="$TEST_DIR/output.json"
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run -f json -o "$json_file" 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-o with JSON format succeeds"
  file_content=''
  [[ ! -f $json_file ]] || file_content=$(< "$json_file")
  assert_contains "$file_content" '"keywords"' "JSON output file has keywords"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCORE FILTERING TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_score_filtering() {
  test_section "Score Filtering"

  setup_test_env
  local -- output exit_code

  # --min-score 0.0 returns all (default)
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run --min-score 0.0 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--min-score 0.0 works"

  # --min-score with various values
  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run --min-score 0.5 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--min-score 0.5 works"

  output=$(echo "$TEST_INPUT" | "$KEYWORDS" --dry-run --min-score 0.9 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--min-score 0.9 works"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL TESTS
# ═══════════════════════════════════════════════════════════════════════════════

main() {
  test_text_format
  test_csv_format
  test_json_format
  test_output_file
  test_score_filtering

  print_summary
}

main "$@"

#fin
