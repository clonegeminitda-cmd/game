#!/usr/bin/env bash
# Launch the actual game briefly without replacing a player's existing save.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
smoke_data_dir="$(mktemp -d /tmp/dark-evidence-smoke.XXXXXXXX)"
trap 'rm -rf -- "$smoke_data_dir"' EXIT
export DARK_EVIDENCE_DATA_HOME="$smoke_data_dir"
case "${1:-headless}" in
  headless) "$repo_root/tools/godot.sh" --headless -- --smoke ;;
  render) "$repo_root/tools/with_display.sh" "$repo_root/tools/godot.sh" --audio-driver Dummy -- --smoke ;;
  *) printf 'Usage: bash tests/smoke.sh [headless|render]\n' >&2; exit 2 ;;
esac
