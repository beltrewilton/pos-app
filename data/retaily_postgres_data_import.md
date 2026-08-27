# Retaily MySQL data import into a Triplex tenant

`retaily_db_data.sql` is a 75 MB MySQL dump containing approximately 296,000
single-row `INSERT` statements. It must **not** be executed with `psql`: MySQL
identifiers, escaping rules, and its disabled foreign-key checks are not valid
in PostgreSQL.

## 1. Prepare the target tenant

1. Configure `server/.env` with the PostgreSQL connection details.
2. Run the application migrations from `server`:

   ```bash
   ./sh/migrate.sh
   ```

3. Create the destination tenant through the normal company/onboarding flow.
   That flow calls `Triplex.create_schema/3` and `Triplex.migrate/2`, so it
   applies `20260822030000_create_retaily_schema.exs` to the new tenant. Do not
   import Retaily tables into `public`.
4. Record the PostgreSQL schema name used by Triplex (referred to below as
   `<tenant_schema>`). Verify it before importing:

   ```sql
   SELECT table_name
   FROM information_schema.tables
   WHERE table_schema = '<tenant_schema>'
   ORDER BY table_name;
   ```

## 2. Restore the source dump to temporary MySQL

Use a temporary MySQL 8 database/container. This is the safest way to interpret
the dump's MySQL string escaping and `NULL` values; do not write a regex-based
SQL converter.

```bash
mysql -u <mysql_user> -p -e 'CREATE DATABASE retaily_import CHARACTER SET utf8mb4'
mysql -u <mysql_user> -p retaily_import < ../data/retaily_db_schema.sql
mysql -u <mysql_user> -p retaily_import < ../data/retaily_db_data.sql
```

Keep this database isolated from production. The dump starts with child rows
(for example, `app_inventory`) before their parent `product` rows, which only
worked in MySQL because the dump disables foreign-key checks.

## 3. Export each MySQL table as a PostgreSQL `COPY`-compatible file

The repository includes [`server/sh/import_retaily_data.sh`](../server/sh/import_retaily_data.sh),
which performs the explicit export and `\copy` for all 21 tables in the required
foreign-key order. Use a shared directory that is allowed by MySQL's
`secure_file_priv` setting and readable by `psql`:

```bash
cd server
EXPORT_DIR='/shared/mysql-postgres-export' \
./sh/import_retaily_data.sh
```

The script creates `DATABASE_URL` from `DB_USER`, `DB_PASS`, and `DB_NAME` in
`server/.env`, imports into the target tenant schema, uses
`mysql -u root retaily_import` for every export, never invokes the MySQL
password prompt, and refuses to overwrite an existing export file. It uses
MySQL's backslash-escaped tab-delimited output and PostgreSQL text `\copy`,
not CSV: this safely preserves the embedded commas, quotes, and newlines found
in the Retaily data.

For each table, the script exports an explicit column list in UTF-8, including
the original `id` values. It uses tab-delimited text with MySQL's default
backslash escaping and PostgreSQL `\copy FORMAT text`, so embedded commas,
double quotes, tabs, backslashes, and newlines remain safe. Database `NULL`
values are represented as `\N`, while an empty string remains empty.

Do not use CSV output, `sed`, or `awk` to transform this dump. The Retaily
`app_store.logo`, `app_users.pic`, and product image columns contain large text
values; the script streams them through the database clients instead of reading
the full dump into memory.

## 4. Load tables in parent-before-child order

Load each table completely before moving to the next group:

1. `app_store`, `app_users`, `app_sequence`, `bulk_order`, `client`,
   `delivery`, `pricing`, `product`, `product_bck`, `provider`, `scope_list`,
   `sale`, `sale_line`, `sale_paid`
2. `app_user_store`, `app_inventory`, `app_inventory_head`, `pricing_list`,
   `product_order`, `scopes`
3. `product_order_line`
4. `bulk_order_line`

`sale_line` and `sale_paid` have no foreign keys in the source schema, so they
may be loaded with the first group. Keep the original IDs for every table.

Run each `\copy` with `ON_ERROR_STOP=1`; retain the failed CSV batch and error
output if a load stops. Do not turn off PostgreSQL constraints in the target.

## 5. Reset identity sequences

Explicitly loaded IDs do not advance PostgreSQL sequences. After loading,
reset the `id` sequence for every table that has one (all Retaily tables except
`app_user_store`). Run this once per table, substituting the schema and table:

```sql
SELECT setval(
  pg_get_serial_sequence('<tenant_schema>.product', 'id'),
  COALESCE((SELECT MAX(id) FROM <tenant_schema>.product), 1),
  true
);
```

## 6. Validate before enabling the tenant

1. Compare `COUNT(*)` for every MySQL and PostgreSQL table.
2. Compare `MIN(id)`, `MAX(id)`, and a checksum of stable business columns for
   the high-volume tables: `sale`, `sale_line`, `sale_paid`, `product`,
   `client`, and `app_inventory`.
3. Check orphaned foreign keys in PostgreSQL. For example:

   ```sql
   SELECT COUNT(*) AS missing_products
   FROM <tenant_schema>.app_inventory inventory
   LEFT JOIN <tenant_schema>.product product ON product.id = inventory.product_id
   WHERE inventory.product_id IS NOT NULL AND product.id IS NULL;
   ```

4. Test one application read and one insert in the new tenant. The insert
   confirms that every sequence was reset correctly.
5. Only after validation, point the company/tenant to the imported schema and
   remove the temporary MySQL database and exported CSV files according to the
   retention policy.
