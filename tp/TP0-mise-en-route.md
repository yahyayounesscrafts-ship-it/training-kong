# TP0 : Mise en route

**Objectif** : avoir une gateway Kong qui tourne, et comprendre de quoi elle est composée.

## 1. Ce qu'on va lancer

Ouvrez [docker-compose-local.yml](../docker-compose-local.yml) et repérez les services :

| Service | Rôle |
|---------|------|
| `cassandra` | La base où Kong stocke sa configuration (services, routes, plugins, consumers…) |
| `kong-migrations` | Conteneur « one-shot » qui crée les tables dans la base |
| `kong` | La gateway elle-même |
| `httpbin` | Un backend de test qui renvoie en JSON la requête qu'il a reçue. Il va nous servir de miroir pour voir ce que Kong transmet |
| `konga` | Interface graphique d'administration |

> **Question** : le service `kong` utilise l'image `kong-local`. D'où vient-elle ? Regardez le [Dockerfile](../Dockerfile). Que contient-elle de plus que l'image officielle ?

## 2. Builder l'image

```bash
docker build . -t kong-local
```

> Sur Linux, si vous obtenez `permission denied ... docker.sock`, votre utilisateur n'est pas dans le groupe `docker` : `sudo usermod -aG docker $USER`, puis déconnexion et reconnexion.
>
> Sur macOS, si vous obtenez `docker-credential-desktop: executable file not found`, ajoutez Docker Desktop au PATH :
> `export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"`

## 3. Démarrer la base, puis les migrations, puis Kong

L'ordre compte : Kong ne démarre pas sans une base initialisée.

```bash
# 1. La base (Cassandra met 30 s à 1 min à être prête)
docker compose -f docker-compose-local.yml up -d cassandra
docker compose -f docker-compose-local.yml ps cassandra   # attendre "healthy"

# 2. Les migrations : création du schéma
docker compose -f docker-compose-local.yml run --rm kong-migrations

# 3. Kong, le backend de test et l'interface graphique
docker compose -f docker-compose-local.yml up -d kong httpbin konga
```

> **Question** : dans la sortie des migrations, cherchez `check-referer`. Pourquoi notre plugin a-t-il ses propres migrations ?

## 4. Vérifier

```bash
curl -s localhost:8001 | jq '.version'
curl -s localhost:8001/status | jq
curl -i localhost:8000
```

✅ **Checkpoint**
- L'Admin API répond `"2.8.5"`.
- `/status` indique `"reachable": true` pour la base.
- Le proxy répond `404` avec `{"message":"no Route matched with those values"}`. C'est normal : Kong tourne, mais on ne lui a encore rien appris.

## 5. Le plugin maison est-il chargé ?

```bash
curl -s localhost:8001 | jq '.plugins.available_on_server | keys | map(select(. == "check-referer"))'
```

> **Question** : deux variables d'environnement du service `kong` rendent ce chargement possible. Lesquelles, et que fait chacune ?

## 6. Konga (facultatif)

1. Ouvrez http://localhost:1337 et créez un compte admin local.
2. Ajoutez une connexion : *Kong Admin URL* = `http://kong:8001`.

> **Question** : pourquoi `http://kong:8001` et pas `http://localhost:8001` ?

Konga est pratique pour visualiser, mais **dans les TPs on passe par `curl`** : c'est ce que vous automatiserez ensuite.
