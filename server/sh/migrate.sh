#!/usr/bin/env bash
set -euo pipefail
server_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$server_dir"

tenant_schema=''
if [[ $# -gt 0 ]]; then
  tenant_schema=$1
  shift
fi

set -a
[ -f .env ] && . ./.env
set +a

if [[ -n "$tenant_schema" && ! "$tenant_schema" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
  echo "TENANT_SCHEMA must be a PostgreSQL identifier" >&2
  exit 1
fi

mix ecto.migrate "$@"

# Without a tenant, only public Ecto migrations are requested.
if [[ -z "$tenant_schema" ]]; then
  exit 0
fi

# Tenant migrations only run against schemas that already exist. Create the
# Retaily import schema on first use; Triplex.create also applies its tenant
# migrations, while the task below brings existing schemas up to date.
TENANT_SCHEMA="$tenant_schema" mix run -e '
tenant = System.fetch_env!("TENANT_SCHEMA")

unless Triplex.exists?(tenant, PosServer.Repo) do
  {:ok, _tenant} = Triplex.create(tenant, PosServer.Repo)
end
'

mix triplex.migrate "$@"
