#!/usr/bin/env bash
# ============================================================
# 03-deploy-risingwave.sh
# Déploie RisingWave sur le cluster via le chart helm officiel,
# avec les dépendances groupées : PostgreSQL (meta) + MinIO (state).
# Usage : ./03-deploy-risingwave.sh
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

source ./_common.sh
need_cluster

require helm

REPO=risingwavelabs
CHART=risingwave
VALUES=./values.yaml

info "Ajout / mise à jour du repo helm $REPO…"
helm repo add "$REPO" https://risingwavelabs.github.io/helm-charts/ >/dev/null 2>&1 || true
helm repo update >/dev/null

if helm status "$RW_RELEASE" -n "$DEPLOY_NS" >/dev/null 2>&1; then
  warn "$RW_RELEASE déjà installé. Upgrade avec les values actuelles…"
  helm upgrade "$RW_RELEASE" "$REPO/$CHART" -n "$DEPLOY_NS" -f "$VALUES"
  exit 0
fi

info "Création du namespace $DEPLOY_NS…"
kubectl create namespace "$DEPLOY_NS" 2>/dev/null || true

info "Installation de RisingWave ($RW_RELEASE) via helm…"
helm install "$RW_RELEASE" "$REPO/$CHART" \
  --namespace "$DEPLOY_NS" \
  --create-namespace \
  --values "$VALUES" \
  --wait --timeout 5m

info "Attente readiness des pods RisingWave…"
kubectl -n "$DEPLOY_NS" wait --for=condition=ready pod \
  --all --timeout 180s || true

ok "RisingWave déployé (namespace $DEPLOY_NS)."
note "Pods :"
kubectl -n "$DEPLOY_NS" get pods
