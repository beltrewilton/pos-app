SELECT status, COUNT(*) AS count
FROM product_order
WHERE to_store_id = :store_id
GROUP BY status;
