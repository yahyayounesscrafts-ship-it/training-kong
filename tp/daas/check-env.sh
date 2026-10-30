#!/usr/bin/env bash
# Vérifie qu'une machine (VM du DaaS, poste stagiaire) peut dérouler les TPs Kong.
# Ne modifie rien. Usage : bash tp/daas/check-env.sh
# Code de sortie : 0 si aucun point bloquant, 1 sinon.

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ -t 1 ]; then
  GREEN=$'\e[32m'; YELLOW=$'\e[33m'; RED=$'\e[31m'; BOLD=$'\e[1m'; RESET=$'\e[0m'
else
  GREEN=""; YELLOW=""; RED=""; BOLD=""; RESET=""
fi

N_OK=0; N_WARN=0; N_KO=0
ok()      { N_OK=$((N_OK + 1));     echo "  ${GREEN}[OK]${RESET}   $*"; }
warn()    { N_WARN=$((N_WARN + 1)); echo "  ${YELLOW}[WARN]${RESET} $*"; }
ko()      { N_KO=$((N_KO + 1));     echo "  ${RED}[KO]${RESET}   $*"; }
info()    { echo "         $*"; }
section() { echo; echo "${BOLD}== $* ==${RESET}"; }
has()     { command -v "$1" >/dev/null 2>&1; }

# Images utilisées par les TPs (stack, terragrunt, dépendances de pongo)
IMAGES=(
  "kong:2.8"
  "cassandra:3.9"
  "mccutchen/go-httpbin:latest"
  "pantsel/konga:latest"
  "cytopia/terragrunt:1.0-0.29"
  "postgres:9.5"
  "cassandra:3.11"
)
PORTS=(8000 8001 8443 8444 1337 9042 7000 7001 7199 9160 3000)

# ---------------------------------------------------------------------------
section "Système"

OS="$(uname -s)"; ARCH="$(uname -m)"
info "OS : $OS $(uname -r) / arch : $ARCH"
case "$ARCH" in
  x86_64|amd64) ok "Architecture x86_64" ;;
  *) ko "Architecture $ARCH : l'image cassandra:3.9 n'existe qu'en amd64 (prévoir des VMs x86_64)" ;;
esac

if [ "$OS" = "Linux" ]; then
  CPUS="$(nproc 2>/dev/null || echo 0)"
  MEM_GB="$(awk '/MemTotal/ {printf "%d", $2/1024/1024 + 0.5}' /proc/meminfo)"
else
  CPUS="$(sysctl -n hw.ncpu 2>/dev/null || echo 0)"
  MEM_GB="$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024 / 1024 / 1024 ))"
fi

if   [ "$CPUS" -ge 4 ]; then ok "$CPUS vCPU"
elif [ "$CPUS" -ge 2 ]; then warn "$CPUS vCPU : suffisant, mais Cassandra et pongo seront lents (4 recommandés)"
else ko "$CPUS vCPU : 2 minimum"
fi

if   [ "$MEM_GB" -ge 8 ]; then ok "${MEM_GB} Go de RAM"
elif [ "$MEM_GB" -ge 6 ]; then warn "${MEM_GB} Go de RAM : arrêter la stack avant 'pongo run' (8 Go recommandés)"
else ko "${MEM_GB} Go de RAM : la stack seule prend ~2 Go, la stack + pongo ~4 Go ; 6 Go minimum, 8 recommandés"
fi

free_gb() { df -Pk "$1" 2>/dev/null | awk 'NR==2 {printf "%d", $4/1024/1024}'; }
DISK_REPO="$(free_gb "$REPO_DIR")"
if   [ "${DISK_REPO:-0}" -ge 20 ]; then ok "${DISK_REPO} Go libres pour le repo"
elif [ "${DISK_REPO:-0}" -ge 10 ]; then warn "${DISK_REPO} Go libres pour le repo (20 recommandés)"
else ko "${DISK_REPO:-?} Go libres pour le repo : les images et le build pongo demandent ~10 Go"
fi

# ---------------------------------------------------------------------------
section "Docker"

DOCKER_OK=0
if ! has docker; then
  ko "docker absent"
else
  if docker info >/dev/null 2>&1; then
    DOCKER_OK=1
    ok "Docker $(docker version --format '{{.Server.Version}}' 2>/dev/null) accessible sans sudo"
    DOCKER_ROOT="$(docker info --format '{{.DockerRootDir}}' 2>/dev/null)"
    if [ -n "$DOCKER_ROOT" ] && [ -d "$DOCKER_ROOT" ]; then
      DISK_DOCKER="$(free_gb "$DOCKER_ROOT")"
      if [ "${DISK_DOCKER:-0}" -ge 15 ]; then ok "${DISK_DOCKER} Go libres pour Docker ($DOCKER_ROOT)"
      else warn "${DISK_DOCKER:-?} Go libres pour Docker ($DOCKER_ROOT) : 15 recommandés"
      fi
    fi
    DPROXY="$(docker info 2>/dev/null | grep -iE '^ *(HTTP|HTTPS|No) Proxy' | sed 's/^ *//')"
    [ -n "$DPROXY" ] && info "Proxy du démon Docker : $(echo "$DPROXY" | tr '\n' ' ')"
  elif docker info 2>&1 | grep -qi 'permission denied'; then
    ko "docker présent mais 'permission denied' : ajouter l'utilisateur au groupe docker (sudo usermod -aG docker \$USER, puis se reconnecter)"
  else
    ko "démon Docker injoignable (docker info échoue) : est-il démarré ?"
  fi
fi

if has docker && docker compose version >/dev/null 2>&1; then
  ok "$(docker compose version | head -1)"
else
  ko "plugin 'docker compose' (v2) absent : utilisé par tous les TPs"
fi

if has docker-compose; then
  ok "docker-compose (v1) présent : le Makefile du repo fonctionnera"
else
  warn "docker-compose (v1) absent : les cibles du Makefile échoueront (les TPs n'en ont pas besoin)"
fi

# ---------------------------------------------------------------------------
section "Outils"

has curl    && ok "curl"    || ko   "curl absent (utilisé dans tous les TPs)"
has jq      && ok "jq"      || warn "jq absent : très utilisé dans les TPs (sudo apt install -y jq)"
has git     && ok "git"     || warn "git absent : nécessaire pour installer pongo (TP4)"
has python3 && ok "python3" || warn "python3 absent : sert à servir le front au TP3 (python3 -m http.server)"
has make    && ok "make"    || info "make absent (facultatif)"

if has pongo; then
  ok "pongo installé ($(command -v pongo))"
elif [ -x "$HOME/.local/bin/pongo" ]; then
  warn "pongo installé dans ~/.local/bin mais absent du PATH : echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
else
  warn "pongo non installé : lancer tp/daas/prepare.sh, ou voir https://github.com/Kong/kong-pongo#installation"
fi

BROWSER=""
for b in firefox chromium chromium-browser google-chrome google-chrome-stable microsoft-edge; do
  has "$b" && BROWSER="$b" && break
done
if [ "$OS" = "Darwin" ]; then
  ok "macOS : navigateur disponible pour Konga (TP0) et le front CORS (TP3)"
elif [ -n "$BROWSER" ]; then
  ok "Navigateur dans la VM ($BROWSER) : Konga (TP0) et le front CORS (TP3) seront utilisables"
else
  warn "Aucun navigateur trouvé dans la VM : Konga (TP0) et la démo CORS dans le navigateur (TP3) devront se faire avec curl"
fi

# ---------------------------------------------------------------------------
section "Ports (doivent être libres avant le TP0)"

port_busy() {
  if has ss; then ss -ltnH 2>/dev/null | awk '{print $4}' | grep -qE "[:.]$1\$"
  elif has lsof; then lsof -iTCP:"$1" -sTCP:LISTEN -P -n >/dev/null 2>&1
  else (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
  fi
}
BUSY=()
for p in "${PORTS[@]}"; do port_busy "$p" && BUSY+=("$p"); done
if [ "${#BUSY[@]}" -eq 0 ]; then
  ok "Ports ${PORTS[*]} libres"
else
  warn "Ports déjà utilisés : ${BUSY[*]} (une stack Kong tourne déjà ? sinon, identifier le processus)"
fi

# ---------------------------------------------------------------------------
section "Accès réseau sortant"

for v in HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy; do
  [ -n "${!v:-}" ] && info "$v=${!v}"
done

# code HTTP renvoyé (000 = injoignable)
http_code() { curl -s -o /dev/null -w '%{http_code}' --connect-timeout 8 --max-time 15 "$1" 2>/dev/null; }

check_url() { # $1 = url, $2 = usage, $3 = gravité si injoignable (ko|warn)
  local code; code="$(http_code "$1")"
  if [ "$code" != "000" ] && [ -n "$code" ]; then ok "$1 ($code) – $2"
  else "$3" "$1 injoignable – $2"
  fi
}

check_url https://registry-1.docker.io/v2/              "Docker Hub (pull des images)"             ko
check_url https://auth.docker.io/token                  "Docker Hub (authentification)"           ko
check_url https://production.cloudflare.docker.com/     "Docker Hub (téléchargement des couches)" ko
check_url https://registry.terraform.io/.well-known/terraform.json "registre Terraform (TP5)"     warn
check_url https://github.com/                           "GitHub : pongo, provider Terraform"      warn
check_url https://objects.githubusercontent.com/        "GitHub : binaires des releases"          warn
check_url https://release-assets.githubusercontent.com/ "GitHub : binaires des releases"          warn
check_url http://archive.ubuntu.com/ubuntu/             "build de l'image pongo (apt)"             warn
check_url https://luarocks.org/                         "build de l'image pongo (luarocks)"        warn

# Quota de pulls anonymes Docker Hub : partagé par toutes les VMs qui sortent par la même IP
if has curl; then
  TOKEN="$(curl -s --max-time 15 'https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull' \
           | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
  if [ -n "$TOKEN" ]; then
    RL="$(curl -s --max-time 15 --head -H "Authorization: Bearer $TOKEN" \
          https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest | tr -d '\r' | grep -i '^ratelimit-')"
    LIMIT="$(echo "$RL" | awk -F'[ :;]+' 'tolower($1)=="ratelimit-limit" {print $2}')"
    REMAINING="$(echo "$RL" | awk -F'[ :;]+' 'tolower($1)=="ratelimit-remaining" {print $2}')"
    if [ -n "$REMAINING" ]; then
      if [ "$REMAINING" -ge 20 ]; then ok "Quota Docker Hub : $REMAINING pulls restants sur $LIMIT (pour l'IP de sortie)"
      else warn "Quota Docker Hub : $REMAINING pulls restants sur $LIMIT. Chaque VM tire ~7 images : pré-charger les images dans le modèle de VM ou faire un 'docker login'"
      fi
    else
      info "Quota Docker Hub : pas d'en-tête ratelimit (compte authentifié ou miroir)"
    fi
  fi
fi

# ---------------------------------------------------------------------------
section "Préparation (images, build, caches)"

if [ "$DOCKER_OK" = 1 ]; then
  MISSING=()
  for img in "${IMAGES[@]}"; do docker image inspect "$img" >/dev/null 2>&1 || MISSING+=("$img"); done
  if [ "${#MISSING[@]}" -eq 0 ]; then ok "Toutes les images sont déjà présentes"
  else warn "Images à télécharger pendant la formation : ${MISSING[*]}"
  fi
  docker image inspect kong-local >/dev/null 2>&1 && ok "Image kong-local buildée" \
    || warn "Image kong-local absente (le TP0 la construit, sinon tp/daas/prepare.sh)"
  if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q '^kong-pongo.*:2\.8\.5$'; then
    ok "Image de test pongo pour Kong 2.8.5 déjà construite"
  else
    warn "Image de test pongo absente : son premier build prend 15 à 30 min (tp/daas/prepare.sh)"
  fi
fi

if ls "$REPO_DIR"/infra/.terraform-plugin-cache/registry.terraform.io/philips-labs/kong/*/* >/dev/null 2>&1; then
  ok "Provider Terraform philips-labs/kong déjà en cache"
else
  warn "Provider Terraform pas en cache : téléchargé au TP5 (tp/daas/prepare.sh)"
fi

[ -f "$REPO_DIR/docker-compose-local.yml" ] && ok "Repo trouvé : $REPO_DIR" \
  || ko "docker-compose-local.yml introuvable dans $REPO_DIR"

# ---------------------------------------------------------------------------
echo
echo "${BOLD}Bilan : ${GREEN}$N_OK OK${RESET}${BOLD}, ${YELLOW}$N_WARN avertissement(s)${RESET}${BOLD}, ${RED}$N_KO bloquant(s)${RESET}"
[ "$N_KO" -eq 0 ]
