#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tool_root="${DARK_EVIDENCE_TOOLS:-$(dirname -- "$repo_root")/.dark-evidence-tools}"
export XDG_DATA_HOME="${DARK_EVIDENCE_DATA_HOME:-$tool_root/xdg/data}"
export XDG_CONFIG_HOME="$tool_root/xdg/config"
export XDG_CACHE_HOME="$tool_root/xdg/cache"
export XDG_RUNTIME_DIR="$tool_root/xdg/runtime"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
godot_binary="${GODOT_BIN:-$tool_root/godot-4.6.3/Godot_v4.6.3-stable_linux.x86_64}"
if [[ ! -x "$godot_binary" ]]; then
  printf 'Godot is not installed. Run: %s/tools/setup.sh\n' "$repo_root" >&2
  exit 1
fi
exec "$godot_binary" --path "$repo_root" "$@"
