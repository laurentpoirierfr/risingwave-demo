# RisingWave sur Kubernetes (k8s)

Ce dossier met en place des **scripts bash** pour tester RisingWave sur
**Minikube**, via une installation **Helm**, et évaluer concrètement la
**complexité de déploiement** sur Kubernetes.

> Périmètre volontairement réduit : **RisingWave uniquement**, avec son
> **object store S3 (MinIO)** et les **dashboards / observabilité** utiles.
> **Pas d'OpenSearch** ici — on se concentre sur le déploiement du moteur.
> Un **prototype opt-in** remplace OpenSearch par **ZincSearch** comme
> destination des sinks (voir plus bas).

---

## Flux d'utilisation (résumé)

```bash
cd k8s
./01-start-minikube.sh          # 1. démarre le cluster Minikube
./02-install-dashboards.sh      # 2. Prometheus + Grafana (observabilité)
./03-deploy-risingwave.sh       # 3. déploie RisingWave via Helm (bundle PG+MinIO)
./04-port-forward.sh            # 4. ouvre les port-forwards (SQL, dashboards, MinIO, Grafana)
./05-smoke-test.sh              # 5. smoke test : table + MV incrémentale en SQL pur
./06-verify-minio.sh            # 6. vérifie que l'object store S3 est bien utilisé
# Prototype (optionnel) :
./09-deploy-zincsearch.sh       # 7. déploie ZincSearch (sink léger)
./10-test-zinc.sh               # 8. test RisingWave → sink → ZincSearch
```

Nettoyage :

```bash
./07-cleanup.sh                 # désinstalle RisingWave + observabilité + ZincSearch
./08-stop-minikube.sh           # stop         (conserve les données)
./08-stop-minikube.sh delete    # suppression complète du cluster
```

---

## Prototype : RisingWave → ZincSearch (remplaçant OpenSearch)

> ⚠️ **STATUT : TEST / PROTOTYPE.** Cette intégration vise à **évaluer** si
> ZincSearch peut remplacer OpenSearch comme destination des **sinks**
> RisingWave, avec un déploiement bien plus léger (un seul binaire Go,
> pas de JVM). **Non destiné à la production** : un seul pod, PVC local,
> pas de HA, pas de TLS.

**ZincSearch** est un moteur de recherche full-text open source écrit en **Go**,
alternative légère à Elasticsearch/OpenSearch. Il expose une **API compatible
Elasticsearch** (sous le chemin `/es`), ce qui permet de brancher un sink
RisingWave de type `elasticsearch` dessus **sans changer de connecteur**.

### Déploiement (prototype)

```bash
./09-deploy-zincsearch.sh     # applique zincsearch.yaml (1 pod + PVC + svc)
./04-port-forward.sh          # inclut ZincSearch sur localhost:4080
# UI : http://localhost:4080  (admin / admin)
```

### Tester le pipeline RisingWave → ZincSearch

```bash
./10-test-zinc.sh             # exécute zinc-demo.sql puis interroge l'index
```

Ce script :
1. crée une table, une **materialized view** agrégée et un **sink**
   (`connector = 'elasticsearch'`) pointant vers `zincsearch.zincsearch:4080/es` ;
2. insère des données → la MV se met à jour → le sink flush vers ZincSearch ;
3. interroge l'index `sinistres_par_type` via l'API ZincSearch pour confirmer
   que les agrégats sont bien arrivés.

> Détail réseau : les pods RisingWave vivent dans `risingwave`, ZincSearch dans
> `zincsearch`. On utilise donc le nom **qualifié** `zincsearch.zincsearch`
> (service.namespace) dans l'URL du sink.

**Fichiers** : `zincsearch.yaml` (manifest), `zinc-demo.sql`, `09-deploy-*`,
`10-test-*`. Le nettoyage de ZincSearch est inclus dans `./07-cleanup.sh`.

---

## Les scripts

| Script | Rôle |
| --- | --- |
| `01-start-minikube.sh` | Démarre Minikube (driver docker, 6 CPU / 10 Gi). |
| `02-install-dashboards.sh` | Installe `kube-prometheus-stack` : Prometheus + Grafana. |
| `03-deploy-risingwave.sh` | `helm install` du chart officiel, values `values.yaml`. |
| `04-port-forward.sh` | Port-forwards locaux vers les interfaces (SQL, dashboards…). |
| `05-smoke-test.sh` | Vérifie le moteur en SQL pur (via un pod `postgres-client`). |
| `06-verify-minio.sh` | Liste buckets/objets de l'object store S3 (MinIO). |
| `07-cleanup.sh` | Désinstalle RisingWave + observabilité + ZincSearch. |
| `08-stop-minikube.sh` | Arrête ou supprime le cluster Minikube. |
| `09-deploy-zincsearch.sh` | Déploie ZincSearch (prototype, destination sink). |
| `10-test-zinc.sh` | Teste le pipeline RisingWave → sink → ZincSearch. |
| `_common.sh` | Fonctions partagées (noms, attentes, port-forwards). |
| `values.yaml` | Values Helm du déploiement RisingWave. |
| `smoke-test.sql` | Requêtes de validation du moteur. |
| `zincsearch.yaml` | Manifest k8s ZincSearch (prototype). |
| `zinc-demo.sql` | SQL du prototype RisingWave → ZincSearch. |

---

## Ce que le déploiement met en place

Le chart `risingwavelabs/risingwave` (mode **distribué**) crée les 4 rôles
séparés + les stores partagés, **en bundle** pour un démarrage rapide :

| Composant | Rôle | Note |
| --- | --- | --- |
| **Meta node** | coordination, métadonnées | meta store = **PostgreSQL** (bundle) |
| **Compute node** | traitement du flux | state store sur l'object store |
| **Frontend node** | interface PostgreSQL (port 4567) | on s'y connecte comme à une base |
| **Compactor node** | compaction de l'état | écrit sur MinIO |
| **MinIO** | object store **S3-compatible** | state store `risingwave-state` |
| **PostgreSQL** | meta store | métadonnées du cluster |

L'observabilité (`kube-prometheus-stack`) fournit **Prometheus** (métriques
d'état/cpu/mémoire de RisingWave) et **Grafana** (visualisation).

---

## Interfaces (port-forwards)

Lancés par `./04-port-forward.sh` :

| Interface | URL locale | Identifiant |
| --- | --- | --- |
| RisingWave SQL (psql) | `localhost:4567` | `root` (base `dev`) |
| RisingWave Dashboard | [`http://localhost:5691`](http://localhost:5691) | — |
| MinIO Console | [`http://localhost:9001`](http://localhost:9001) | `hummockadmin` / `hummockadmin` |
| MinIO API (S3) | `localhost:9000` | idem |
| Grafana | [`http://localhost:3000`](http://localhost:3000) | `admin` / `admin` |
| ZincSearch (proto) | [`http://localhost:4080`](http://localhost:4080) | `admin` / `admin` |

Connexion psql :

```bash
psql -h localhost -p 4567 -U root -d dev
```

> Si `psql` n'est pas installé sur la machine, `smoke-test.sh` s'y connecte
> depuis un pod dans le cluster — aucun client local requis.

---

## Observation de la complexité de déploiement

Ce périmètre (RisingWave + S3/MinIO + dashboards, via Helm) tient en
**3 commandes d'installation** (`01`, `02`, `03`) : le chart bundle
PostgreSQL et MinIO, ce qui évite de provisionner soi-même le méta-store
et le state-store.

Ce qui reste quand même à maîtriser sur k8s (pour aller plus loin) :
- **dimensionnement** : cpu/mémoire des 4 nodes (dans `values.yaml`) ;
- **persistance** : `PersistentVolumeClaim` MinIO (le state store) ;
- **observabilité** : scraping Prometheus des métriques des nodes ;
- **exposition** : service du frontend (`service.type`, NodePort/LoadBalancer)
  pour un accès hors port-forward.

→ **Verdict attendu** : le "bootsrap" est simple grâce au bundle Helm ; la
complexité réelle apparaît dès qu'on veut du **scale-out** (plusieurs
replica de compute), de la **persistance durable** et de la **sécurité**
(creds S3, TLS) en production.

---

## Variables d'environnement

| Variable | Défaut | Rôle |
| --- | --- | --- |
| `CPUS` | `6` | CPU du cluster minikube |
| `MEMORY` | `10g` | Mémoire du cluster minikube |
| `DISK` | `30000mb` | Disque du cluster minikube |
| `DRIVER` | `docker` | Driver minikube |
| `DEPLOY_NS` | `risingwave` | Namespace RisingWave |
| `RW_RELEASE` | `my-risingwave` | Nom du release Helm |
| `MONITOR_RELEASE` | `obs` | Release kube-prometheus-stack |
| `MONITOR_NS` | `monitoring` | Namespace observabilité |

---

## Ressources

- Chart Helm : <https://github.com/risingwavelabs/helm-charts>
- Documentation k8s : <https://docs.risingwave.com/deploy/risingwave-kubernetes>
- MinIO : <https://min.io>
