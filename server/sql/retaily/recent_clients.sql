SELECT
  client.id,
  client.name,
  client.document_id,
  client.address,
  client.celphone,
  client.email,
  client.date_create,
  client.wholesaler
FROM {{prefix}}.client AS client
WHERE ($1::bigint IS NULL OR client.id < $1)
  AND (
    NULLIF($2::text, '') IS NULL
    OR client.name ILIKE '%' || $2 || '%'
    OR client.celphone ILIKE '%' || $2 || '%'
  )
ORDER BY client.id DESC
LIMIT $3;
