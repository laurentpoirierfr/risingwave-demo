-- ============================================================
-- zinc-demo.sql — PROTOTYPE : RisingWave -> ZincSearch
-- Démontre qu'un SINK RisingWave (connector elasticsearch) peut
-- pousser des agrégats vers ZincSearch (API compatible ES, /es).
-- ⚠️  DÉMO / PROTOTYPE : à des fins d'évaluation uniquement.
-- ============================================================

-- 1. Table "source" simulée (pas de Kafka : données en pur SQL)
DROP SINK IF EXISTS sink_zinc_par_type;
DROP MATERIALIZED VIEW IF EXISTS mv_zinc_par_type;
DROP TABLE IF EXISTS t_sinistres;

CREATE TABLE t_sinistres (
    id_sinistre   BIGINT PRIMARY KEY,
    type_sinistre VARCHAR,
    montant       DOUBLE PRECISION,
    statut        VARCHAR
);

INSERT INTO t_sinistres VALUES
    (1, 'COLLISION', 12000.00, 'indemnisé'),
    (2, 'INCENDIE',  85000.00, 'en cours'),
    (3, 'COLLISION', 3500.00,  'indemnisé'),
    (4, 'VOL',       20000.00, 'en cours'),
    (5, 'INCENDIE',  1200.00,  'indemnisé');

-- 2. Materialized view agrégée (incrémentale)
CREATE MATERIALIZED VIEW mv_zinc_par_type AS
SELECT
    type_sinistre,
    COUNT(*)                                AS nb_sinistres,
    COALESCE(SUM(montant), 0)               AS montant_indemnise_total
FROM t_sinistres
GROUP BY type_sinistre;

-- 3. Sink vers ZincSearch (chemin /es, API compatible Elasticsearch)
CREATE SINK sink_zinc_par_type
FROM mv_zinc_par_type
WITH (
    connector = 'elasticsearch',
    index     = 'sinistres_par_type',
    primary_key = 'type_sinistre',
    url       = 'http://zincsearch.zincsearch:4080/es',
    username  = 'admin',
    password  = 'admin'
);

-- 4. Donnée supplémentaire -> le sink fait suivre la MV incrémentale
INSERT INTO t_sinistres VALUES (6, 'COLLISION', 7000.00, 'indemnisé');

-- 5. Vérification locale de la MV
SELECT * FROM mv_zinc_par_type ORDER BY type_sinistre;
