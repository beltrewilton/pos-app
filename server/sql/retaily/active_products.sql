WITH catalog AS (
  SELECT
    product.id,
    product.name,
    product.cost,
    COALESCE(default_price.price, product.price) AS price,
    product.margin,
    product.code,
    product.img_path,
    product.date_create,
    product.image_raw,
    product.active,
    product.user_modified,
    product.archived
  FROM {{prefix}}.product AS product
  LEFT JOIN LATERAL (
    SELECT pricing_list.price
    FROM {{prefix}}.pricing_list
    WHERE pricing_list.product_id = product.id
      AND pricing_list.pricing_id = 1
    ORDER BY pricing_list.id DESC
    LIMIT 1
  ) AS default_price ON TRUE
  WHERE product.active = 1
)
SELECT
  catalog.*,
  round(catalog.price::numeric / (1 + $3::numeric), 2) AS sub,
  round(catalog.price::numeric - round(catalog.price::numeric / (1 + $3::numeric), 2), 2) AS tax
FROM catalog
WHERE catalog.price IS NOT NULL
  AND ($1::bigint IS NULL OR catalog.id > $1)
ORDER BY catalog.id ASC
LIMIT $2;
