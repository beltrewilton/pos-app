SELECT
  client.id,
  client.name,
  client.document_id,
  client.address,
  client.celphone,
  client.email,
  client.date_create,
  client.wholesaler,
  COALESCE(SUM(GREATEST(sale.amount - COALESCE(payment_totals.total_paid, 0), 0)) FILTER (WHERE sale.status <> 'RETURN'), 0) AS pending_balance,
  MAX(sale.date_create) FILTER (WHERE sale.status <> 'RETURN') AS last_purchase_date
FROM {{prefix}}.client AS client
LEFT JOIN {{prefix}}.sale AS sale ON sale.client_id = client.id
LEFT JOIN (SELECT sale_id, SUM(amount) AS total_paid FROM {{prefix}}.sale_paid GROUP BY sale_id) AS payment_totals ON payment_totals.sale_id = sale.id
WHERE ($1::bigint IS NULL OR client.id < $1)
  AND (
    NULLIF($2::text, '') IS NULL
    OR client.name ILIKE '%' || $2 || '%'
    OR client.celphone ILIKE '%' || $2 || '%'
    OR client.document_id ILIKE '%' || $2 || '%'
    OR client.email ILIKE '%' || $2 || '%'
  )
GROUP BY client.id, client.name, client.document_id, client.address, client.celphone, client.email, client.date_create, client.wholesaler
ORDER BY client.id DESC
LIMIT $3;
