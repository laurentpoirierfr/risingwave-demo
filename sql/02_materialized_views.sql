-- ============================================================
-- 02_materialized_views.sql
-- Vues matérialisées pour l'exemple `orders`
-- - agrégation des lignes de commande en tableau JSONB
-- - mise en forme du customer depuis topic customers
-- - jointure pour produire un document `order_360`
-- ============================================================

-- Agrège les lignes de commande par order_id en un tableau JSONB
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_order_items AS
SELECT
    order_id,
    jsonb_agg(item) AS items
FROM src_order_lines
GROUP BY order_id;

-- Transforme les enregistrements clients en objet JSONB utilisable
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_customers_json AS
SELECT
    customer_id,
    jsonb_build_object(
        'customer_id', customer_id,
        'name', name,
        'tier', tier,
        'shipping_address', shipping_address
    ) AS customer
FROM src_order_clients;

-- Vue 360° de la commande : propriétés racine depuis src_orders,
-- customer enrichi via join sur customer_id, items agrégés via mv_order_items
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_order_360 AS
SELECT
    o.order_id,
    o.status,
    o.created_at,
    -- preferer le customer provenant du topic customers s'il existe,
    -- sinon conserver celui embarqué dans src_orders
    COALESCE(c.customer, o.customer) AS customer,
    COALESCE(it.items, '[]'::JSONB) AS items,
    o.payment_summary
FROM src_orders o
LEFT JOIN mv_customers_json c ON (o.customer->> 'customer_id') = c.customer_id
LEFT JOIN mv_order_items it ON it.order_id = o.order_id;

-- Exemples d'agrégats simples
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_orders_par_status AS
SELECT status, COUNT(*) AS nb_orders, SUM((payment_summary->> 'total_amount')::DOUBLE PRECISION) AS total_amount
FROM src_orders
GROUP BY status;
