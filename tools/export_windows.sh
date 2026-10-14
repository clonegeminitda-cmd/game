#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
build_mode="${1:-release}"
case "$build_mode" in
  release|debug) ;;
  *) printf 'Usage: %s [release|debug]\n' "$0" >&2; exit 2 ;;
esac
output_dir="$repo_root/builds/windows-$build_mode"
mkdir -p "$repo_root/builds"
stage_dir="$(mktemp -d "$repo_root/builds/.windows-$build_mode.XXXXXX")"
trap 'rm -rf -- "$stage_dir"' EXIT
command -v python3 >/dev/null || { printf 'Python 3 is required to package the build.\n' >&2; exit 1; }
test -s "$repo_root/docs/RUN-WINDOWS.txt"
test -s "$repo_root/assets/licenses/Godot.txt"
test -s "$repo_root/assets/licenses/Godot-ThirdParty.txt"
"$repo_root/tools/godot.sh" --headless --editor --import
"$repo_root/tools/godot.sh" --headless "--export-$build_mode" "Windows Desktop" "$stage_dir/DarkEvidence.exe"
test -s "$stage_dir/DarkEvidence.exe"
cp -- "$repo_root/docs/RUN-WINDOWS.txt" "$stage_dir/RUN-WINDOWS.txt"
mkdir -p "$stage_dir/LICENSES"
cp -- "$repo_root/assets/licenses/"*.txt "$repo_root/assets/fonts/"LICENSE*.txt "$stage_dir/LICENSES/"
archive_path="$repo_root/builds/DarkEvidence-Windows-x86_64-$build_mode.zip"
python3 - "$stage_dir" "$archive_path" <<'PY'
import hashlib
import pathlib
import sys
import zipfile

stage = pathlib.Path(sys.argv[1])
archive = pathlib.Path(sys.argv[2])
files = sorted(path for path in stage.rglob("*") if path.is_file())
with (stage / "SHA256SUMS.txt").open("w", encoding="utf-8", newline="\n") as checksums:
    for path in files:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        checksums.write(f"{digest}  {path.relative_to(stage).as_posix()}\n")
with zipfile.ZipFile(str(archive) + ".part", "w", zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
    for path in sorted(stage.rglob("*")):
        if path.is_file():
            bundle.write(path, "DarkEvidence/" + path.relative_to(stage).as_posix())
pathlib.Path(str(archive) + ".part").replace(archive)
PY
mkdir -p "$output_dir"
cp -a -- "$stage_dir/." "$output_dir/"
printf 'Windows x86_64 build: %s/DarkEvidence.exe\nPackage: %s\n' "$output_dir" "$archive_path"
