#!/usr/bin/env bash
set -e
set -a
[ -f .env ] && . ./.env
set +a
mix ecto.migrate "$@"
mix triplex.migrate "$@"
