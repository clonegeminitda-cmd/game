#!/usr/bin/env bash
set -euo pipefail

# Local, non-root setup. The checksums are published by the upstream release at:
# https://github.com/godotengine/godot/releases/download/4.6.3-stable/SHA512-SUMS.txt
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tool_root="${DARK_EVIDENCE_TOOLS:-$(dirname -- "$repo_root")/.dark-evidence-tools}"
godot_version=4.6.3
release_url="https://github.com/godotengine/godot/releases/download/${godot_version}-stable"
editor_name="Godot_v${godot_version}-stable_linux.x86_64.zip"
templates_name="Godot_v${godot_version}-stable_export_templates.tpz"
editor_sha512=a035258da32b77f966a5376f9fa29c30a6adde826a85ba918e1605bd1fc9823eba7d85f1dd5e748956bd2ba72827c0025ffa11bb82aec91128c407a2e723c99c
templates_sha512=da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68
with_xvfb=false
case "${1:-}" in
  "") ;;
  --with-xvfb) with_xvfb=true ;;
  *) printf 'Usage: %s [--with-xvfb]\n' "$0" >&2; exit 2 ;;
esac
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  printf 'This setup script requires Linux x86_64. See docs/BUILD.md for other hosts.\n' >&2
  exit 1
fi
for required_tool in curl unzip sha512sum; do
  command -v "$required_tool" >/dev/null || { printf 'Missing prerequisite: %s\n' "$required_tool" >&2; exit 1; }
done
mkdir -p "$tool_root/downloads" "$tool_root/godot-$godot_version" \
  "$tool_root/xdg/data/godot/export_templates/$godot_version.stable" \
  "$tool_root/xdg/cache" "$tool_root/xdg/config" "$tool_root/xdg/runtime"
chmod 700 "$tool_root/xdg/runtime"

verify_download() {
  local name="$1" expected="$2" destination="$tool_root/downloads/$1"
  if [[ ! -f "$destination" ]]; then
    curl --fail --location --silent --show-error --retry 2 \
      "$release_url/$name" --output "$destination.part"
    printf '%s  %s\n' "$expected" "$destination.part" | sha512sum --check --strict -
    mv -- "$destination.part" "$destination"
  else
    printf '%s  %s\n' "$expected" "$destination" | sha512sum --check --strict -
  fi
}

verify_download "$editor_name" "$editor_sha512"
verify_download "$templates_name" "$templates_sha512"
unzip -oq "$tool_root/downloads/$editor_name" -d "$tool_root/godot-$godot_version"
chmod +x "$tool_root/godot-$godot_version/Godot_v$godot_version-stable_linux.x86_64"
# Only Windows x86_64 templates are required for this project.
unzip -joq "$tool_root/downloads/$templates_name" \
  templates/version.txt 'templates/windows_*_x86_64.exe' \
  'templates/windows_*_x86_64_console.exe' \
  -d "$tool_root/xdg/data/godot/export_templates/$godot_version.stable"

if "$with_xvfb" && ! command -v Xvfb >/dev/null; then
  # Signed Debian metadata + APT hash verification remain enabled. No packages
  # are installed into the host: download and unpack under tool_root only.
  if [[ ! -r /usr/share/keyrings/debian-archive-keyring.gpg || ! -x /usr/bin/apt-get ]]; then
    printf 'Local Xvfb setup requires Debian and its trusted archive keyring.\n' >&2
    exit 1
  fi
  . /etc/os-release
  if [[ "${ID:-}" != debian || "${VERSION_CODENAME:-}" != trixie ]]; then
    printf 'Local Xvfb packages are supported on Debian 13 (trixie) only.\n' >&2
    exit 1
  fi
  apt_root="$tool_root/apt"
  mkdir -p "$apt_root/lists/partial" "$apt_root/archives/partial" "$apt_root/empty" "$tool_root/xvfb-root"
  cat > "$apt_root/sources.list" <<'SOURCES'
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://deb.debian.org/debian trixie main
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://deb.debian.org/debian-security trixie-security main
SOURCES
  cat > "$apt_root/config" <<CONFIG
Dir::Etc::main "-";
Dir::Etc::parts "$apt_root/empty";
Dir::Etc::sourcelist "$apt_root/sources.list";
Dir::Etc::sourceparts "-";
Dir::State::lists "$apt_root/lists";
Dir::Cache::archives "$apt_root/archives";
APT::Get::List-Cleanup "false";
Acquire::Languages "none";
CONFIG
  APT_CONFIG="$apt_root/config" /usr/bin/apt-get update
  package_dir="$(mktemp -d "$apt_root/archives/current.XXXXXX")"
  (
    cd -- "$package_dir"
    APT_CONFIG="$apt_root/config" /usr/bin/apt-get download xvfb xserver-common libxfont2
  )
  for package_file in "$package_dir/"*.deb; do
    dpkg-deb --extract "$package_file" "$tool_root/xvfb-root"
  done
  rm -rf -- "$package_dir"
  if LD_LIBRARY_PATH="$tool_root/xvfb-root/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
      ldd "$tool_root/xvfb-root/usr/bin/Xvfb" | grep -F 'not found'; then
    printf 'Xvfb has unresolved shared libraries; install the listed prerequisites before rendering.\n' >&2
    exit 1
  fi
fi

"$repo_root/tools/godot.sh" --headless --version
printf 'Ready: Godot %s and verified Windows x86_64 export templates in %s\n' "$godot_version" "$tool_root"
