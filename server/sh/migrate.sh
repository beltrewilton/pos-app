#!/usr/bin/env bash
set -e
server_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$server_dir"
set -a
[ -f .env ] && . ./.env
set +a
mix ecto.migrate "$@"
mix triplex.migrate "$@"
