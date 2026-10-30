#!/usr/bin/env bash
# Prépare une machine pour les TPs Kong : pré-télécharge tout ce qui est lourd ou fragile,
# puis vérifie de bout en bout que la stack fonctionne. Idempotent : relançable sans risque.
#
# À lancer UNE fois sur la VM modèle du DaaS, avant d'en faire une image/snapshot pour les stagiaires.
#
# Usage : [FORCE=1] bash tp/daas/prepare.sh [--skip-tests]
#   --skip-tests  ne lance pas la suite de tests pongo à la fin (gagne ~3 min)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"

KONG_VERSION="2.8.5"
PONGO_HOME="${PONGO_HOME:-$HOME/.local/share/kong-pongo}"
BIN_DIR="$HOME/.local/bin"
SMOKE_PROJECT="kongtp-smoke"
RUN_TESTS=1
[ "${1:-}" = "--skip-tests" ] && RUN_TESTS=0

COMPOSE=(docker compose -f docker-compose-local.yml)

step() { echo; echo "==> $*"; }
retry() { # retry <n> <commande...> : le réseau des salles de formation est souvent capricieux
  local n="$1"; shift
  local i
  for ((i = 1; i <= n; i++)); do
    "$@" && return 0
    echo "    échec (tentative $i/$n), nouvel essai dans 10 s..."
    sleep 10
  done
  return 1
}

step "1/6 Vérification de l'environnement"
if ! bash "$REPO_DIR/tp/daas/check-env.sh"; then
  if [ "${FORCE:-0}" = 1 ]; then
    echo "Points bloquants détectés, mais FORCE=1 : on continue."
  else
    echo "Des points bloquants ont été détectés ci-dessus : corrigez-les, ou relancez avec FORCE=1 pour passer outre."
    exit 1
  fi
fi

step "2/6 Téléchargement des images Docker"
for img in kong:2.8 cassandra:3.9 mccutchen/go-httpbin:latest pantsel/konga:latest \
           cytopia/terragrunt:1.0-0.29 postgres:9.5 cassandra:3.11; do
  echo "    $img"
  retry 3 docker pull -q "$img" >/dev/null
done

step "3/6 Build de l'image kong-local (Kong 2.8 + plugin check-referer)"
docker build -q -t kong-local . >/dev/null

step "4/6 Cache du provider Terraform (TP5)"
mkdir -p infra/.terraform-plugin-cache
retry 3 "${COMPOSE[@]}" run --rm terragrunt \
  terragrunt init -no-color --terragrunt-working-dir /data/tenants/local >/dev/null 2>&1
ls -d infra/.terraform-plugin-cache/registry.terraform.io/philips-labs/kong/*/* >/dev/null
echo "    provider philips-labs/kong en cache dans infra/.terraform-plugin-cache"

step "5/6 Installation de pongo et build de son image de test (long la première fois)"
if [ ! -d "$PONGO_HOME/.git" ]; then
  retry 3 git clone -q --depth 1 https://github.com/Kong/kong-pongo.git "$PONGO_HOME"
fi
mkdir -p "$BIN_DIR"
ln -sf "$PONGO_HOME/pongo.sh" "$BIN_DIR/pongo"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "    ⚠ $BIN_DIR n'est pas dans le PATH : ajoutez 'export PATH=\"\$HOME/.local/bin:\$PATH\"' à ~/.bashrc"
     export PATH="$BIN_DIR:$PATH" ;;
esac
retry 3 env KONG_VERSION="$KONG_VERSION" pongo build

step "6/6 Test de fumée de la stack (projet Docker '$SMOKE_PROJECT', supprimé à la fin)"
SMOKE=(docker compose -p "$SMOKE_PROJECT" -f docker-compose-local.yml)
cleanup() { "${SMOKE[@]}" down -v --remove-orphans >/dev/null 2>&1 || true; }
trap cleanup EXIT

if curl -s -o /dev/null --max-time 2 localhost:8001; then
  echo "    Une stack Kong tourne déjà sur le port 8001 : test de fumée ignoré."
else
  "${SMOKE[@]}" up -d cassandra >/dev/null 2>&1
  printf "    attente de Cassandra"
  for _ in $(seq 1 60); do
    [ "$(docker inspect -f '{{.State.Health.Status}}' "$("${SMOKE[@]}" ps -q cassandra)")" = healthy ] && break
    printf "."; sleep 5
  done; echo
  "${SMOKE[@]}" run --rm kong-migrations >/dev/null 2>&1
  "${SMOKE[@]}" up -d kong httpbin >/dev/null 2>&1
  for _ in $(seq 1 30); do curl -s -o /dev/null localhost:8001/status && break; sleep 2; done

  curl -sf localhost:8001 | grep -q '"check-referer":true' || { echo "    ✗ plugin check-referer non chargé"; exit 1; }
  curl -sf -o /dev/null -X POST localhost:8001/services --data name=smoke --data url=http://httpbin:8080
  curl -sf -o /dev/null -X POST localhost:8001/services/smoke/routes --data 'paths[]=/smoke'
  sleep 6
  CODE="$(curl -s -o /dev/null -w '%{http_code}' localhost:8000/smoke/get)"
  [ "$CODE" = 200 ] || { echo "    ✗ proxy -> httpbin : HTTP $CODE au lieu de 200"; exit 1; }
  echo "    ✓ Kong démarre, charge check-referer et relaie vers httpbin"
fi
cleanup
trap - EXIT

if [ "$RUN_TESTS" = 1 ]; then
  step "Tests du plugin avec pongo (Postgres + Cassandra)"
  KONG_VERSION="$KONG_VERSION" pongo run
  KONG_VERSION="$KONG_VERSION" pongo down >/dev/null 2>&1 || true
fi

echo
echo "✅ Machine prête pour les TPs."
echo "   Pensez à vérifier qu'aucun conteneur ne tourne avant de figer la VM : docker ps"
