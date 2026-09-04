#!/usr/bin/env bash

# Build production Tigoo POS artifacts for one or more platforms.
#
# Examples:
#   bash scripts/build-release.sh mac android
#   bash scripts/build-release.sh windows linux
#
# Windows cross-builds produce an NSIS installer (MSI still requires Windows).
# Linux cross-builds run in Docker. macOS builds require macOS. Android requires
# the generated src-tauri/gen/android project and a configured release keystore.

set -euo pipefail

readonly REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CLIENT_DIR="${REPOSITORY_ROOT}/client"
readonly PROD_ENV_FILE="${REPOSITORY_ROOT}/server/.env-prod"

usage() {
  cat <<'EOF'
Usage: bash scripts/build-release.sh <platform> [platform ...]

Platforms:
  windows  Build Windows x64 installer; non-Windows hosts produce NSIS only.
  linux    Build Linux x64 AppImage, DEB, and RPM (uses Docker off Linux).
  mac      Build macOS Apple Silicon and Intel DMGs (run on macOS).
  android  Build Android AAB and APK (requires Android project and signing).

Examples:
  bash scripts/build-release.sh mac android
  bash scripts/build-release.sh windows linux
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

build_windows() {
  local host_os
  host_os="$(uname -s)"

  case "${host_os}" in
    MINGW*|MSYS*|CYGWIN*)
      npm run tauri -- prod --target x86_64-pc-windows-msvc
      ;;
    *)
      command -v cargo-xwin >/dev/null 2>&1 || cargo install --locked cargo-xwin
      rustup target add x86_64-pc-windows-msvc
      npm run tauri -- prod --bundles nsis --runner cargo-xwin --target x86_64-pc-windows-msvc
      ;;
  esac
}

build_linux() {
  if [[ "$(uname -s)" == "Linux" ]]; then
    npm run tauri -- prod --target x86_64-unknown-linux-gnu
    return
  fi

  command -v docker >/dev/null 2>&1 || fail "Linux cross-builds require Docker when not running on Linux."
  docker run --rm \
    --platform linux/amd64 \
    --volume "${REPOSITORY_ROOT}:/work" \
    --workdir /work/client \
    node:22-bookworm \
    bash -lc '
      set -euo pipefail
      apt-get update
      apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl file libwebkit2gtk-4.1-dev \
        libappindicator3-dev librsvg2-dev patchelf pkg-config xdg-utils
      curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
      export PATH="$HOME/.cargo/bin:$PATH"
      npm ci
      npm run tauri -- prod --target x86_64-unknown-linux-gnu
    '
}

build_mac() {
  [[ "$(uname -s)" == "Darwin" ]] || fail "macOS artifacts can only be built on macOS because Apple tooling is required. Use a macOS CI runner."
  rustup target add aarch64-apple-darwin x86_64-apple-darwin
  npm run tauri -- prod --target aarch64-apple-darwin
  npm run tauri -- prod --target x86_64-apple-darwin
}

build_android() {
  case "$(uname -s)" in
    Darwin|Linux) ;;
    *) fail "Android builds require macOS or Linux (current host: $(uname -s))." ;;
  esac
  [[ -d src-tauri/gen/android ]] || fail "Android project is missing. Run: cd client && npm run tauri -- android init"
  npm run tauri -- android prod --aab
  npm run tauri -- android prod --apk
}

[[ $# -gt 0 ]] || {
  usage
  exit 1
}

platforms=()
seen_platforms=" "
for platform in "$@"; do
  case "${platform}" in
    windows|linux|mac|android)
      if [[ "${seen_platforms}" == *" ${platform} "* ]]; then
        printf 'Skipping duplicate platform: %s\n' "${platform}"
        continue
      fi
      platforms+=("${platform}")
      seen_platforms+="${platform} "
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "Unknown platform: ${platform}"
      ;;
  esac
done

[[ -f "${PROD_ENV_FILE}" ]] || fail "Production environment file is missing: ${PROD_ENV_FILE}"

# A Docker-based Linux cross-build installs its own dependencies. Every other
# build path uses the local Tauri CLI.
needs_local_tauri=false
for platform in "${platforms[@]}"; do
  if [[ "${platform}" != "linux" || "$(uname -s)" == "Linux" ]]; then
    needs_local_tauri=true
  fi
done
if [[ "${needs_local_tauri}" == true ]]; then
  [[ -x "${CLIENT_DIR}/node_modules/.bin/tauri" ]] || fail "Tauri dependencies are missing. Run: cd client && npm ci"
fi

cd "${CLIENT_DIR}"

for platform in "${platforms[@]}"; do
  printf '\n==> Building %s release artifacts\n' "${platform}"
  "build_${platform}"
done

printf '\nRelease build completed. See DEPLOYMENT.md for artifact paths, signing, validation, and GitHub Release publication.\n'
