---
marp: true
theme: risingwave
paginate: true
---

<!-- _class: cover -->

# Démo : Pipeline "orders"
### Redpanda → RisingWave → OpenSearch

Scénario simple montrant l'ingestion d'ordres JSON, leur modélisation SQL
et l'export des agrégats vers OpenSearch.

---

<!-- _class: lead -->

## Objectif de la démo

- Simuler des commandes (`orders`) publiées dans 3 topics Kafka
- Ingestion dans RisingWave via `CREATE SOURCE`
- Construire des vues matérialisées (JSON imbriqué + agrégats)
- Indexer les résultats dans OpenSearch via `CREATE SINK`

---

## Prototype JSON (exemple)

```json
{
  "order_id": "ORD-2026-8942",
  "status": "COMPLETED",
  "created_at": "2026-09-20T08:30:00Z",
  "customer": { /* ... */ },
  "items": [ /* ... */ ],
  "payment_summary": { /* ... */ }
}
```

---

## Mapping Topics → Sources → Requêtes

- Racine (order_id, status, payment_summary)
  - Topic: `orders.commands` → Source: `src_orders`
  - Stocker propriétés directes en colonnes

- Objet imbriqué (customer, shipping_address)
  - Topic: `orders.clients` → Source: `src_order_clients`
  - Construire `customer` JSONB via `jsonb_build_object(...)`

- Collection (items)
  - Topic: `orders.lines` → Source: `src_order_lines`
  - Agréger avec `jsonb_agg(item)` GROUP BY `order_id`

---

## Flux SQL (haute-niveau)

1. `CREATE SOURCE` pour les 3 topics (`src_orders`, `src_order_clients`, `src_order_lines`)
2. `CREATE MATERIALIZED VIEW mv_order_items AS SELECT order_id, jsonb_agg(item) ...` 
3. `CREATE MATERIALIZED VIEW mv_customers_json AS SELECT customer_id, jsonb_build_object(...)`
4. `CREATE MATERIALIZED VIEW mv_order_360 AS SELECT o.*, COALESCE(c.customer,o.customer) ...` 
5. `CREATE SINK FROM mv_order_360` → index `orders_360`

---

## Architecture (schéma)

```
Generator (Go) -> Redpanda topics (orders.*)
      |                        
      v                        
RisingWave (CREATE SOURCE) -> Materialized Views -> CREATE SINK -> OpenSearch
```

---

## Commandes rapides pour lancer la démo

```bash
# Démarrer la stack (Redpanda, RisingWave, OpenSearch, ...)
docker compose up -d

# Appliquer les scripts SQL (sources / MVs / sinks)
# (risingwave-init le fait automatiquement dans docker-compose)
./scripts/init_rw.sh

# Construire/exécuter le générateur
cd generator && docker build -t orders-generator .
docker compose up --build generator
```

---

## Vérification / Debug

- Lister les topics : `docker compose exec redpanda rpk topic list`
- Voir des messages : Redpanda Console http://localhost:8082
- Interroger RisingWave (psql) : `psql -h localhost -p 4566 -U root -d dev`
  - `SELECT * FROM mv_order_360 LIMIT 10;`
- Vérifier indices OpenSearch : http://localhost:9200/_cat/indices?v

---

## Points pédagogiques

- Séparer la source de données (topic) et la représentation SQL
- Utiliser `jsonb` pour objets imbriqués et `jsonb_agg` pour collections
- Construire un document 360° via LEFT JOIN de petites vues agrégées
- RisingWave expose un modèle déclaratif (SQL) simple à intégrer

---

# Fin — Questions ?

Merci.
