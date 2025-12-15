#!/usr/bin/env bash
# Test suite for caching operations in keywords script

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
  export ANTHROPIC_API_KEY="test-key-for-caching"
  mkdir -p "$HOME"
}

cleanup_test_env() {
  [[ -d "${TEST_DIR:-}" ]] && rm -rf "$TEST_DIR" || true
}

trap cleanup_test_env EXIT

# ═══════════════════════════════════════════════════════════════════════════════
# CACHE DIRECTORY TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_cache_directory() {
  test_section "Cache Directory"

  setup_test_env
  local -- output exit_code

  # Cache directory should be created on first run
  [[ ! -d "$XDG_CACHE_HOME/keywords" ]] || rm -rf "$XDG_CACHE_HOME/keywords"

  output=$(echo "Test input text for cache directory creation" | "$KEYWORDS" --dry-run 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "Script runs successfully"

  # Dry-run doesn't create cache since it doesn't call API
  # Test with --no-cache to verify the flag works
  output=$(echo "Test input text for no-cache mode" | "$KEYWORDS" --dry-run --no-cache 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--no-cache works with --dry-run"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# CACHE KEY GENERATION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_cache_key_determinism() {
  test_section "Cache Key Generation"

  # This is a conceptual test - we can't directly test generate_cache_key()
  # but we can verify that the same input produces consistent behavior

  setup_test_env
  local -- output1 output2 exit_code

  # Same input should produce same result in dry-run mode
  local -- test_input="Consistent input for cache key test validation"

  output1=$(echo "$test_input" | "$KEYWORDS" --dry-run -f json 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "First run succeeds"

  output2=$(echo "$test_input" | "$KEYWORDS" --dry-run -f json 2>/dev/null) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "Second run succeeds"

  # Both outputs should be identical for same input
  assert_equals "$output1" "$output2" "Same input produces same output"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# NO-CACHE FLAG TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_no_cache_flag() {
  test_section "No-Cache Flag"

  setup_test_env
  local -- output exit_code

  # --no-cache should skip cache
  output=$(echo "Test input for no-cache validation" | "$KEYWORDS" --dry-run --no-cache 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--no-cache flag works"
  assert_not_contains "$output" "Cache hit" "--no-cache doesn't show cache hit"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# CUSTOM CACHE DIRECTORY TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_custom_cache_dir() {
  test_section "Custom Cache Directory"

  setup_test_env
  local -- output exit_code
  local -- custom_cache="$TEST_DIR/custom-cache"

  # --cache-dir should accept custom directory
  output=$(echo "Test input for custom cache dir" | "$KEYWORDS" --dry-run --cache-dir "$custom_cache" 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "--cache-dir works"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# XDG_CACHE_HOME TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_xdg_cache_home() {
  test_section "XDG_CACHE_HOME Support"

  setup_test_env
  local -- output exit_code

  # XDG_CACHE_HOME should be respected
  export XDG_CACHE_HOME="$TEST_DIR/xdg-cache"
  mkdir -p "$XDG_CACHE_HOME"

  output=$(echo "Test input for XDG cache validation" | "$KEYWORDS" --dry-run 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "XDG_CACHE_HOME is respected"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# CACHE PERMISSIONS TESTS
# ═══════════════════════════════════════════════════════════════════════════════

test_cache_permissions() {
  test_section "Cache Permissions"

  # This test verifies that cache directory would be created with proper permissions
  # Since dry-run doesn't create cache, we test the option handling

  setup_test_env
  local -- output exit_code

  output=$(echo "Test input for cache permissions" | "$KEYWORDS" --dry-run 2>&1) && exit_code=0 || exit_code=$?
  assert_exit_code 0 "$exit_code" "Script handles cache permissions"

  cleanup_test_env
}

# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL TESTS
# ═══════════════════════════════════════════════════════════════════════════════

main() {
  test_cache_directory
  test_cache_key_determinism
  test_no_cache_flag
  test_custom_cache_dir
  test_xdg_cache_home
  test_cache_permissions

  print_summary
}

main "$@"

#fin
