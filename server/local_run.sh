#!/usr/bin/env bash
set -e
set -a
[ -f .env ] && . ./.env
set +a
iex -S mix phx.server
