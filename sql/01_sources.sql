-- ============================================================
-- 01_sources.sql
-- Sources RisingWave -> Redpanda (Kafka-compatible)
-- Chaque concept métier arrive dans un topic dédié.
-- ============================================================

-- (Ancien exemple 'insurance' supprimé. Le fichier contient maintenant
-- uniquement les sources liées à l'exemple 'orders'.)

-- ============================================================
-- Sources pour l'exemple commandes (orders)
-- Trois topics : orders.clients, orders.lines, orders.commands
-- ============================================================

-- Clients (métadonnées)
CREATE SOURCE IF NOT EXISTS src_order_clients (
    customer_id      VARCHAR,
    name             VARCHAR,
    tier             VARCHAR,
    shipping_address JSONB
) WITH (
    connector = 'kafka',
    topic = 'orders.clients',
    properties.bootstrap.server = 'redpanda:29092',
    scan.startup.mode = 'earliest'
) FORMAT PLAIN ENCODE JSON;

-- Lignes de commande (une ligne par message, contient order_id et item)
CREATE SOURCE IF NOT EXISTS src_order_lines (
    order_id         VARCHAR,
    item             JSONB
) WITH (
    connector = 'kafka',
    topic = 'orders.lines',
    properties.bootstrap.server = 'redpanda:29092',
    scan.startup.mode = 'earliest'
) FORMAT PLAIN ENCODE JSON;

-- Commandes (document racine JSON)
CREATE SOURCE IF NOT EXISTS src_orders (
    order_id         VARCHAR,
    status           VARCHAR,
    created_at       TIMESTAMP,
    customer         JSONB,
    items            JSONB,
    payment_summary  JSONB
) WITH (
    connector = 'kafka',
    topic = 'orders.commands',
    properties.bootstrap.server = 'redpanda:29092',
    scan.startup.mode = 'earliest'
) FORMAT PLAIN ENCODE JSON;
