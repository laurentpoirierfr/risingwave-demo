#!/usr/bin/env bash
# ============================================================
# 08-stop-minikube.sh
# Arrête (ou supprime) le cluster minikube.
# Usage : ./08-stop-minikube.sh [stop|delete]
#   stop   (défaut) : arrête le cluster (conserve les données)
#   delete          : supprime le cluster et ses données
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

source ./_common.sh

ACTION="${1:-stop}"
require minikube

case "$ACTION" in
  stop)
    info "Arrêt de minikube (données conservées)…"
    minikube stop
    ;;
  delete)
    warn "Suppression définitive du cluster minikube (données perdues)…"
    minikube delete --all
    ;;
  *)
    die "Action inconnue : $ACTION (attendu : stop|delete)"
    ;;
esac

ok "minikube : $ACTION terminé."
