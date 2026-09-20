-- ============================================================
-- smoke-test.sql — vérification fonctionnelle de RisingWave
-- (sans source Kafka : on teste le moteur en pur SQL)
-- Idempotent : nettoie puis recrée les objets à chaque exécution.
-- ============================================================

-- 0. Version du moteur
SELECT version();

-- 1. Nettoyage (objets de l'exécution précédente, s'ils existent)
DROP MATERIALIZED VIEW IF EXISTS mv_total_par_client;
DROP TABLE IF EXISTS t_payments;

-- 2. Une table persistante (état sauvegardé dans MinIO)
CREATE TABLE t_payments (
    id        BIGINT PRIMARY KEY,
    client    VARCHAR,
    montant   DOUBLE PRECISION,
    statut    VARCHAR
);

-- 3. Quelques lignes
INSERT INTO t_payments VALUES
    (1, 'alice', 120.00, 'ok'),
    (2, 'bob',   250.50, 'ok'),
    (3, 'alice',  80.00, 'pending');

-- 4. Une materialized view incrémentale
CREATE MATERIALIZED VIEW mv_total_par_client AS
SELECT client, COUNT(*) AS nb, SUM(montant) AS total
FROM t_payments
GROUP BY client;

-- 5. Interroger la vue (fraîcheur)
SELECT * FROM mv_total_par_client ORDER BY client;

-- 6. Ajout supplémentaire -> la MV se met à jour toute seule
INSERT INTO t_payments VALUES (4, 'bob', 99.99, 'ok');
SELECT * FROM mv_total_par_client ORDER BY client;

-- 7. État du système
SHOW TABLES;
SHOW MATERIALIZED VIEWS;
