#!/usr/bin/env bash
set -euo pipefail

# Required:
#   EXPORT_DIR=/shared/mysql-postgres-export \
#   ./sh/import_retaily_data.sh
#
# DATABASE_URL is constructed from DB_USER, DB_PASS, and DB_NAME in .env.
# The target Triplex tenant schema is always educa.
# EXPORT_DIR must be writable by the MySQL SERVER, allowed by its secure_file_priv
# setting, and readable by the host running psql. When MySQL runs in Docker,
# use a bind-mounted directory for EXPORT_DIR.

server_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

if [[ ! -f "$server_dir/.env" ]]; then
  echo "Missing $server_dir/.env" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source "$server_dir/.env"
set +a

: "${DB_USER:?Set DB_USER in server/.env}"
: "${DB_PASS:?Set DB_PASS in server/.env}"
: "${DB_NAME:?Set DB_NAME in server/.env}"

DATABASE_URL="postgresql://${DB_USER}:${DB_PASS}@localhost/${DB_NAME}"
TENANT_SCHEMA='educa'
: "${EXPORT_DIR:?Set EXPORT_DIR to a shared MySQL/PostgreSQL export directory}"

if [[ ! "$TENANT_SCHEMA" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
  echo "TENANT_SCHEMA must be a PostgreSQL identifier" >&2
  exit 1
fi

if [[ ! "$EXPORT_DIR" = /* ]]; then
  echo "EXPORT_DIR must be an absolute path" >&2
  exit 1
fi

mysql_escape() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\'/\'\'}
  printf '%s' "$value"
}

export_and_copy() {
  local table=$1
  local columns=$2
  local export_path="$EXPORT_DIR/$table.tsv"
  local mysql_export_path

  mysql_export_path=$(mysql_escape "$export_path")

  if [[ -e "$export_path" ]]; then
    echo "Refusing to overwrite existing export: $export_path" >&2
    exit 1
  fi

  echo "Exporting $table from MySQL..."
  mysql -u root retaily_import -e "
    SELECT $columns
    INTO OUTFILE '$mysql_export_path'
    FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\'
    LINES TERMINATED BY '\\n'
    FROM $table
  "

  echo "Loading $table into $TENANT_SCHEMA..."
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c \
    "\\copy \"$TENANT_SCHEMA\".\"$table\" ($columns) FROM '$export_path' WITH (FORMAT text, DELIMITER E'\\t', NULL '\\N')"
}

reset_sequence() {
  local table=$1

  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c \
    "SELECT setval(
       pg_get_serial_sequence('$TENANT_SCHEMA.$table', 'id'),
       COALESCE((SELECT MAX(id) FROM \"$TENANT_SCHEMA\".\"$table\"), 1),
       true
     );"
}

# Parent tables and tables without declared foreign keys.
export_and_copy app_store 'id, name, date_create, company_id, slogan, logo, address'
export_and_copy app_users 'id, username, password, first_name, last_name, is_active, date_joined, last_login, pic'
export_and_copy app_sequence 'id, name, code, prefix, fill, increment_by, current_seq'
export_and_copy bulk_order 'id, name, memo, date_create, user_create'
export_and_copy client 'id, name, document_id, address, celphone, email, date_create, wholesaler'
export_and_copy delivery 'id, name, value'
export_and_copy pricing 'id, label, user_modified, date_create, price_key, status'
export_and_copy product 'id, name, cost, price, margin, code, img_path, date_create, image_raw, active, user_modified, archived'
export_and_copy product_bck 'id, name, cost, price, margin, code, img_path, date_create, image_raw, active, user_modified'
export_and_copy provider 'id, name, date_create'
export_and_copy scope_list 'id, name'
export_and_copy sale 'id, amount, sub, discount, tax_amount, delivery_charge, sequence, sequence_type, status, sale_type, date_create, login, client_id, store_id, additional_info'
export_and_copy sale_line 'id, amount, tax_amount, discount, quantity, total_amount, sale_id, product_id'
export_and_copy sale_paid 'id, amount, type, date_create, sale_id'

# Tables with declared foreign keys.
export_and_copy app_user_store 'user_id, store_id'
export_and_copy app_inventory 'id, prev_quantity, quantity, next_quantity, status, last_update, user_updated, product_id, store_id'
export_and_copy app_inventory_head 'id, name, date_create, date_close, status, memo, store_id'
export_and_copy pricing_list 'id, price, user_modified, date_create, product_id, pricing_id'
export_and_copy product_order 'id, name, memo, order_type, user_requester, user_receiver, date_opened, date_closed, from_origin_id, to_store_id, status'
export_and_copy scopes 'id, name, user_id'
export_and_copy product_order_line 'id, product_id, from_origin_id, to_store_id, product_order_id, quantity, quantity_observed, status, date_create, user_receiver, receiver_last_update, receiver_memo'
export_and_copy bulk_order_line 'id, bulk_order_id, product_order_id'

# Preserve the imported IDs and make the next generated ID valid.
for table in \
  app_store app_users app_sequence bulk_order client delivery pricing product \
  product_bck provider scope_list sale sale_line sale_paid app_inventory \
  app_inventory_head pricing_list product_order scopes product_order_line bulk_order_line; do
  reset_sequence "$table"
done

echo "Retaily import completed for tenant schema: $TENANT_SCHEMA"
