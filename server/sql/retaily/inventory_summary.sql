WITH inventory AS (
  SELECT
    inventory.store_id,
    inventory.product_id,
    COALESCE(inventory.quantity, 0)::numeric AS quantity,
    COALESCE(product.cost, 0)::numeric AS cost
  FROM {{prefix}}.app_inventory AS inventory
  LEFT JOIN {{prefix}}.product AS product ON product.id = inventory.product_id
  WHERE inventory.store_id = $1
),
inventory_metrics AS (
  SELECT
    COALESCE(SUM(quantity * cost) FILTER (WHERE quantity > 0), 0) AS inventory_valuation,
    COUNT(*) FILTER (WHERE quantity < 0) AS negative_stock_sku_count,
    COALESCE(SUM(ABS(quantity)) FILTER (WHERE quantity < 0), 0) AS negative_stock_units,
    COALESCE(SUM(ABS(quantity) * cost) FILTER (WHERE quantity < 0), 0) AS negative_stock_value,
    COUNT(*) FILTER (WHERE quantity = 0) AS zero_stock_sku_count,
    COUNT(*) AS inventoried_sku_count,
    COALESCE(SUM(GREATEST(quantity, 0)) FILTER (WHERE cost <= 0), 0) AS uncosted_inventory_units,
    COUNT(*) FILTER (WHERE quantity > 0 AND cost <= 0) AS uncosted_inventory_sku_count
  FROM inventory
),
inventory_by_store AS (
  SELECT
    store.id AS store_id,
    store.name AS store_name,
    COALESCE(SUM(COALESCE(inventory.quantity, 0)::numeric * COALESCE(product.cost, 0)::numeric) FILTER (WHERE COALESCE(inventory.quantity, 0) > 0), 0) AS inventory_valuation
  FROM {{prefix}}.app_store AS store
  LEFT JOIN {{prefix}}.app_inventory AS inventory ON inventory.store_id = store.id
  LEFT JOIN {{prefix}}.product AS product ON product.id = inventory.product_id
  GROUP BY store.id, store.name
),
company_inventory_metrics AS (
  SELECT COALESCE(SUM(inventory_valuation), 0) AS company_inventory_valuation
  FROM inventory_by_store
),
sales AS (
  SELECT
    sale.id,
    sale.sale_type,
    sale.status,
    sale.login,
    sale.client_id,
    sale.amount::numeric AS amount,
    sale.discount::numeric AS discount,
    CASE WHEN sale.status = 'RETURN' OR sale.sale_type = 'RETURN' THEN -1 ELSE 1 END AS direction
  FROM {{prefix}}.sale AS sale
  WHERE sale.store_id = $1
    AND sale.date_create >= CURRENT_DATE - INTERVAL '30 days'
),
sales_metrics AS (
  SELECT
    COALESCE(SUM(direction * amount), 0) AS net_sales,
    COUNT(*) FILTER (WHERE direction = 1) AS sale_transaction_count,
    COALESCE(SUM(direction * discount), 0) AS net_discount,
    COALESCE(SUM(amount + discount) FILTER (WHERE direction = 1), 0) AS pre_discount_sales,
    COUNT(DISTINCT client_id) FILTER (WHERE direction = 1) AS purchasing_customer_count
  FROM sales
),
line_metrics AS (
  SELECT
    COALESCE(SUM(sales.direction * line.quantity), 0) AS net_units_sold
  FROM sales
  JOIN {{prefix}}.sale_line AS line ON line.sale_id = sales.id
),
product_velocity AS (
  SELECT
    line.product_id,
    COALESCE(product.name, 'Unknown product') AS product_name,
    COALESCE(SUM(sales.direction * line.quantity), 0) AS net_units,
    COALESCE(SUM(sales.direction * line.total_amount), 0) AS net_revenue
  FROM sales
  JOIN {{prefix}}.sale_line AS line ON line.sale_id = sales.id
  LEFT JOIN {{prefix}}.product AS product ON product.id = line.product_id
  GROUP BY line.product_id, product.name
),
customer_frequency AS (
  SELECT client_id, COUNT(*) AS purchases, SUM(amount) AS customer_value
  FROM sales
  WHERE direction = 1
  GROUP BY client_id
),
order_metrics AS (
  SELECT
    COUNT(*) FILTER (WHERE order_type = 'purchase' AND status IN ('closed', 'received')) AS closed_purchase_order_count,
    COUNT(*) FILTER (WHERE order_type = 'purchase' AND status NOT IN ('closed', 'received')) AS open_purchase_order_count,
    COUNT(*) FILTER (WHERE order_type = 'movement' AND status IN ('closed', 'received')) AS closed_transfer_count,
    COUNT(*) FILTER (WHERE order_type = 'movement' AND status NOT IN ('closed', 'received')) AS open_transfer_count,
    AVG(EXTRACT(EPOCH FROM (date_closed - date_opened)) / 3600.0) FILTER (WHERE status IN ('closed', 'received') AND date_closed IS NOT NULL) AS average_closed_order_hours
  FROM {{prefix}}.product_order
  WHERE to_store_id = $1 OR from_origin_id = $1
),
receiving_metrics AS (
  SELECT
    COALESCE(SUM(line.quantity), 0) AS ordered_units,
    COALESCE(SUM(line.quantity_observed), 0) AS observed_units
  FROM {{prefix}}.product_order_line AS line
  JOIN {{prefix}}.product_order AS product_order ON product_order.id = line.product_order_id
  WHERE product_order.to_store_id = $1 OR product_order.from_origin_id = $1
)
SELECT
  inventory_metrics.inventory_valuation,
  company_inventory_metrics.company_inventory_valuation,
  COALESCE((
    SELECT jsonb_agg(item ORDER BY item.store_name)
    FROM (
      SELECT store_id, store_name, inventory_valuation
      FROM inventory_by_store
    ) AS item
  ), '[]'::jsonb) AS inventory_valuation_by_store,
  inventory_metrics.negative_stock_sku_count,
  inventory_metrics.negative_stock_units,
  inventory_metrics.negative_stock_value,
  inventory_metrics.zero_stock_sku_count,
  inventory_metrics.inventoried_sku_count,
  CASE WHEN inventory_metrics.inventoried_sku_count = 0 THEN 0
       ELSE inventory_metrics.zero_stock_sku_count::numeric / inventory_metrics.inventoried_sku_count END AS zero_stock_rate,
  inventory_metrics.uncosted_inventory_units,
  inventory_metrics.uncosted_inventory_sku_count,
  sales_metrics.net_sales,
  sales_metrics.sale_transaction_count,
  CASE WHEN sales_metrics.sale_transaction_count = 0 THEN 0
       ELSE sales_metrics.net_sales / sales_metrics.sale_transaction_count END AS average_order_value,
  line_metrics.net_units_sold,
  CASE WHEN sales_metrics.sale_transaction_count = 0 THEN 0
       ELSE line_metrics.net_units_sold / sales_metrics.sale_transaction_count END AS units_per_order,
  sales_metrics.net_discount,
  CASE WHEN sales_metrics.pre_discount_sales = 0 THEN 0
       ELSE sales_metrics.net_discount / sales_metrics.pre_discount_sales END AS discount_rate,
  sales_metrics.purchasing_customer_count,
  COALESCE((SELECT COUNT(*) FROM customer_frequency WHERE purchases >= 2), 0) AS returning_customer_count,
  COALESCE((SELECT AVG(purchases) FROM customer_frequency), 0) AS average_purchase_frequency,
  COALESCE((SELECT AVG(customer_value) FROM customer_frequency), 0) AS average_customer_value,
  order_metrics.closed_purchase_order_count,
  order_metrics.open_purchase_order_count,
  order_metrics.closed_transfer_count,
  order_metrics.open_transfer_count,
  COALESCE(order_metrics.average_closed_order_hours, 0) AS average_closed_order_hours,
  receiving_metrics.ordered_units,
  receiving_metrics.observed_units,
  CASE WHEN receiving_metrics.ordered_units = 0 THEN 0
       ELSE receiving_metrics.observed_units / receiving_metrics.ordered_units END AS receiving_completion_rate,
  COALESCE((
    SELECT jsonb_agg(item ORDER BY item.net_revenue DESC)
    FROM (SELECT product_name, net_units, net_revenue FROM product_velocity ORDER BY net_revenue DESC LIMIT 3) AS item
  ), '[]'::jsonb) AS best_products,
  COALESCE((
    SELECT jsonb_agg(item ORDER BY item.net_units ASC)
    FROM (SELECT product_name, net_units, net_revenue FROM product_velocity WHERE net_units > 0 ORDER BY net_units ASC, net_revenue ASC LIMIT 3) AS item
  ), '[]'::jsonb) AS slowest_products,
  COALESCE((
    SELECT jsonb_agg(item ORDER BY item.net_sales DESC)
    FROM (
      SELECT sale_type, login, SUM(direction * amount) AS net_sales, COUNT(*) AS transaction_count
      FROM sales GROUP BY sale_type, login
    ) AS item
  ), '[]'::jsonb) AS sales_mix,
  COALESCE((
    SELECT jsonb_agg(item ORDER BY item.amount DESC)
    FROM (
      SELECT payment.type, SUM(payment.amount) AS amount
      FROM {{prefix}}.sale_paid AS payment
      JOIN sales ON sales.id = payment.sale_id
      WHERE sales.direction = 1
      GROUP BY payment.type
    ) AS item
  ), '[]'::jsonb) AS payment_method_mix
FROM inventory_metrics
CROSS JOIN company_inventory_metrics
CROSS JOIN sales_metrics
CROSS JOIN line_metrics
CROSS JOIN order_metrics
CROSS JOIN receiving_metrics;
