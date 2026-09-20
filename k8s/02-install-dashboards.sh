#!/usr/bin/env bash
# ============================================================
# 02-install-dashboards.sh
# Installe l'observabilité : Prometheus + Grafana
# via le stack kube-prometheus-stack (helm).
# (OpenSearch est volontairement exclu de ce périmètre.)
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

source ./_common.sh
need_cluster

require helm

HELM_REPO=prometheus-community

info "Ajout / mise à jour du repo helm $HELM_REPO…"
helm repo add "$HELM_REPO" https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null

if helm status "$MONITOR_RELEASE" -n "$MONITOR_NS" >/dev/null 2>&1; then
  ok "Stack d'observabilité déjà installée ($MONITOR_RELEASE/$MONITOR_NS)."
  exit 0
fi

info "Création du namespace $MONITOR_NS…"
kubectl create namespace "$MONITOR_NS" 2>/dev/null || true

info "Installation de kube-prometheus-stack ($MONITOR_RELEASE)…"
helm install "$MONITOR_RELEASE" "$HELM_REPO/kube-prometheus-stack" \
  --namespace "$MONITOR_NS" \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --wait

ok "Observabilité installée : Prometheus + Grafana."
note "Accès : voir ./04-port-forward.sh"
