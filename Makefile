.PHONY: up down restart logs ps psql console init init-sql \
	generator logs-generator logs-redpanda gen-es view-client clean help

# Démarrer toute la stack (Redpanda, RisingWave, OpenSearch, MinIO, ...)
up:
	docker compose up -d

# Démarrer la stack (init SQL exécuté automatiquement) puis lancer le générateur
init:
	docker compose up -d
	docker compose --profile demo up -d generator
	@echo "Pipeline prêt. Voir : make console"

# Applique uniquement les scripts SQL (sources, MV, sinks) dans RisingWave
init-sql:
	docker compose run --rm risingwave-init

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f risingwave-standalone

logs-generator:
	docker compose logs -f generator

logs-redpanda:
	docker compose logs -f redpanda

ps:
	docker compose ps

psql:
	docker compose exec risingwave-standalone psql -h localhost -p 4566 -U root -d dev

# Démarre le générateur de données de démo
generator:
	docker compose --profile demo up -d generator

# Liste les index OpenSearch alimentés par les sinks
gen-es:
	@echo "=== Index OpenSearch ==="
	@curl -s http://localhost:9200/_cat/indices?v || echo "(OpenSearch non joignable)"

# Vue agrégée "360°" d'un client. Usage : make view-client ID=<id_client>
view-client:
	@[ -n "$(ID)" ] || (echo "Erreur : précisez l'ID du client : make view-client ID=4" ; exit 1)
	@echo "=== Client #$(ID) - vue 360° ==="
	@curl -s "http://localhost:9200/client_360/_search" -H 'Content-Type: application/json' \
		-d "{\"query\":{\"term\":{\"id_client\":$(ID)}}}" \
		| python3 -c "import sys,json; h=json.load(sys.stdin)['hits']['hits']; print(json.dumps(h[0]['_source'],ensure_ascii=False,indent=2) if h else 'Client #$(ID) introuvable')" \
		|| echo "(OpenSearch non joignable ou ID invalide)"

console:
	@echo "RisingWave Console      : http://localhost:8020 (root/root)"
	@echo "RisingWave Dashboard    : http://localhost:5691"
	@echo "Redpanda Console        : http://localhost:8082"
	@echo "OpenSearch Dashboards   : http://localhost:5601"
	@echo "OpenSearch (API)        : http://localhost:9200"
	@echo "MinIO                   : http://localhost:9400 (hummockadmin/hummockadmin)"

clean:
	docker compose down -v

help:
	@echo "Cibles disponibles :"
	@printf "  %-14s %s\n" "init" "Stack + SQL + générateur (tout-en-un)"
	@printf "  %-14s %s\n" "up" "Démarrer toute la stack"
	@printf "  %-14s %s\n" "init-sql" "Créer sources/MV/sinks dans RisingWave"
	@printf "  %-14s %s\n" "generator" "Lancer le générateur de données de démo"
	@printf "  %-14s %s\n" "psql" "Ouvrir un client psql sur RisingWave"
	@printf "  %-14s %s\n" "gen-es" "Lister les index OpenSearch"
	@printf "  %-14s %s\n" "view-client" "Vue 360° d'un client (make view-client ID=4)"
	@printf "  %-14s %s\n" "console" "Afficher les URLs des interfaces"
	@printf "  %-14s %s\n" "down" "Arrêter la stack"
	@printf "  %-14s %s\n" "clean" "Arrêter et supprimer volumes"
