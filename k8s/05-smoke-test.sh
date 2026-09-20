#!/usr/bin/env bash
# ============================================================
# 05-smoke-test.sh
# Vérifie le bon fonctionnement de RisingWave en pur SQL :
# table + insert + materialized view incrémentale + requêtes.
# S'exécute dans le cluster (pod postgres-client) — pas besoin
# de psql sur la machine hôte.
# Usage : ./05-smoke-test.sh [fichier.sql]
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

source ./_common.sh
need_cluster

SQL_FILE="${1:-smoke-test.sql}"
[ -f "$SQL_FILE" ] || die "Fichier SQL introuvable : $SQL_FILE"

POD="rw-smoke-$$"

cleanup() { kubectl -n "$DEPLOY_NS" delete pod "$POD" --ignore-not-found >/dev/null 2>&1 || true; }
trap cleanup EXIT

info "Smoke test : lecture de $SQL_FILE sur le frontend (pod $POD)…"
kubectl -n "$DEPLOY_NS" run "$POD" \
  --image=postgres:15-alpine --restart=Never --rm -i --quiet \
  --command -- psql "postgresql://root@$RW_SVC_FRONTEND:4567/dev" \
  < "$SQL_FILE"

ok "Smoke test terminé."
