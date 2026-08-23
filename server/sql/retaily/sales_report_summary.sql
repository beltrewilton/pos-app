WITH invoice_totals AS (
  SELECT
    sale.id,
    sale.amount,
    sale.status,
    COALESCE(SUM(sale_paid.amount), 0) AS total_paid
  FROM {{prefix}}.sale AS sale
  LEFT JOIN {{prefix}}.sale_paid AS sale_paid ON sale_paid.sale_id = sale.id
  LEFT JOIN {{prefix}}.client AS client ON client.id = sale.client_id
  WHERE sale.store_id = $1
    AND (
      NULLIF($2::text, '') IS NULL
      OR client.name ILIKE '%' || $2 || '%'
    )
    AND ($3::date IS NULL OR sale.date_create >= $3::date)
    AND ($4::date IS NULL OR sale.date_create < $4::date + INTERVAL '1 day')
  GROUP BY sale.id, sale.amount, sale.status
), invoices AS (
  SELECT
    amount,
    CASE
      WHEN status = 'RETURN' THEN 'cancelled'
      WHEN amount - total_paid > 0 THEN 'open'
      ELSE 'close'
    END AS invoice_status
  FROM invoice_totals
)
SELECT
  COUNT(*) FILTER (WHERE invoice_status = 'close') AS paid_count,
  COALESCE(SUM(amount) FILTER (WHERE invoice_status = 'close'), 0) AS paid_total,
  COUNT(*) FILTER (WHERE invoice_status = 'open') AS pending_count,
  COALESCE(SUM(amount) FILTER (WHERE invoice_status = 'open'), 0) AS pending_total,
  COUNT(*) FILTER (WHERE invoice_status = 'cancelled') AS cancelled_count,
  COALESCE(SUM(amount) FILTER (WHERE invoice_status = 'cancelled'), 0) AS cancelled_total
FROM invoices;
