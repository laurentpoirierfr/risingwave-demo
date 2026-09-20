-- ============================================================
-- 03_sinks.sql
-- Sinks RisingWave -> OpenSearch (API Bulk compatible Elasticsearch)
-- Chaque agrégat est indexé dans un index dédié.
-- ============================================================

-- ============================================================
-- Sinks pour l'exemple `orders` vers OpenSearch
-- ============================================================

-- Sink : document enrichi par commande (order_360)
CREATE SINK IF NOT EXISTS sink_order_360
FROM mv_order_360
WITH (
    connector = 'elasticsearch',
    index = 'orders_360',
    primary_key = 'order_id',
    url = 'http://opensearch:9200'
);

-- Sink : agrégat simple par statut
CREATE SINK IF NOT EXISTS sink_orders_par_status
FROM mv_orders_par_status
WITH (
    connector = 'elasticsearch',
    index = 'orders_par_status',
    primary_key = 'status',
    url = 'http://opensearch:9200'
);
