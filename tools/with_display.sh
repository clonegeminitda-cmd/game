#!/usr/bin/env bash
set -euo pipefail
# Run a command with an isolated virtual screen and software OpenGL. The X11
# socket uses a random authorization cookie, and TCP listening is disabled.
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tool_root="${DARK_EVIDENCE_TOOLS:-$(dirname -- "$repo_root")/.dark-evidence-tools}"
if (( $# == 0 )); then
  printf 'Usage: %s command [args...]\n' "$0" >&2
  exit 2
fi
if command -v Xvfb >/dev/null; then
  xvfb_binary="$(command -v Xvfb)"
else
  xvfb_binary="$tool_root/xvfb-root/usr/bin/Xvfb"
  export LD_LIBRARY_PATH="$tool_root/xvfb-root/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
if [[ ! -x "$xvfb_binary" ]]; then
  printf 'Xvfb is missing. Run tools/setup.sh --with-xvfb first.\n' >&2
  exit 1
fi
for required_tool in xauth xdpyinfo od; do
  command -v "$required_tool" >/dev/null || { printf 'Missing prerequisite: %s\n' "$required_tool" >&2; exit 1; }
done
display_dir="$(mktemp -d /tmp/dark-evidence-display.XXXXXX)"
xvfb_pid=""
cleanup() {
  if [[ -n "$xvfb_pid" ]]; then
    kill "$xvfb_pid" 2>/dev/null || true
    wait "$xvfb_pid" 2>/dev/null || true
  fi
  rm -rf -- "$display_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
export XAUTHORITY="$display_dir/auth"
touch "$XAUTHORITY"
cookie="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
xauth -f "$XAUTHORITY" add :0 MIT-MAGIC-COOKIE-1 "$cookie"
"$xvfb_binary" -displayfd 3 -screen 0 "${DARK_EVIDENCE_SCREEN:-1280x720x24}" \
  -nolisten tcp -auth "$XAUTHORITY" 3> "$display_dir/number" > "$display_dir/xvfb.log" 2>&1 &
xvfb_pid=$!
for ((attempt=0; attempt<100; attempt++)); do
  if [[ -s "$display_dir/number" ]]; then break; fi
  if ! kill -0 "$xvfb_pid" 2>/dev/null; then cat "$display_dir/xvfb.log" >&2; exit 1; fi
  sleep 0.1
done
if [[ ! -s "$display_dir/number" ]]; then
  cat "$display_dir/xvfb.log" >&2
  printf 'Virtual display did not become ready within 10 seconds.\n' >&2
  exit 1
fi
export DISPLAY=":$(cat "$display_dir/number")"
xauth -f "$XAUTHORITY" add "$DISPLAY" MIT-MAGIC-COOKIE-1 "$cookie"
unset cookie
xdpyinfo >/dev/null
export LIBGL_ALWAYS_SOFTWARE=1
"$@"
