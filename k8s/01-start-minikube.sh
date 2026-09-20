#!/usr/bin/env bash
# ============================================================
# 01-start-minikube.sh
# Démarre un cluster Minikube dimensionné pour RisingWave.
# Usage : ./01-start-minikube.sh [--delete]
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

source ./_common.sh

DRIVER=${DRIVER:-docker}
CPUS=${CPUS:-6}
MEMORY=${MEMORY:-10g}
DISK=${DISK:-30000mb}
K8S_VERSION=${K8S_VERSION:-}

require minikube
require kubectl
require docker

if [ "${1:-}" = "--delete" ]; then
  info "Suppression du cluster minikube existant…"
  minikube delete
fi

if minikube status >/dev/null 2>&1; then
  ok "Minikube déjà en cours d'exécution."
  minikube status
  exit 0
fi

info "Démarrage de Minikube (driver=$DRIVER, cpu=$CPUS, mem=$MEMORY, disk=$DISK)"
ARGS=(start --driver "$DRIVER" --cpus "$CPUS" --memory "$MEMORY" --disk-size "$DISK")
[ -n "$K8S_VERSION" ] && ARGS+=(--kubernetes-version "$K8S_VERSION")
minikube "${ARGS[@]}"

info "Sélection du contexte minikube…"
kubectl config use-context minikube

ok "Cluster minikube prêt."
minikube status
