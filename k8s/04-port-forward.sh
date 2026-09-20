#!/usr/bin/env bash
# ============================================================
# 04-port-forward.sh
# Ouvre des port-forwards locaux vers les interfaces utiles :
#   - RisingWave (SQL / psql)         4567
#   - RisingWave Dashboard (métriques) 5691
#   - MinIO console (object store)     9001
#   - MinIO API (S3)                   9000
#   - Grafana (observabilité)          3000
# Usage : ./04-port-forward.sh          (Ctrl+C pour arrêter)
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

source ./_common.sh
need_cluster

# ---- Stopper d'éventuels anciens forwards -------------------
note "Ports libérés : arrêt des forwards précédents (kubectl port-forward)."
pkill -f "kubectl .*port-forward" 2>/dev/null || true
sleep 1

info "Ouverture des port-forwards. Ctrl+C pour tout arrêter."
echo

pf "$DEPLOY_NS" "$RW_SVC_FRONTEND"   "4567" "RisingWave SQL (psql)"
pf "$DEPLOY_NS" "$RW_SVC_META"       "5691" "RisingWave Dashboard"
pf "$DEPLOY_NS" "$RW_SVC_MINIO"      "9000" "MinIO API (S3)"
pf "$DEPLOY_NS" "$RW_SVC_MINIO"      "9001" "MinIO Console"
pf "$MONITOR_NS" "${MONITOR_RELEASE}-grafana" "3000" "Grafana"
pf "zincsearch" "zincsearch"         "4080" "ZincSearch (UI + API)"

echo
note "Identifiants par défaut :"
note "  RisingWave SQL : psql -h localhost -p 4567 -U root -d dev"
note "  MinIO          : hummockadmin / hummockadmin"
note "  Grafana        : admin / admin"
echo

trap 'kill_pf' INT TERM EXIT
wait
