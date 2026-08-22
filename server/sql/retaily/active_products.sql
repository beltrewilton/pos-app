SELECT
  id,
  name,
  cost,
  price,
  margin,
  code,
  img_path,
  date_create,
  image_raw,
  active,
  user_modified,
  archived
FROM {{prefix}}.product
WHERE active = 1
  AND ($1::bigint IS NULL OR id > $1)
ORDER BY id ASC
LIMIT $2;
