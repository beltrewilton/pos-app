#!/usr/bin/env bash
# Refresh the offline UI kit. Runtime code must only reference the copied assets.
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHADCN_HTML_VERSION="0.7.13-alpha"
SHADCN_HTML_REF="v${SHADCN_HTML_VERSION}"
LUCIDE_VERSION="0.468.0"
INTER_VERSION="v20"
COMPONENTS=(typography button input label card form separator alert dialog toast table select)
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# A local source is useful for reviewing a candidate update before publishing it.
# Without it, the pinned GitHub archive is the only remote shadcn-html source.
SOURCE_DIR="${SHADCN_HTML_SOURCE_DIR:-}"
if [[ -z "$SOURCE_DIR" ]]; then
  ARCHIVE="$WORK_DIR/shadcn-html.tar.gz"
  curl --fail --location --silent --show-error \
    "https://github.com/codylindley/shadcn-html/archive/refs/tags/${SHADCN_HTML_REF}.tar.gz" \
    --output "$ARCHIVE"
  tar -xzf "$ARCHIVE" -C "$WORK_DIR"
  SOURCE_DIR="$WORK_DIR/shadcn-html-${SHADCN_HTML_REF#v}/dist"
else
  SOURCE_DIR="${SOURCE_DIR%/}/dist"
fi

[[ -f "$SOURCE_DIR/theme/default-semantic-tokens.css" ]] || { echo "Missing shadcn-html distribution at $SOURCE_DIR" >&2; exit 1; }

KIT="$ROOT/ui/shadcn-html"
rm -rf "$KIT"
mkdir -p "$KIT/components"
cp "$SOURCE_DIR/theme/default-semantic-tokens.css" "$KIT/default-semantic-tokens.css"
for component in "${COMPONENTS[@]}"; do
  source_component="$SOURCE_DIR/components/$component"
  [[ -f "$source_component/component-skill.md" && -f "$source_component/$component.css" ]] || { echo "Invalid $component component" >&2; exit 1; }
  cp -R "$source_component" "$KIT/components/$component"
done

mkdir -p "$ROOT/ui/fonts" "$ROOT/ui/icons"
# Google Fonts-hosted Inter variable Latin; used for all numeric POS values.
# This revisioned gstatic URL is intentionally pinned and recorded in the manifest.
INTER_URL="https://fonts.gstatic.com/s/inter/v20/UcCo3FwrK3iLTcviYwY.woff2"
curl --fail --location --silent --show-error "$INTER_URL" --output "$ROOT/ui/fonts/inter-latin-variable.woff2"
NATURE_FONT_URLS=(
  "https://fonts.gstatic.com/s/montserrat/v31/JTUSjIg1_i6t8kCHKm459WlhyyTh89Y.woff2"
  "https://fonts.gstatic.com/s/merriweather/v33/u-4e0qyriQwlOrhSvowK_l5UcA6zuSYEqOzpPe3HOZJ5eX1WtLaQwmYiSeqqJ-mXq1Gi.woff2"
  "https://fonts.gstatic.com/s/sourcecodepro/v31/HI_SiYsKILxRpg3hIP6sJ7fM7PqlPevWnsUnxg.woff2"
)
NATURE_FONT_FILES=(montserrat-latin-variable.woff2 merriweather-latin-variable.woff2 source-code-pro-latin-variable.woff2)
for index in "${!NATURE_FONT_URLS[@]}"; do
  curl --fail --location --silent --show-error "${NATURE_FONT_URLS[$index]}" --output "$ROOT/ui/fonts/${NATURE_FONT_FILES[$index]}"
done
# Doom 64's display face; this revisioned gstatic URL contains the Latin
# variable range used by the opt-in theme.
OXANIUM_URL="https://fonts.gstatic.com/s/oxanium/v21/RrQQboN_4yJ0JmiMe2LE0ZJCZ4c.woff2"
curl --fail --location --silent --show-error "$OXANIUM_URL" --output "$ROOT/ui/fonts/oxanium-latin-variable.woff2"
curl --fail --location --silent --show-error \
  "https://unpkg.com/lucide@${LUCIDE_VERSION}/dist/umd/lucide.min.js" \
  --output "$ROOT/ui/icons/lucide-${LUCIDE_VERSION}.min.js"

rm -rf "$ROOT/client/src/vendor/ui" "$ROOT/server/priv/static/assets/ui"
mkdir -p "$ROOT/client/src/vendor/ui" "$ROOT/server/priv/static/assets/ui"
cp -R "$ROOT/ui/shadcn-html/." "$ROOT/client/src/vendor/ui/"
cp -R "$ROOT/ui/shadcn-html/." "$ROOT/server/priv/static/assets/ui/"
mkdir -p "$ROOT/client/src/vendor/ui/fonts" "$ROOT/client/src/vendor/ui/icons" "$ROOT/server/priv/static/assets/ui/fonts" "$ROOT/server/priv/static/assets/ui/icons"
cp "$ROOT/ui/fonts/inter-latin-variable.woff2" "$ROOT/client/src/vendor/ui/fonts/"
cp "$ROOT/ui/fonts/inter-latin-variable.woff2" "$ROOT/server/priv/static/assets/ui/fonts/"
cp "$ROOT/ui/fonts/montserrat-latin-variable.woff2" "$ROOT/ui/fonts/merriweather-latin-variable.woff2" "$ROOT/ui/fonts/source-code-pro-latin-variable.woff2" "$ROOT/client/src/vendor/ui/fonts/"
cp "$ROOT/ui/fonts/montserrat-latin-variable.woff2" "$ROOT/ui/fonts/merriweather-latin-variable.woff2" "$ROOT/ui/fonts/source-code-pro-latin-variable.woff2" "$ROOT/server/priv/static/assets/ui/fonts/"
cp "$ROOT/ui/fonts/oxanium-latin-variable.woff2" "$ROOT/client/src/vendor/ui/fonts/"
cp "$ROOT/ui/fonts/oxanium-latin-variable.woff2" "$ROOT/server/priv/static/assets/ui/fonts/"
cp "$ROOT/ui/fonts/inter.css" "$ROOT/client/src/vendor/ui/fonts/"
cp "$ROOT/ui/fonts/inter.css" "$ROOT/server/priv/static/assets/ui/fonts/"
cp "$ROOT/ui/fonts/nature.css" "$ROOT/client/src/vendor/ui/fonts/"
cp "$ROOT/ui/fonts/nature.css" "$ROOT/server/priv/static/assets/ui/fonts/"
cp "$ROOT/ui/fonts/doom-64.css" "$ROOT/client/src/vendor/ui/fonts/"
cp "$ROOT/ui/fonts/doom-64.css" "$ROOT/server/priv/static/assets/ui/fonts/"
cp "$ROOT/ui/icons/lucide-${LUCIDE_VERSION}.min.js" "$ROOT/client/src/vendor/ui/icons/"
cp "$ROOT/ui/icons/lucide-${LUCIDE_VERSION}.min.js" "$ROOT/server/priv/static/assets/ui/icons/"

{
  echo "shadcn-html=${SHADCN_HTML_VERSION} (${SHADCN_HTML_REF})"
  echo "lucide=${LUCIDE_VERSION}"
  echo "inter=${INTER_VERSION}"
  echo "inter-url=${INTER_URL}"
  echo
  (cd "$ROOT" && shasum -a 256 ui/shadcn-html/default-semantic-tokens.css ui/fonts/inter-latin-variable.woff2 ui/icons/lucide-${LUCIDE_VERSION}.min.js)
  for component in "${COMPONENTS[@]}"; do
    (cd "$ROOT" && find "ui/shadcn-html/components/$component" -type f -print0 | sort -z | xargs -0 shasum -a 256)
  done
} > "$ROOT/ui/manifest.txt"

echo "Updated offline UI assets and ui/manifest.txt"
