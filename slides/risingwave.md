---
marp: true
theme: risingwave
paginate: true
---

<!-- _class: cover -->

# RisingWave
### Traitement de flux (streaming) réinventé

Deux ou trois `CREATE` et le pipeline temps réel est en place — un pipeline **déclaratif**, **versionnable** et **auditable**, sans la complexité des moteurs traditionnels.

---

<!-- _class: lead -->

## Le problème

Le streaming temps réel est **puissant**, mais il reste encore **difficile à adopter** pour la plupart des équipes. Les moteurs de streaming actuels sont techniquement impressionnants, mais ils sont complexes à **déployer**, à **opérer** et à **apprendre** — un investissement lourd qui rebute souvent ceux qui ne veulent pas devenir des data engineers spécialisés.

> Les moteurs de streaming actuels sont puissants, mais complexes à déployer, opérer et apprendre.

Ce qu'on recherche, en réalité, c'est d'obtenir des résultats **en temps réel** sans devoir maîtriser toute la panoplie des outils traditionnels de la classe "data engineering".

---

## Apache Flink : la référence, et ses limites

Flink a longtemps dominé le paysage du streaming. C'est un moteur **puissant et éprouvé**, qui offre **les deux mondes** : une API impérative (DataStream en Java/Scala) **et** une API SQL déclarative (Flink SQL). Bien que ce modèle soit riche, il n'est pas exempt de limites structurelles.

- **Orienté "jobs"** : on soumet des *jobs* qui possèdent leur propre état et leur propre cycle de vie — et cet état n'est pas interrogeable comme le serait une table durable.
- **Double API** : le code SQL et le code impératif coexistent dans le même écosystème, et en réalité le SQL déclaratif est souvent délaissé au profit de la DataStream API impérative.
- **Complexité opérationnelle** : il faut déployer et maintenir des clusters dédiés, gérer les checkpoints et l'état, et redéployer le job à chaque évolution de la logique.
- **Apprentissage abrupt** : windowing, watermarks, stateful processing, exactly-once… autant de concepts à maîtriser explicitement avant de pouvoir être productif.

> En un mot, Flink est un **moteur de jobs**. RisingWave, lui, se présente comme une **base de données** : l'état y est persistant, continu et **interrogeable**.

---

## La réponse : le déclaratif par défaut

Le déclaratif n'est pas l'apanage de RisingWave — **Flink a aussi du SQL**.
Ce qui change, c'est que RisingWave l'érige en **seul** langage et l'inscrit
dans un modèle de **base de données** :

| | Moteur orienté "jobs" | Base de données streaming |
|---|---|---|
| | (Flink SQL / DataStream coexistants) | (RisingWave) |
| **Unité de travail** | un job à soumettre | une vue / une requête |
| **État** | propre au job, à gérer | **persistant, interrogeable** |
| **Ce qu'on écrit** | mix SQL + code impératif | **100 % SQL** |
| **Interroger le résultat** | non trivial | **oui, comme une table** |
| **Évolution** | redéploiement du job | `CREATE OR REPLACE` |

Le moteur garantit l'**itération incrémentale** : dès qu'une nouvelle donnée arrive, la view matérialisée se met à jour **automatiquement**, sans intervention manuelle — et reste **interrogeable en continu** à tout moment, exactement comme une table classique.

---

## SQL : le langage d'interaction

Flink propose lui aussi du SQL, mais chez RisingWave le SQL est **le** langage unique, et le résultat de chaque requête reste **interrogeable comme une table** — ce n'est pas un artefact de job qu'il faut exporter pour pouvoir le consulter.

```sql
-- Même requête que sur une table, mais en temps réel
CREATE MATERIALIZED VIEW mv_sinistres_par_type AS
SELECT
    type_sinistre,
    COUNT(*)                                AS nb_sinistres,
    COALESCE(SUM(montant_indemnisation), 0) AS montant_indemnise_total
FROM src_claims
GROUP BY type_sinistre;
```

```sql
-- … et on peut interroger le résultat à tout moment
SELECT * FROM mv_sinistres_par_type WHERE nb_sinistres > 5;
```

- Une **seule syntaxe** sert à la fois pour les sources, les transformations et les sinks — rien d'autre à apprendre.
- Les **materialized views** restent à jour **en continu**, sans cesser d'être disponibles à la lecture.
- L'état agrégé est **interrogeable à la volée**, comme on interrogerait un entrepôt de données classique.

---

## La CLI / l'interaction : comme une vraie base

RisingWave se pilote **exactement comme une instance PostgreSQL**, avec le même réflexe et les mêmes commandes familières.

```
$ psql -h localhost -p 4566 -U root -d dev
dev=> CREATE SOURCE src_claims (...) WITH (...) FORMAT AVRO ENCODE AVRO;
dev=> CREATE MATERIALIZED VIEW ... ;
dev=> SELECT * FROM mv_sinistres_par_type;
   type_sinistre   | nb_sinistres | montant_indemnise_total
-------------------+--------------+--------------------------
 COLLISION         |           14 |               102340.00
 INCENDIE          |            6 |               390451.20
```

- Les interfaces sont **familières** : `psql`, drivers JDBC/ODBC, outils de BI... tout l'existant PostgreSQL fonctionne tel quel.
- On parle à RisingWave **exactement comme on parlerait à une base SQL** — pas de nouveau SDK ni de langage propriétaire à apprendre.

---

## Exposer le moteur : l'interface PostgreSQL

RisingWave se présente et se connecte comme **une instance PostgreSQL classique** — port `4566`, protocole wire PostgreSQL complet.

**Pourquoi c'est une idée forte :**

- **Adoption immédiate** : tout l'outillage PostgreSQL existant fonctionne sans aucune modification — psql, GraphQL, outils de BI, ORMs, et bien d'autres.
- **Courbe d'apprentissage minimale** : pas de nouveau SDK ni de langage à découvrir ; on reste dans des pratiques déjà connues de toute l'équipe.
- **Interopérabilité** : le streaming devient "juste une base" qui se met à jour toute seule, en continu, sans que le moteur sous-jacent n'ait besoin d'être visible.

> En substance, le streaming est **abstrait derrière un standard universel** : le SQL et le protocole PostgreSQL. **Le moteur** lui-même reste invisible.

---

## Démonstration : le pipeline en SQL pur

L'intégralité d'un pipeline de streaming peut tenir **en quelques instructions SQL seulement** — c'est toute la puissance de l'approche déclarative :

```sql
-- 1. Ingest : une source Kafka-compatible (Redpanda)
CREATE SOURCE src_payments (...) WITH (connector='kafka', topic='insurance.payments') ...;

-- 2. Transform : une vue incrémentale toujours à jour
CREATE MATERIALIZED VIEW mv_paiements_par_jour AS
  SELECT CAST(date_paiement AS DATE) AS jour, SUM(montant) AS total
  FROM src_payments GROUP BY CAST(date_paiement AS DATE);

-- 3. Output : un sink vers OpenSearch
CREATE SINK sink_paiements_par_jour FROM mv_paiements_par_jour
  WITH (connector='elasticsearch', index='paiements_par_jour', ...);
```

Deux ou trois `CREATE` suffisent pour mettre en place un pipeline temps réel complet — un pipeline **déclaratif**, **versionnable** et **auditable**, exactement comme on versionnerait le schéma d'une base de données classique.

---

## Déclaratif + temps réel : la promesse

- **La productivité d'une requête SQL**, combinée à la **fraîcheur du streaming** : le meilleur des deux mondes.
- Les **materialized views** gèrent l'incrément en interne — vous ne gérez plus ni états ni checkpoints.
- **Évolutif** : un scale-out horizontal est possible sans jamais réécrire vos requêtes.
- **Sobre en ressources** : par défaut en *in-memory* state (sans RocksDB), avec un footprint mémoire/CPU nettement plus léger qu'un cluster Flink + JVM ; on peut le faire tourner sur un seul nœud modeste.
- Déploiement **simple** : un seul binaire `standalone` ou un cluster, là où Flink exige tout un bundle distribué à orchestrer.

---

## En résumé : Flink vs RisingWave

| | Apache Flink | RisingWave |
|---|---|---|
| **Langage** | SQL **et** DataStream (Java/Scala) | **100 % SQL** |
| **Unités** | jobs, states, checkpoints | vues, sources, sinks |
| **Modèle** | moteur de traitement (jobs) | **base de données streaming** |
| **État** | interne à chaque job | **persistant + interrogeable** |
| **Interaction** | backend / SDK | **Protocole PostgreSQL** (`psql`) |
| **Opération** | cluster de jobs à tuner | service / base simple |
| **Ressources** | JVM + RocksDB, à dimensionner | **léger**, souvent 1 nœud modeste |

---

<!-- _class: lead -->

## À retenir

1. Le streaming temps réel **n'a pas à être compliqué** — il peut être aussi simple qu'une requête SQL.
2. Flink est solide mais profondément orienté **jobs** ; RisingWave, lui, se pense comme une **base**.
3. Le **SQL**, déclaratif par nature, s'impose comme le langage d'interaction universel du streaming.
4. **Exposer le moteur en PostgreSQL** le rend instantanément familier pour toutes les équipes.

> *Le streaming ne devrait pas ressembler à un cluster qu'on opère avec peine, mais à une **base de données** qu'on interroge simplement.*

---

<!-- _class: lead -->

# Merci

### Des questions ?
