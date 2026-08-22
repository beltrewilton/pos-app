#!/usr/bin/env bash
set -e
set -a
[ -f .env ] && . ./.env
set +a
case "$(uname)" in
  Darwin) iex -S mix phx.server ;;
  *) mix phx.server ;;
esac
