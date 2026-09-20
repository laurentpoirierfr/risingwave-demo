#!/usr/bin/env bash
# ============================================================
# 06-verify-minio.sh
# Montre que RisingWave utilise bien l'object store S3 (MinIO)
# comme state store : listing des buckets/objets + volumes.
# Usage : ./06-verify-minio.sh
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"

source ./_common.sh
need_cluster

info "State store (MinIO) utilisé par RisingWave…"
MINIO_SVC="${RW_SVC_MINIO}"
ROOT=hummockadmin
PASS=hummockadmin

POD="rw-minio-$$"
cleanup() { kubectl -n "$DEPLOY_NS" delete pod "$POD" --ignore-not-found >/dev/null 2>&1 || true; }
trap cleanup EXIT

info "Listing des buckets/objets via le client mc…"
kubectl -n "$DEPLOY_NS" run "$POD" \
  --image=quay.io/minio/mc:latest --restart=Never --rm -i --quiet \
  --env "MC_HOST_minio=http://$ROOT:$PASS@$MINIO_SVC:9000" \
  --command -- sh -c 'mc ls minio; echo "---- buckets ----"; mc find minio --maxdepth 2 | head -40'

echo
info "Volumes persistants du cluster :"
kubectl get pvc -n "$DEPLOY_NS"
kubectl get pv 2>/dev/null | grep -i "minio\|bound" || true

note "(Le volume MinIO persiste l'état hummock ; les objets y grandissent avec les MVs.)"
