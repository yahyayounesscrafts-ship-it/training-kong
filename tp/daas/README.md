# Dérouler les TPs sur le DaaS Ambient IT

Le DaaS (https://daas.ambient-it.net) est un portail **Apache Guacamole** : chaque stagiaire ouvre, depuis son navigateur, un bureau à distance (ou un terminal SSH) sur une VM. Tout se passe **dans la VM** : Docker, Kong, curl, le navigateur pour Konga… Le poste du stagiaire ne sert qu'à afficher.

Deux scripts :

| Script | Rôle | Durée |
|--------|------|-------|
| [check-env.sh](check-env.sh) | Vérifie la VM, sans rien modifier : ressources, Docker, outils, ports, accès réseau, quota Docker Hub, préparation | ~30 s |
| [prepare.sh](prepare.sh) | Pré-télécharge les images, builde `kong-local`, met en cache le provider Terraform, installe pongo et builde son image, puis teste la stack de bout en bout | 20 à 40 min la 1ʳᵉ fois |

## 1. Ce qu'il faut demander à Ambient IT

| Élément | Minimum | Recommandé | Pourquoi |
|---------|---------|------------|----------|
| OS / architecture | Linux **x86_64** | Ubuntu 22.04 ou 24.04 | `cassandra:3.9` n'existe pas en ARM |
| vCPU | 2 | 4 | Cassandra + Kong, et pongo qui lance un 2ᵉ Kong + Postgres + Cassandra |
| RAM | 6 Go | 8 Go | Stack ≈ 1,5 Go ; stack + tests pongo ≈ 4 Go |
| Disque libre | 15 Go | 30 Go | Images ≈ 3 Go, image de test pongo ≈ 1 Go + cache de build |
| Docker | Engine + plugin `docker compose` v2 | | Tous les TPs |
| Droits | utilisateur dans le groupe `docker` | `sudo` disponible | Éviter `sudo docker` partout |
| Outils | `curl`, `jq`, `git` | `python3` | `jq` est utilisé dans presque toutes les commandes |
| Bureau graphique | | **Oui**, avec Firefox ou Chromium | Konga (TP0) et la démo CORS dans le navigateur (TP3). En SSH seul, ces deux parties se font au `curl` |
| Une VM par stagiaire | | + une pour le formateur | Les TPs s'enchaînent et modifient la configuration de Kong |

**Accès réseau sortant à autoriser** (HTTPS sauf mention contraire) :

| Domaine | Utilisé pour | Indispensable ? |
|---------|--------------|-----------------|
| `registry-1.docker.io`, `auth.docker.io`, `production.cloudflare.docker.com` | Pull des images | Oui, sauf si les images sont déjà dans le modèle de VM |
| `registry.terraform.io` | `terragrunt init` (TP5) : résolution de la version du provider | **Oui pendant la formation**, même avec le cache |
| `github.com`, `objects.githubusercontent.com`, `release-assets.githubusercontent.com` | Provider Terraform, pongo | Seulement pour la préparation |
| `archive.ubuntu.com`, `security.ubuntu.com` (HTTP), `luarocks.org`, `pypi.org` | Build de l'image pongo | Seulement pour la préparation |

**Quota Docker Hub.** Les pulls anonymes sont limités **par IP de sortie**. Si toutes les VMs sortent par la même IP, 10 stagiaires × 7 images épuisent vite le quota, et les pulls échouent en `toomanyrequests`. Le plus sûr : des images **déjà présentes dans le modèle de VM** (étape 2). Sinon, un `docker login` ou un miroir de registre fourni par Ambient IT.

## 2. Procédure recommandée

**J-7 : demande.** Envoyer le tableau ci-dessus à Ambient IT, en demandant une VM modèle qui sera **clonée** pour chaque stagiaire.

**J-5 : préparation de la VM modèle.**

1. Copier le repo dans la VM. Le plus simple est un `git clone` depuis un dépôt (privé) ; sinon, utiliser le transfert de fichiers de Guacamole (voir plus bas) avec une archive `.zip`.
2. Vérifier :
   ```bash
   bash tp/daas/check-env.sh
   ```
   Tout point `[KO]` doit être réglé avec Ambient IT. Avant préparation, des `[WARN]` sont normaux pour les images, pongo et le provider.
3. Préparer :
   ```bash
   bash tp/daas/prepare.sh
   ```
   Le script est relançable : s'il échoue sur un téléchargement, relancez-le simplement.
4. Relancer `check-env.sh` : il ne doit plus rester d'avertissement sur les images, pongo ou le provider.
5. Vérifier que rien ne tourne (`docker ps` vide), puis demander à Ambient IT de **figer la VM en modèle**.

**J-1 : contrôle.** Sur 2 ou 3 VMs stagiaires clonées, lancer `check-env.sh`. Résultat attendu : `0 bloquant`. Dérouler aussi rapidement le TP0 sur l'une d'elles.

**Jour J.** Premier geste des stagiaires : `bash tp/daas/check-env.sh`. Cela prend 30 secondes et détecte une VM mal clonée avant de commencer.

## 3. Pièges propres au DaaS (Guacamole)

- **Clavier.** Si la disposition clavier de la connexion Guacamole ne correspond pas à celle du poste (AZERTY/QWERTY), les caractères `| ~ { } [ ] \ @ #` sortent mal. Or ils sont partout dans les TPs (regex, `jq`, `curl`). À vérifier dès J-1 avec `echo '| ~ { } [ ] \ @ #'`.
- **Copier-coller.** Le presse-papier passe par le menu Guacamole (**Ctrl+Alt+Shift**). C'est peu pratique pour de longues commandes. Le plus simple : **ouvrir les énoncés dans la VM**, dans le navigateur de la VM ou dans un éditeur. Le repo y est déjà, et les copier-coller restent internes à la VM.
- **Transfert de fichiers.** S'il est activé sur la connexion, il se fait par glisser-déposer dans la fenêtre Guacamole, ou par le menu Ctrl+Alt+Shift → *Devices*. Sinon, passer par `git clone`.
- **Session inactive.** Guacamole peut couper les sessions inactives. Les conteneurs continuent de tourner dans la VM, il suffit de se reconnecter.
- **localhost.** Dans les TPs, `localhost` désigne **la VM**. Konga s'ouvre donc avec le navigateur **de la VM** (http://localhost:1337), pas avec celui du poste.

## 4. Ce dont chaque TP a besoin

| TP | Besoins particuliers |
|----|----------------------|
| TP0 | Images présentes (sinon téléchargement de ~1,5 Go), navigateur dans la VM pour Konga (facultatif) |
| TP1 – TP2 | Rien de plus |
| TP3 | `python3` et un navigateur dans la VM pour la démo CORS (sinon : partie curl uniquement) |
| TP4 | pongo installé et son image buildée (**impossible à faire en séance** : 15 à 30 min de build) |
| TP5 | Accès à `registry.terraform.io` ; provider en cache dans `infra/.terraform-plugin-cache` |
