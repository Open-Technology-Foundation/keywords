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

  # -m haiku-4-5
  output=$("$KEYWORDS" -m haiku-4-5 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "-m haiku-4-5 accepts full model name"

  # --model sonnet-4-5
  output=$("$KEYWORDS" --model sonnet-4-5 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--model sonnet-4-5 works"

  # --model opus-4-5
  output=$("$KEYWORDS" --model opus-4-5 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--model opus-4-5 works"

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

  # --temperature
  output=$("$KEYWORDS" --temperature 0.5 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--temperature 0.5 works"

  output=$("$KEYWORDS" --temperature 0 --help 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--temperature 0 works"

  output=$("$KEYWORDS" --temperature abc 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 2 "$exit_code" "--temperature abc exits 2 (invalid)"

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

  print_summary
}

main "$@"

#fin
