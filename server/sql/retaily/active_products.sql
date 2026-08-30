WITH catalog AS (
  SELECT
    product.id,
    product.name,
    product.cost,
    default_price.price AS price,
    product.margin,
    product.code,
    product.img_path,
    product.date_create,
    product.image_raw,
    product.active,
    product.user_modified,
    product.archived,
    COALESCE(inventory.available_quantity, 0) AS inventory_quantity
  FROM {{prefix}}.product AS product
  LEFT JOIN LATERAL (
    SELECT pricing_list.price
    FROM {{prefix}}.pricing_list
    WHERE pricing_list.product_id = product.id
      AND pricing_list.pricing_id = 1
    ORDER BY pricing_list.id DESC
    LIMIT 1
  ) AS default_price ON TRUE
  LEFT JOIN LATERAL (
    SELECT SUM(app_inventory.quantity) AS available_quantity
    FROM {{prefix}}.app_inventory AS app_inventory
    WHERE app_inventory.product_id = product.id
      AND app_inventory.store_id = $4
  ) AS inventory ON TRUE
  WHERE product.active = 1
    AND ($6::bigint IS NULL OR product.id = $6)
)
SELECT
  catalog.*,
  round(catalog.price::numeric / (1 + $3::numeric), 2) AS sub,
  round(catalog.price::numeric - round(catalog.price::numeric / (1 + $3::numeric), 2), 2) AS tax
FROM catalog
WHERE catalog.price IS NOT NULL
  AND ($1::bigint IS NULL OR catalog.id > $1)
  AND (
    NULLIF($5::text, '') IS NULL
    OR catalog.name ILIKE '%' || $5 || '%'
    OR COALESCE(catalog.code, '') ILIKE '%' || $5 || '%'
  )
ORDER BY catalog.id ASC
LIMIT $2;
