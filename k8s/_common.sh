#!/usr/bin/env bash
# ============================================================
# _common.sh — fonctions partagées par les scripts k8s
# Usage : source "$(dirname "$0")/../k8s/_common.sh"  (à ajuster)
# ============================================================

# ---- Constantes de déploiement ------------------------------
DEPLOY_NS=${DEPLOY_NS:-risingwave}          # namespace RisingWave
RW_RELEASE=${RW_RELEASE:-my-risingwave}     # nom du release Helm
MONITOR_NS=${MONITOR_NS:-monitoring}        # namespace observabilité
MONITOR_RELEASE=${MONITOR_RELEASE:-obs}     # release kube-prometheus-stack

# ---- Noms de services dérivés du release ----------------------
RW_SVC_FRONTEND=${RW_RELEASE}                     # interface PostgreSQL (4567)
RW_SVC_META=${RW_RELEASE}-meta-headless           # dashboard meta (5691)
RW_SVC_MINIO=${RW_RELEASE}-minio                  # MinIO (api 9000 / console 9001)
RW_SVC_PG=${RW_RELEASE}-postgresql                # meta store PostgreSQL

# Couleurs (si stdout est un terminal)
if [ -t 1 ]; then
  C_RESET='\033[0m'; C_BOLD='\033[1m'
  C_TEAL='\033[36m'; C_YEL='\033[33m'; C_RED='\033[31m'; C_GRN='\033[32m'
  C_MUT='\033[2m'
else
  C_RESET=''; C_BOLD=''; C_TEAL=''; C_YEL=''; C_RED=''; C_GRN=''; C_MUT=''
fi

info()  { printf "${C_TEAL}==>${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$*"; }
note()  { printf "${C_MUT}   %s${C_RESET}\n" "$*"; }
ok()    { printf "${C_GRN}[ok]${C_RESET} %s\n" "$*"; }
warn()  { printf "${C_YEL}[warn]${C_RESET} %s\n" "$*"; }
die()   { printf "${C_RED}[err]${C_RESET} %s\n" "$*"; exit 1; }

require() {
  local bin="$1"
  command -v "$bin" >/dev/null 2>&1 \
    || die "'$bin' est requis mais introuvable dans PATH."
}

# ---- Préconditions cluster -----------------------------------
need_cluster() {
  server=$(kubectl config current-context 2>/dev/null)
  [ -n "$server" ] || die "Aucun contexte kube. Lance d'abord ./01-start-minikube.sh"
}

# ---- Attente de readiness des pods ---------------------------
wait_pods() {
  local ns="$1" label="$2" timeout="${3:-180}"
  info "Attente readiness des pods ($ns / $label) — timeout ${timeout}s"
  kubectl -n "$ns" wait --for=condition=ready pod \
    -l "$label" --timeout="${timeout}s" 2>/dev/null \
    || kubectl -n "$ns" wait --for=condition=ready pod \
       -l "$label" --timeout="${timeout}s"
}

# ---- Port-forward propre (arrière-plan, avec cleanup) ---------
# usage : pf <ns> <svc> <local_port>[:<target_port>] <nom>
# Déclare une fonction kill_pf() pour tuer tous les forwards lancés.
_PF_PIDS=()
pf() {
  local ns="$1" svc="$2" port="$3" name="$4"
  kubectl -n "$ns" port-forward "svc/$svc" "$port" >/dev/null 2>&1 &
  _PF_PIDS+=($!)
  ok "port-forward $name : http://localhost:${port%%:*}"
}
kill_pf() {
  [ ${#_PF_PIDS[@]} -eq 0 ] && return 0
  note "Arrêt des port-forwards…"
  kill "${_PF_PIDS[@]}" 2>/dev/null
  wait "${_PF_PIDS[@]}" 2>/dev/null
  _PF_PIDS=()
}

# ---- Attente qu'un service existe -----------------------------
wait_svc() {
  local ns="$1" name="$2" timeout="${3:-120}"
  info "Attente du service $name…"
  until kubectl -n "$ns" get svc "$name" >/dev/null 2>&1; do
    sleep 3; ((timeout-=3)); [ "$timeout" -le 0 ] \
      && die "timeout en attendant le service $name"
  done
  ok "service $name prêt"
}
