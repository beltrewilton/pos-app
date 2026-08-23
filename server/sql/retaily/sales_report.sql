SELECT
  sale.id,
  sale.amount,
  sale.sub,
  sale.discount,
  sale.tax_amount,
  sale.delivery_charge,
  sale.sequence,
  sale.sequence_type,
  sale.status,
  sale.sale_type,
  sale.date_create,
  sale.login,
  sale.cancelled_by,
  sale.additional_info,
  sale.store_id,
  client.id AS client_id,
  client.name AS client_name,
  client.document_id AS client_document_id,
  COALESCE(payment_totals.total_paid, 0) AS total_paid,
  CASE
    WHEN sale.status = 'RETURN' THEN 0
    ELSE sale.amount - COALESCE(payment_totals.total_paid, 0)
  END AS due_balance,
  CASE
    WHEN sale.status = 'RETURN' THEN 'cancelled'
    WHEN sale.amount - COALESCE(payment_totals.total_paid, 0) > 0 THEN 'open'
    ELSE 'close'
  END AS invoice_status,
  COALESCE(line_totals.line_count, 0) AS line_count,
  COALESCE(line_totals.item_quantity, 0) AS item_quantity
FROM {{prefix}}.sale AS sale
LEFT JOIN {{prefix}}.client AS client ON client.id = sale.client_id
LEFT JOIN LATERAL (
  SELECT SUM(sale_paid.amount) AS total_paid
  FROM {{prefix}}.sale_paid AS sale_paid
  WHERE sale_paid.sale_id = sale.id
) AS payment_totals ON TRUE
LEFT JOIN LATERAL (
  SELECT
    COUNT(*) AS line_count,
    SUM(sale_line.quantity) AS item_quantity
  FROM {{prefix}}.sale_line AS sale_line
  WHERE sale_line.sale_id = sale.id
) AS line_totals ON TRUE
WHERE sale.store_id = $3
  AND ($1::bigint IS NULL OR sale.id < $1)
  AND (
    NULLIF($4::text, '') IS NULL
    OR client.name ILIKE '%' || $4 || '%'
  )
  AND ($5::date IS NULL OR sale.date_create >= $5::date)
  AND ($6::date IS NULL OR sale.date_create < $6::date + INTERVAL '1 day')
  AND (
    $7::text IS NULL
    OR CASE
      WHEN sale.status = 'RETURN' THEN 'cancelled'
      WHEN sale.amount - COALESCE(payment_totals.total_paid, 0) > 0 THEN 'open'
      ELSE 'close'
    END = $7
  )
ORDER BY sale.id DESC
LIMIT $2;
