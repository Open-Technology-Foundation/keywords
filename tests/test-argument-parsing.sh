#!/usr/bin/env bash
# Test suite for argument parsing in keywords script

set -euo pipefail
shopt -s inherit_errexit extglob nullglob

# Script metadata
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Source test helpers
#shellcheck source=test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

# Keywords script (exported by run-all-tests.sh or set here)
KEYWORDS="${KEYWORDS_SCRIPT:-$SCRIPT_DIR/../keywords}"

# ═══════════════════════════════════════════════════════════════════════════════
# HELP AND VERSION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_help_options() {
  test_section "Help and Version Options"

  local -- output exit_code

  # --help
  output=$("$KEYWORDS" --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--help exits with 0"
  assert_contains "$output" "Usage:" "--help shows Usage"
  assert_contains "$output" "OPTIONS:" "--help shows OPTIONS"
  assert_contains "$output" "EXAMPLES:" "--help shows EXAMPLES"

  # -h (short form)
  output=$("$KEYWORDS" -h 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-h exits with 0"
  assert_contains "$output" "Usage:" "-h shows Usage"

  # --version
  output=$("$KEYWORDS" --version 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--version exits with 0"
  assert_contains "$output" "keywords" "--version shows script name"
  assert_contains "$output" "[0-9]+\.[0-9]+\.[0-9]+" "--version shows semver"

  # -V (short form)
  output=$("$KEYWORDS" -V 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-V exits with 0"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MODEL SELECTION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_model_selection() {
  test_section "Model Selection Options"

  local -- output exit_code

  # Valid model names (tested via --dry-run to avoid API calls)
  # These should NOT fail at argument parsing stage

  # -m haiku (short alias)
  output=$("$KEYWORDS" -m haiku --dry-run --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-m haiku accepts short model name"

  # -m haiku-5-5
  output=$("$KEYWORDS" -m haiku-5-5 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-m haiku-5-5 accepts versioned model name"

  # --model sonnet-5-5
  output=$("$KEYWORDS" --model sonnet-5-5 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--model sonnet-5-5 works"

  # --model opus-5-5
  output=$("$KEYWORDS" --model opus-5-5 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--model opus-5-5 works"

  # Full model ID
  output=$("$KEYWORDS" -m claude-opus-5-5 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-m claude-opus-5-5 accepts full model ID"

  # Superseded models are no longer supported
  output=$("$KEYWORDS" -m haiku-4-5 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "-m haiku-4-5 exits 2 (superseded model)"

  # ANTHROPIC_MODEL goes through the same validation as -m
  local -- text='Sample input text that is long enough to pass validation'
  output=$(echo "$text" | ANTHROPIC_API_KEY=test-key ANTHROPIC_MODEL=sonnet "$KEYWORDS" --dry-run 2>&1) \
    && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "ANTHROPIC_MODEL=sonnet is accepted"

  output=$(echo "$text" | ANTHROPIC_API_KEY=test-key ANTHROPIC_MODEL=claude-haiku-4-5 "$KEYWORDS" --dry-run 2>&1) \
    && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "ANTHROPIC_MODEL=claude-haiku-4-5 exits 2 (superseded model)"
  assert_contains "$output" "Invalid model" "Superseded ANTHROPIC_MODEL shows error message"

  # Invalid model name
  output=$("$KEYWORDS" --model invalid-model 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "--model invalid-model exits 2"
  assert_contains "$output" "Invalid model" "Invalid model shows error message"

  # Missing value for -m
  output=$("$KEYWORDS" -m 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "-m without value exits 2"
  assert_contains "$output" "Missing value" "-m without value shows error"
}

# ═══════════════════════════════════════════════════════════════════════════════
# NUMERIC OPTIONS TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_numeric_options() {
  test_section "Numeric Options"

  local -- output exit_code

  # -n / --max-keywords
  output=$("$KEYWORDS" -n 10 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-n 10 works"

  output=$("$KEYWORDS" --max-keywords 50 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--max-keywords 50 works"

  output=$("$KEYWORDS" -n 0 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "-n 0 exits 2 (invalid)"

  output=$("$KEYWORDS" -n -5 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "-n -5 exits 2 (invalid)"

  output=$("$KEYWORDS" -n 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "-n without value exits 2"

  # --timeout
  output=$("$KEYWORDS" --timeout 120 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--timeout 120 works"

  output=$("$KEYWORDS" --timeout 0 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "--timeout 0 exits 2 (invalid)"

  output=$("$KEYWORDS" --timeout 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "--timeout without value exits 2"

  # --max-tokens
  output=$("$KEYWORDS" --max-tokens 4000 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--max-tokens 4000 works"

  output=$("$KEYWORDS" --max-tokens 0 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "--max-tokens 0 exits 2 (invalid)"

  # --temperature was removed: current models reject the parameter
  output=$("$KEYWORDS" --temperature 0.5 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "--temperature exits 2 (option removed)"
  assert_contains "$output" "Unknown option" "--temperature reported as unknown option"

  # --min-score
  output=$("$KEYWORDS" --min-score 0.5 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--min-score 0.5 works"

  output=$("$KEYWORDS" --min-score abc 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "--min-score abc exits 2 (invalid)"
}

# ═══════════════════════════════════════════════════════════════════════════════
# FORMAT OPTIONS TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_format_options() {
  test_section "Format Options"

  local -- output exit_code

  # Valid formats
  output=$("$KEYWORDS" -f text --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-f text works"

  output=$("$KEYWORDS" -f json --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-f json works"

  output=$("$KEYWORDS" -f csv --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-f csv works"

  output=$("$KEYWORDS" --format text --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--format text works"

  # Invalid format
  output=$("$KEYWORDS" -f xml 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "-f xml exits 2 (invalid format)"
  assert_contains "$output" "Invalid format" "-f xml shows error"

  # Missing value
  output=$("$KEYWORDS" -f 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "-f without value exits 2"
}

# ═══════════════════════════════════════════════════════════════════════════════
# FLAG OPTIONS TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_flag_options() {
  test_section "Flag Options"

  local -- output exit_code

  # Boolean flags (should all work with --help)
  output=$("$KEYWORDS" -s --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-s (scores) flag works"

  output=$("$KEYWORDS" -t --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-t (types) flag works"

  output=$("$KEYWORDS" -e --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-e (entities) flag works"

  output=$("$KEYWORDS" -v --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-v (verbose) flag works"

  output=$("$KEYWORDS" -q --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-q (quiet) flag works"

  output=$("$KEYWORDS" --dry-run --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--dry-run flag works"

  output=$("$KEYWORDS" --no-cache --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--no-cache flag works"

  output=$("$KEYWORDS" --scores --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--scores long form works"

  output=$("$KEYWORDS" --types --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--types long form works"

  output=$("$KEYWORDS" --entities --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--entities long form works"

  output=$("$KEYWORDS" --verbose --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--verbose long form works"

  output=$("$KEYWORDS" --quiet --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--quiet long form works"
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMBINED SHORT OPTIONS TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_combined_options() {
  test_section "Combined Short Options"

  local -- output exit_code

  # Combined flags should expand correctly
  output=$("$KEYWORDS" -stev --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-stev expands to -s -t -e -v"

  output=$("$KEYWORDS" -qste --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-qste expands correctly"
}

# ═══════════════════════════════════════════════════════════════════════════════
# OUTPUT FILE TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_output_options() {
  test_section "Output Options"

  local -- output exit_code

  # -o / --output
  output=$("$KEYWORDS" -o /tmp/test-output.txt --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-o /tmp/test-output.txt works"

  output=$("$KEYWORDS" --output /tmp/test-output.txt --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--output works"

  output=$("$KEYWORDS" -o 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "-o without value exits 2"

  # --cache-dir
  output=$("$KEYWORDS" --cache-dir /tmp/test-cache --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--cache-dir works"

  output=$("$KEYWORDS" --cache-dir 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "--cache-dir without value exits 2"
}

# ═══════════════════════════════════════════════════════════════════════════════
# UNKNOWN OPTIONS TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_unknown_options() {
  test_section "Unknown Options"

  local -- output exit_code

  # Unknown long option
  output=$("$KEYWORDS" --unknown-flag 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "--unknown-flag exits 2"
  assert_contains "$output" "Unknown option" "--unknown-flag shows error"

  # Unknown short option
  output=$("$KEYWORDS" -z 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "-z (unknown) exits 2"
}

# ═══════════════════════════════════════════════════════════════════════════════
# OPTION VALUE VALIDATION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_option_value_validation() {
  test_section 'Option Value Validation'

  local -- output exit_code tmp
  tmp=$(mktemp -d)

  # Integer options must not be evaluated as arithmetic (command execution via subscripts)
  output=$("$KEYWORDS" -n "VERBOSE[\$(touch $tmp/pwned)]" --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" '-n with an arithmetic expression exits 2'
  assert_equals absent "$([[ -e $tmp/pwned ]] && echo present || echo absent)" '-n value is never executed'

  output=$("$KEYWORDS" -n abc --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" '-n abc exits 2'
  assert_contains "$output" 'Invalid' '-n abc shows an Invalid message'

  output=$("$KEYWORDS" -n 5.5 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" '-n 5.5 exits 2'

  output=$("$KEYWORDS" --timeout 10s --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" '--timeout 10s exits 2'

  output=$("$KEYWORDS" --max-tokens 1e3 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" '--max-tokens 1e3 exits 2'

  # --min-score is a 0.0-1.0 relevance score
  output=$("$KEYWORDS" --min-score 5 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" '--min-score 5 exits 2 (out of range)'

  output=$("$KEYWORDS" --min-score 1 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" '--min-score 1 works'

  output=$("$KEYWORDS" --min-score 1.0 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" '--min-score 1.0 works'

  rm -rf "$tmp"
}

# ═══════════════════════════════════════════════════════════════════════════════
# OPERAND TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_operands() {
  test_section 'Operands and Bundling'

  local -- output exit_code tmp
  tmp=$(mktemp -d)
  local -- text='Operand test input with enough characters to pass'
  echo "$text" > "$tmp"/-notes.txt
  echo "$text" > "$tmp"/a.txt
  echo "$text" > "$tmp"/b.txt
  : > "$tmp"/e

  # Bundles must not pick up letters from filenames in the working directory
  output=$(cd "$tmp" && "$KEYWORDS" '-q?' --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "-q? exits 2 even when a file named 'e' exists"

  output=$("$KEYWORDS" -qm haiku --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" '-qm haiku bundles an option that takes a value'

  output=$(cd "$tmp" && "$KEYWORDS" --dry-run --no-cache -- -notes.txt 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" '-- allows a filename starting with -'
  assert_contains "$output" 'dry-run' 'File after -- is processed'

  output=$(echo "$text" | "$KEYWORDS" --dry-run --no-cache - 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" '- reads stdin'

  output=$("$KEYWORDS" --dry-run --no-cache "$tmp"/a.txt "$tmp"/b.txt 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" 'Two input files exit 2'
  assert_contains "$output" 'one input file' 'Two input files explained'

  rm -rf "$tmp"
}

# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL TESTS
# ═══════════════════════════════════════════════════════════════════════════════

main() {
  test_help_options
  test_model_selection
  test_numeric_options
  test_format_options
  test_flag_options
  test_combined_options
  test_output_options
  test_unknown_options
  test_option_value_validation
  test_operands

  print_summary
}

main "$@"

#fin
