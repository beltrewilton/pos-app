#!/usr/bin/env bash

# Create/update a GitHub Release and upload Tauri package artifacts.
#
# Usage:
#   bash scripts/release.sh 0.2.1
#   bash scripts/release.sh 0.2.1 path/to/Tigoo.POS_0.2.1_amd64.deb

set -euo pipefail

readonly REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: bash scripts/release.sh <version|vversion> [artifact ...]

Examples:
  bash scripts/release.sh 0.2.1
  bash scripts/release.sh v0.2.1 client/src-tauri/target/x86_64-unknown-linux-gnu/release/bundle/deb/*.deb

Without explicit artifact paths, the script uploads Tauri package files found
under client/src-tauri/target/ and the generated Android output directory.
Existing assets with the same name are replaced.
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

[[ $# -gt 0 ]] || {
  usage
  exit 1
}

case "$1" in
  -h|--help)
    usage
    exit 0
    ;;
esac

version="$1"
shift
tag="${version#v}"
tag="v${tag}"

command -v gh >/dev/null 2>&1 || fail "GitHub CLI is required. Install it from https://cli.github.com/"
gh auth status >/dev/null 2>&1 || fail "Authenticate GitHub CLI first: gh auth login"

cd "${REPOSITORY_ROOT}"

artifacts=()
if [[ $# -gt 0 ]]; then
  for artifact in "$@"; do
    [[ -f "${artifact}" ]] || fail "Artifact does not exist: ${artifact}"
    artifacts+=("${artifact}")
  done
else
  while IFS= read -r -d '' artifact; do
    artifact_name="${artifact##*/}"
    case "${artifact_name}" in
      *.apk|*.aab) ;;
      *"${version}"*) ;;
      *) continue ;;
    esac
    artifacts+=("${artifact}")
  done < <(
    find client/src-tauri/target client/src-tauri/gen/android/app/build/outputs \
      -type f \( \
        -name '*.deb' -o -name '*.rpm' -o -name '*.AppImage' -o \
        -name '*.msi' -o -name '*-setup.exe' -o -name '*.dmg' -o \
        -name '*.apk' -o -name '*.aab' \
      \) -print0 2>/dev/null || true
  )
fi

[[ ${#artifacts[@]} -gt 0 ]] || fail "No release artifacts found. Run scripts/build-release.sh first or pass artifact paths explicitly."

if gh release view "${tag}" >/dev/null 2>&1; then
  printf 'Updating existing GitHub Release %s\n' "${tag}"
  gh release upload "${tag}" "${artifacts[@]}" --clobber
else
  # Prefer an existing remote tag. If none exists, create and push an annotated
  # tag for the current commit before creating the release.
  if ! git ls-remote --exit-code --tags origin "refs/tags/${tag}" >/dev/null 2>&1; then
    if ! git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
      git tag -a "${tag}" -m "Tigoo POS ${tag}"
    fi
    git push origin "refs/tags/${tag}"
  fi

  printf 'Creating GitHub Release %s\n' "${tag}"
  gh release create "${tag}" "${artifacts[@]}" \
    --title "Tigoo POS ${tag}" \
    --generate-notes
fi

printf 'Release published: '
gh release view "${tag}" --json url --jq .url
