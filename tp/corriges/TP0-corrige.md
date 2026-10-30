# Corrigé TP0 : Mise en route

**Q1 – D'où vient `kong-local` ?** Du [Dockerfile](../../Dockerfile) : `FROM kong:2.8` + copie de `kong/plugins` (le plugin `check-referer`) dans `/kong/plugins`. L'image officielle n'a pas notre plugin. Version figée à 2.8 : Kong 3.x ne supporte plus Cassandra, et le plugin utilise l'API 2.x (`workspaceable`, migrations `200_to_210`).

**Q2 – Pourquoi le plugin a ses migrations ?** Il déclare une nouvelle entité (`check_referer`, dans `daos.lua`) : il faut créer sa table. Kong exécute les migrations de chaque plugin listé dans `KONG_PLUGINS`. Sortie attendue : `check-referer migrated up to: 000_base_check_referer` puis `003_200_to_210`.

**Q3 – Les deux variables d'environnement :**
- `KONG_PLUGINS=bundled,check-referer` : active les plugins officiels **et** le nôtre. Sans elle, l'Admin API refuserait `name=check-referer`.
- `KONG_LUA_PACKAGE_PATH=/kong/plugins/check-referer/?.lua;;` : où Lua cherche les modules (`;;` = « + le chemin par défaut »).

  Pour les curieux : Kong charge `require "kong.plugins.check-referer.handler"`, soit le fichier `kong/plugins/check-referer/handler.lua`. Le chemin explicite ci-dessus ne le trouve pas (il chercherait `/kong/plugins/check-referer/kong/plugins/...`). Ça fonctionne grâce au `;;` : le chemin par défaut contient `./?.lua` et le répertoire courant du conteneur est `/`, donc `/kong/plugins/check-referer/handler.lua`. Une valeur plus juste serait `KONG_LUA_PACKAGE_PATH=/?.lua;;`.

**Q4 – Pourquoi `http://kong:8001` dans Konga ?** C'est Konga (le conteneur) qui appelle l'Admin API, pas le navigateur. Dans le conteneur, `localhost` désigne Konga lui-même ; `kong` est le nom DNS du service sur le réseau Docker `kong-net`.

**Checkpoint** :
```bash
curl -s localhost:8001 | jq .version          # "2.8.5"
curl -s localhost:8001/status | jq .database   # {"reachable": true}
curl -i localhost:8000                         # 404 {"message":"no Route matched with those values"}
```
