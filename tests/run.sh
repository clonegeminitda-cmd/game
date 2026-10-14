#!/usr/bin/env bash
# Test saves never share the player's user:// directory.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_data_dir="$(mktemp -d /tmp/dark-evidence-tests.XXXXXXXX)"
trap 'rm -rf -- "$test_data_dir"' EXIT
export DARK_EVIDENCE_DATA_HOME="$test_data_dir"
export DARK_EVIDENCE_TEST_RUN=1
"$repo_root/tools/godot.sh" --headless --editor --import >/dev/null
"$repo_root/tools/godot.sh" --headless --script res://tests/test_suite.gd "$@"
