#!/usr/bin/env bash
# ============================================================
# 09-deploy-zincsearch.sh
# Déploie ZincSearch (recherche full-text, alternative légère à
# OpenSearch) en tant que DESTINATION SINK de RisingWave.
# ⚠️ DÉMO / PROTOTYPE : un seul pod, PVC local, pas de HA/TLS.
# Usage : ./09-deploy-zincsearch.sh
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

source ./_common.sh
need_cluster

MANIFEST=./zincsearch.yaml
[ -f "$MANIFEST" ] || die "Manifest introuvable : $MANIFEST"

info "Application du manifest ZincSearch ($MANIFEST)…"
kubectl apply -f "$MANIFEST"

info "Attente readiness du pod ZincSearch…"
kubectl -n zincsearch wait --for=condition=ready pod \
  -l app=zincsearch --timeout=180s

ok "ZincSearch déployé (namespace zincsearch)."
note "UI + API : http://localhost:4080 (via ./04-port-forward.sh)"
note "Identifiants : admin / admin"
note "Chemin API compatible Elasticsearch : http://zincsearch:4080/es"
