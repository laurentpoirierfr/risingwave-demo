#!/usr/bin/env bash
# ============================================================
# 10-test-zinc.sh — PROTOTYPE RisingWave -> ZincSearch
# 1) exécute zinc-demo.sql (table + MV + sink elasticsearch)
# 2) vérifie que les docs ont bien atteint l'index ZincSearch
# Usage : ./10-test-zinc.sh
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

source ./_common.sh
need_cluster

SQL_FILE="${1:-zinc-demo.sql}"
[ -f "$SQL_FILE" ] || die "Fichier SQL introuvable : $SQL_FILE"

# Assure que ZincSearch est présent
kubectl -n zincsearch get deploy zincsearch >/dev/null 2>&1 \
  || die "ZincSearch absent. Lance ./09-deploy-zincsearch.sh"

POD="rw-zinc-$$"
cleanup() {
  kubectl -n "$DEPLOY_NS" delete pod "$POD" --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

info "Prototype RisingWave -> ZincSearch"
echo

info "1) Exécution de $SQL_FILE sur le frontend…"
kubectl -n "$DEPLOY_NS" run "$POD" \
  --image=postgres:15-alpine --restart=Never --rm -i --quiet \
  --command -- psql "postgresql://root@$RW_SVC_FRONTEND:4567/dev" \
  < "$SQL_FILE"

echo
info "2) Attente du flush du sink (5s)…"
sleep 6

info "3) Interrogation de l'index 'sinistres_par_type' dans ZincSearch…"
echo
kubectl -n zincsearch run "zinc-query-$$" \
  --image=curlimages/curl --restart=Never --rm -i --quiet \
  --command -- curl -sS -u admin:admin \
    -X POST "http://zincsearch.zincsearch:4080/es/sinistres_par_type/_search" \
    -H "Content-Type: application/json" \
    -d '{"search_type":"matchall","max_results":20}'
echo

ok "Prototype terminé — les agrégats ont été poussés vers ZincSearch."
note "UI ZincSearch : http://localhost:4080  (admin / admin)"
