#!/usr/bin/env bash
# Test suite for API integration in keywords script
# Includes mocked tests and optional live tests

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
# MOCK CURL SETUP
# ═══════════════════════════════════════════════════════════════════════════════

# Create a mock curl that returns a fixture
mock_curl() {
  local -- fixture_file="$1"
  local -i mock_exit_code="${2:-0}"

  must_write "$MOCK_DIR"/curl << 'MOCK_SCRIPT'
#!/usr/bin/env bash
# Mock curl - returns fixture content
cat "$KEYWORDS_MOCK_FIXTURE"
exit "$KEYWORDS_MOCK_EXIT"
MOCK_SCRIPT

  must chmod -- +x "$MOCK_DIR"/curl
  export KEYWORDS_MOCK_FIXTURE="$fixture_file"
  export KEYWORDS_MOCK_EXIT="$mock_exit_code"
}

unmock_curl() {
  must rm -f -- "$MOCK_DIR"/curl
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
  must_write "$MOCK_DIR"/curl << 'MOCK_SCRIPT'
#!/usr/bin/env bash
exit 7  # curl exit code for connection failure
MOCK_SCRIPT
  must chmod -- +x "$MOCK_DIR"/curl
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
# REQUEST AND RESPONSE SHAPE (Claude 5.5 models)
# ═══════════════════════════════════════════════════════════════════════════════

declare -r KEYWORDS_JSON='{"keywords":[{"term":"vector search","score":0.9,"type":"technical"}]}'

# Mock curl that returns $TEST_DIR/response.json and records what it was given:
# its argv, the request body, and any header file passed as -H @FILE
mock_curl_recording() {
  must_write "$MOCK_DIR"/curl << 'MOCK_SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$KEYWORDS_MOCK_ARGV"
: > "$KEYWORDS_MOCK_HEADERS"
while (($#)); do
  case $1 in
    -d) printf '%s' "$2" > "$KEYWORDS_MOCK_BODY" ;;
    --data-binary) [[ $2 == @- ]] && cat > "$KEYWORDS_MOCK_BODY" || printf '%s' "$2" > "$KEYWORDS_MOCK_BODY" ;;
    -H) [[ $2 != @* ]] || cat -- "${2:1}" >> "$KEYWORDS_MOCK_HEADERS" ;;
  esac
  shift
done
cat "$KEYWORDS_MOCK_FIXTURE"
MOCK_SCRIPT

  must chmod -- +x "$MOCK_DIR"/curl
  export KEYWORDS_MOCK_FIXTURE="$TEST_DIR"/response.json
  export KEYWORDS_MOCK_BODY="$TEST_DIR"/request-body.json
  export KEYWORDS_MOCK_ARGV="$TEST_DIR"/argv.txt
  export KEYWORDS_MOCK_HEADERS="$TEST_DIR"/headers.txt
  export KEYWORDS_MOCK_EXIT=0
  export ANTHROPIC_API_KEY=test-mock-key
}

# write_response CONTENT_BLOCKS_JSON [STOP_REASON]
write_response() {
  jq -n --argjson content "$1" --arg stop_reason "${2:-end_turn}" \
    '{type: "message", role: "assistant", content: $content, stop_reason: $stop_reason}' \
    > "$TEST_DIR"/response.json \
    || { >&2 echo "Test setup failed: cannot write ${TEST_DIR@Q}/response.json"; return 1; }
}

text_block() { jq -n --arg text "$1" '{type: "text", text: $text}'; }

test_thinking_block_before_text() {
  test_section 'Response Starting With a Thinking Block'

  setup_test_env
  local -- output exit_code
  mock_curl_recording
  write_response "[{\"type\":\"thinking\",\"thinking\":\"\",\"signature\":\"sig\"},$(text_block "$KEYWORDS_JSON")]"

  output=$(echo 'Test input for a thinking-first response' | "$KEYWORDS" --no-cache 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" 'Thinking-first response succeeds'
  assert_contains "$output" 'vector search' 'Keywords read from the text block'

  unmock_curl
  cleanup_test_env
}

test_refusal_reported() {
  test_section 'Refused Request'

  setup_test_env
  local -- output exit_code
  mock_curl_recording
  write_response '[]' refusal

  output=$(echo 'Input text for a declined request' | "$KEYWORDS" --no-cache 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 1 "$exit_code" 'Refusal exits 1'
  assert_contains "$output" 'declined' 'Refusal is named in the error'

  unmock_curl
  cleanup_test_env
}

test_truncated_response_reported() {
  test_section 'Truncated Response'

  setup_test_env
  local -- output exit_code
  mock_curl_recording
  write_response "[$(text_block '{"keywords":[{"term":"vector sea')]" max_tokens

  output=$(echo 'Input text for a truncated response' | "$KEYWORDS" --no-cache 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 1 "$exit_code" 'Truncated response exits 1'
  assert_contains "$output" 'max-tokens' 'Error points at --max-tokens'

  unmock_curl
  cleanup_test_env
}

test_request_body_defaults() {
  test_section 'Request Body Defaults'

  setup_test_env
  mock_curl_recording
  write_response "[$(text_block "$KEYWORDS_JSON")]"

  echo 'Test input for inspecting the default request body' | "$KEYWORDS" --no-cache &>/dev/null ||:
  assert_equals false "$(jq -r 'has("temperature")' < "$KEYWORDS_MOCK_BODY")" 'temperature is not sent by default'
  assert_equals 8000 "$(jq -r '.max_tokens' < "$KEYWORDS_MOCK_BODY")" 'Default max_tokens leaves room for thinking'
  assert_equals low "$(jq -r '.output_config.effort' < "$KEYWORDS_MOCK_BODY")" \
    'Effort is set explicitly, not left to per-model defaults'
  assert_contains "$(< "$KEYWORDS_MOCK_ARGV")" '--retry' 'Transient failures are retried'

  unmock_curl
  cleanup_test_env
}

test_api_key_not_on_command_line() {
  test_section 'API Key Kept Off the Command Line'

  setup_test_env
  mock_curl_recording
  write_response "[$(text_block "$KEYWORDS_JSON")]"

  echo 'Input text for inspecting how the key is passed' | "$KEYWORDS" --no-cache &>/dev/null ||:
  assert_not_contains "$(< "$KEYWORDS_MOCK_ARGV")" 'test-mock-key' 'API key absent from curl argv'
  assert_not_contains "$(< "$KEYWORDS_MOCK_ARGV")" 'how the key is passed' 'Document text absent from curl argv'
  assert_contains "$(< "$KEYWORDS_MOCK_HEADERS")" 'x-api-key: test-mock-key' 'API key delivered through a header file'

  unmock_curl
  cleanup_test_env
}

# Fails on any input over Linux's 131,072-byte limit for a single argument
test_large_input() {
  test_section 'Input Larger Than One Argument'

  setup_test_env
  local -- output exit_code input
  mock_curl_recording
  write_response "[$(text_block "$KEYWORDS_JSON")]"
  # 21 bytes x 8000 = 168,000 bytes, over the 131,072-byte limit
  input=$(printf 'vector search scales %.0s' {1..8000})

  output=$("$KEYWORDS" --no-cache <<< "$input" 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" '168 KB input succeeds'
  assert_greater_than "$(jq -r '.messages[0].content | length' 2>/dev/null < "$KEYWORDS_MOCK_BODY")" 167999 \
    'Whole document reaches the request body'

  if command -v stopwords &>/dev/null; then
    output=$("$KEYWORDS" --no-cache -S <<< "$input" 2>&1) && exit_code=0 || exit_code=$?
    assert_exit_code 0 "$exit_code" '168 KB input succeeds with -S'
  else
    skip_test 'stopwords not installed'
  fi

  unmock_curl
  cleanup_test_env
}

test_csv_quoting() {
  test_section 'CSV Quoting'

  setup_test_env
  local -- output
  mock_curl_recording
  write_response "[$(text_block '{"keywords":[{"term":"Jakarta, Indonesia","score":0.9,"type":"entity"}]}')]"

  output=$("$KEYWORDS" --no-cache -f csv <<< 'Input text for checking CSV quoting' 2>/dev/null) ||:
  assert_equals '"Jakarta, Indonesia"' "$output" 'Plain CSV quotes a term containing a comma'

  unmock_curl
  cleanup_test_env
}

test_keywords_sorted_by_score() {
  test_section 'Keywords Sorted by Score'

  setup_test_env
  local -- output unsorted
  mock_curl_recording
  # A non-numeric score must sort last, not make the reply unparseable
  unsorted='{"keywords":[{"term":"low","score":0.5},{"term":"odd","score":"n/a"},'
  unsorted+='{"term":"top","score":0.9},{"term":"mid","score":0.7}]}'
  write_response "[$(text_block "$unsorted")]"

  output=$("$KEYWORDS" --no-cache <<< 'Input text for checking keyword order' 2>/dev/null) ||:
  assert_equals $'top\nmid\nlow\nodd' "$output" 'Keywords are listed by descending score'

  output=$("$KEYWORDS" --no-cache -n 2 <<< 'Input text for checking keyword order' 2>/dev/null) ||:
  assert_equals $'top\nmid' "$output" '-n keeps the highest-scoring keywords'

  unmock_curl
  cleanup_test_env
}

test_statistics_counters() {
  test_section 'Statistics Counters'

  setup_test_env
  local -- output
  mock_curl_recording
  write_response "[$(text_block "$KEYWORDS_JSON")]"

  output=$("$KEYWORDS" -f json <<< 'Input text for counting calls and hits' 2>/dev/null) ||:
  assert_equals 1 "$(jq -r '.metadata.api_calls' <<< "$output")" 'api_calls counts the request'
  output=$("$KEYWORDS" -f json <<< 'Input text for counting calls and hits' 2>/dev/null) ||:
  assert_equals 1 "$(jq -r '.metadata.cache_hits' <<< "$output")" 'cache_hits counts the cache hit'
  assert_equals 0 "$(jq -r '.metadata.api_calls' <<< "$output")" 'No API call on a cache hit'

  unmock_curl
  cleanup_test_env
}

test_cache_write_failure() {
  test_section 'Cache Write Failure'

  setup_test_env
  local -- output exit_code
  mock_curl_recording
  write_response "[$(text_block "$KEYWORDS_JSON")]"
  must touch -- "$TEST_DIR"/not-a-dir

  output=$("$KEYWORDS" --cache-dir "$TEST_DIR"/not-a-dir/cache <<< 'Input text for an unwritable cache' 2>&1) \
    && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" 'Keywords still delivered when the cache cannot be written'
  assert_contains "$output" 'vector search' 'Keywords printed'
  assert_contains "$output" 'Could not write cache' 'Cache failure reported'
  assert_not_contains "$output" 'Result cached' 'No false success message'

  unmock_curl
  cleanup_test_env
}

test_cache_reuse_and_pruning() {
  test_section 'Cache Reuse and Pruning'

  setup_test_env
  local -- output
  local -- stale="$XDG_CACHE_HOME"/keywords/0000-stale.json
  mock_curl_recording
  write_response "[$(text_block "$KEYWORDS_JSON")]"
  must mkdir -p -- "${stale%/*}"
  must_write "$stale" <<< '{}'
  must touch -d '2 days ago' -- "$stale"

  "$KEYWORDS" <<< 'Input text for cache reuse checks' &>/dev/null ||:
  assert_equals absent "$([[ -e $stale ]] && echo present || echo absent)" 'Expired entries pruned on write'

  must rm -f -- "$KEYWORDS_MOCK_ARGV"
  output=$("$KEYWORDS" --min-score 0.95 <<< 'Input text for cache reuse checks' 2>/dev/null) ||:
  assert_equals absent "$([[ -e $KEYWORDS_MOCK_ARGV ]] && echo present || echo absent)" \
    'A different --min-score reuses the cached result'
  assert_not_contains "$output" 'vector search' '--min-score still filters a cached result'

  unmock_curl
  cleanup_test_env
}

test_cache_dir_leading_dash() {
  test_section 'Cache Directory Beginning With a Dash'

  setup_test_env
  local -- work="$TEST_DIR"/work output exit_code
  local -a entries=()
  mock_curl_recording
  write_response "[$(text_block "$KEYWORDS_JSON")]"
  must mkdir -p -- "$work"
  must touch -- "$work"/notes.txt

  # find reads a starting point that begins with - as expression, -- or not, so the cache
  # prune once ran -delete on the current directory. The subshell and scratch dir keep a
  # regression from reaching anything outside this test
  (cd -- "$work" && "$KEYWORDS" --cache-dir -delete <<< 'Input text for a dash cache dir') \
    &>/dev/null ||:
  assert_equals present "$([[ -e $work/notes.txt ]] && echo present || echo absent)" \
    'Files in the current directory survive --cache-dir -delete'
  entries=("$work"/-delete/*.json)
  assert_equals 1 "${#entries[@]}" 'Result cached in ./-delete'

  # ./ is added to relative paths, which would turn an empty value into the current directory
  output=$("$KEYWORDS" --dry-run --cache-dir '' <<< 'Input text for an empty cache dir' 2>&1) \
    && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" 'Empty --cache-dir is a usage error'
  assert_contains "$output" '--cache-dir' 'Error names the option'

  unmock_curl
  cleanup_test_env
}

test_output_file_kept_on_failure() {
  test_section 'Output File Kept on Failure'

  setup_test_env
  mock_curl_recording
  write_response '[]' refusal
  must_write "$TEST_DIR"/out.txt <<< 'previous results'

  "$KEYWORDS" --no-cache -o "$TEST_DIR"/out.txt <<< 'Input text for a failed extraction' &>/dev/null ||:
  assert_equals 'previous results' "$(< "$TEST_DIR"/out.txt)" '-o leaves the existing file alone on failure'

  # An unwritable destination is caught before the (paid) API call, not after it
  local -- output exit_code
  write_response "[$(text_block "$KEYWORDS_JSON")]"
  must rm -f -- "$KEYWORDS_MOCK_ARGV"
  output=$("$KEYWORDS" --no-cache -o "$TEST_DIR"/missing/out.txt <<< 'Input text for a missing directory' 2>&1) \
    && exit_code=0 || exit_code=$?
  assert_exit_code 1 "$exit_code" '-o into a missing directory exits 1'
  assert_contains "$output" 'not writable' '-o into a missing directory explained'
  assert_equals absent "$([[ -e $KEYWORDS_MOCK_ARGV ]] && echo present || echo absent)" \
    'No API call when the output cannot be written'

  # A failed write is a runtime error (1), never the usage-error status (2)
  "$KEYWORDS" --dry-run <<< 'Input text for a closed standard output' >&- 2>/dev/null && exit_code=0 || exit_code=$?
  assert_exit_code 1 "$exit_code" 'Closed stdout exits 1'

  unmock_curl
  cleanup_test_env
}

test_response_json_extraction() {
  test_section 'JSON Extraction From the Response Text'

  setup_test_env
  local -- output exit_code
  mock_curl_recording

  local -- prose=$'Here are the keywords:\n{\n  "keywords": [\n'
  prose+=$'    {"term": "vector search", "score": 0.9, "type": "technical"}\n  ]\n}\nHope this helps.'
  write_response "[$(text_block "$prose")]"
  output=$("$KEYWORDS" --no-cache <<< 'Input text for JSON wrapped in prose' 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" 'Pretty-printed JSON inside prose is accepted'
  assert_contains "$output" 'vector search' 'Keywords read from the embedded JSON'

  write_response "[$(text_block '{"keywords":"vector search"}')]"
  output=$("$KEYWORDS" --no-cache <<< 'Input text for a malformed keywords field' 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 1 "$exit_code" 'Non-array keywords field exits 1'
  assert_contains "$output" 'Could not parse' 'Non-array keywords field reported as unparseable'

  unmock_curl
  cleanup_test_env
}

# A command earlier in the caller's PATH must not replace the script's tools
test_inherited_path_ignored() {
  test_section 'Inherited PATH Ignored'

  setup_test_env
  local -- decoy="$TEST_DIR"/decoy
  must mkdir -p -- "$decoy"
  printf '#!/bin/bash\ntouch %q\nexec /usr/bin/sha256sum "$@"\n' "$TEST_DIR"/decoy-ran \
    | must_write "$decoy"/sha256sum
  must chmod -- +x "$decoy"/sha256sum
  export ANTHROPIC_API_KEY=test-key

  env PATH="$decoy:$PATH" "$KEYWORDS" --dry-run <<< 'Input text for the inherited PATH check' &>/dev/null ||:
  assert_equals absent "$([[ -e $TEST_DIR/decoy-ran ]] && echo present || echo absent)" \
    'sha256sum not taken from the inherited PATH'

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
  test_thinking_block_before_text
  test_refusal_reported
  test_truncated_response_reported
  test_request_body_defaults
  test_api_key_not_on_command_line
  test_large_input
  test_csv_quoting
  test_keywords_sorted_by_score
  test_statistics_counters
  test_cache_write_failure
  test_cache_reuse_and_pruning
  test_cache_dir_leading_dash
  test_output_file_kept_on_failure
  test_response_json_extraction
  test_inherited_path_ignored
  test_dry_run_no_api
  test_live_api

  print_summary
}

main "$@"

#fin
