#!/usr/bin/env bash
# ============================================================
# 07-cleanup.sh
# Désinstalle RisingWave + l'observabilité du cluster.
# (Conserve le cluster minikube ; voir 08-stop-minikube.sh)
# Usage : ./07-cleanup.sh
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

source ./_common.sh
need_cluster

require helm

# 1. RisingWave
if helm status "$RW_RELEASE" -n "$DEPLOY_NS" >/dev/null 2>&1; then
  info "Désinstallation de RisingWave ($RW_RELEASE)…"
  helm uninstall "$RW_RELEASE" -n "$DEPLOY_NS" >/dev/null
fi
kubectl delete namespace "$DEPLOY_NS" --ignore-not-found >/dev/null 2>&1 \
  && ok "Namespace $DEPLOY_NS supprimé"

# 2. Observabilité
if helm status "$MONITOR_RELEASE" -n "$MONITOR_NS" >/dev/null 2>&1; then
  info "Désinstallation de l'observabilité ($MONITOR_RELEASE)…"
  helm uninstall "$MONITOR_RELEASE" -n "$MONITOR_NS" >/dev/null
fi
kubectl delete namespace "$MONITOR_NS" --ignore-not-found >/dev/null 2>&1 \
  && ok "Namespace $MONITOR_NS supprimé"

# 3. ZincSearch (démo/prototype)
kubectl delete namespace "zincsearch" --ignore-not-found >/dev/null 2>&1 \
  && ok "Namespace zincsearch supprimé"

ok "Nettoyage terminé. (Le cluster minikube tourne toujours.)"
