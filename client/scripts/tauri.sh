#!/usr/bin/env sh

set -eu

case "${1:-}:${2:-}" in
  dev:*|android:dev|ios:dev)
    env_file="../server/.env"
    cargo_env_file="../../server/.env"
    environment_name="development"
    ;;
  *)
    env_file="../server/.env-prod"
    cargo_env_file="../../server/.env-prod"
    environment_name="production"
    ;;
esac

if [ ! -f "$env_file" ]; then
  echo "Missing $environment_name environment file: $env_file" >&2
  exit 1
fi

# Export the selected variables to both the Tauri CLI and Cargo. The Rust build
# script uses TAURI_ENV_FILE to embed PHOENIX_SERVER_DNS in the app.
set -a
. "$env_file"
set +a
export TAURI_ENV_FILE="$cargo_env_file"

# `npm run tauri -- prod` is a convenient production desktop-build alias.
if [ "${1:-}" = "prod" ]; then
  shift
  set -- build "$@"
fi

# Mobile production builds use the same alias form, for example:
# `npm run tauri -- android prod` and `npm run tauri -- ios prod`.
case "${1:-}" in
  android|ios)
    platform="$1"
    shift
    if [ "${1:-}" = "prod" ]; then
      shift
      set -- "$platform" build "$@"
    else
      set -- "$platform" "$@"
    fi
    ;;
esac

exec ./node_modules/.bin/tauri "$@"
