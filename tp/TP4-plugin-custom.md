# TP4 : Le plugin maison `check-referer`

**Objectif** : comprendre comment est construit un plugin Kong, en évaluer la sécurité, le faire évoluer et le tester.

**Le besoin métier** : une clé d'API embarquée dans un front web est publique (voir la fin du TP3). Pour limiter sa réutilisation par d'autres sites, on associe à chaque consumer le ou les sites autorisés (une regex), et on vérifie l'en-tête `Referer` envoyé par le navigateur.

## 1. Anatomie d'un plugin (lecture de code, 20 min)

Ouvrez [kong/plugins/check-referer/](../kong/plugins/check-referer/).

| Fichier | Rôle |
|---------|------|
| [schema.lua](../kong/plugins/check-referer/schema.lua) | Les options de configuration du plugin, validées par l'Admin API |
| [handler.lua](../kong/plugins/check-referer/handler.lua) | Le code exécuté à chaque requête |
| [daos.lua](../kong/plugins/check-referer/daos.lua) | Une **nouvelle entité** en base (`check_referer`), avec son API d'admin générée automatiquement |
| [migrations/](../kong/plugins/check-referer/migrations/) | La création de la table, pour Postgres et pour Cassandra |

Répondez aux questions suivantes en lisant le code :

1. Dans quelle **phase** du cycle de requête le plugin s'exécute-t-il ? Citez deux autres phases disponibles et un exemple d'usage pour chacune.
2. `PRIORITY = 200`. Le plugin `key-auth` a une priorité de 1003. Pourquoi est-il indispensable que `key-auth` passe **avant** ? Que se passerait-il avec `PRIORITY = 2000` ?
3. Le schéma déclare `consumer = typedefs.no_consumer`. Qu'est-ce que cela interdit, et pourquoi ?
4. Le handler n'interroge pas la base directement : il passe par `kong.cache:get(...)`. Pourquoi ? Que se passe-t-il quand on modifie un referer via l'Admin API ? (Indice : `cache_key` dans `daos.lua`.)
5. Quelles URLs d'Admin API le fichier `daos.lua` crée-t-il ? Comparez avec [API.md](../API.md).

## 2. Mise en place

```bash
curl -s -X POST localhost:8001/services --data name=carto --data url=http://httpbin:8080/anything
curl -s -X POST localhost:8001/services/carto/routes --data name=carto --data 'paths[]=/carto'
curl -s -X POST localhost:8001/services/carto/plugins --data name=key-auth --data 'config.key_names[]=apikey'
curl -s -X POST localhost:8001/routes/carto/plugins --data name=check-referer

curl -s -X POST localhost:8001/consumers --data username=site-plop
curl -s -X POST localhost:8001/consumers/site-plop/key-auth --data key=CLE-PLOP
curl -s -X POST localhost:8001/consumers/site-plop/check-referer --data-urlencode 'referer=plop\.fr' | jq
```

Notez l'`id` renvoyé par la dernière commande.

✅ **Checkpoint**

| Appel | Attendu |
|-------|---------|
| `curl -H 'apikey: CLE-PLOP' -H 'Referer: https://plop.fr/page' localhost:8000/carto` | 200 |
| `curl -H 'apikey: CLE-PLOP' -H 'Referer: https://autre.fr/' localhost:8000/carto` | 403 |
| `curl -H 'apikey: CLE-PLOP' localhost:8000/carto` | 403 |
| `curl -H 'apikey: CLE-ALICE' -H 'Referer: https://plop.fr/' localhost:8000/carto` | 403 (alice n'a pas de referer configuré) |

Modifiez le referer de `site-plop` en `plop\.com` (`PATCH /check-referers/{id}`). Le changement est-il pris en compte immédiatement ? Expliquez, en lien avec la question 4.

Remettez ensuite `plop\.fr`.

## 3. Jouez l'attaquant (20 min)

Le consumer `site-plop` n'est autorisé que pour `plop.fr`… en théorie.

À vous : trouvez **au moins trois** valeurs de `Referer` qui ne proviennent **pas** du site `plop.fr` mais obtiennent un `200`.

Puis répondez :
1. Pourquoi ces contournements fonctionnent-ils ? (Regardez `matcher` dans `handler.lua`.)
2. Avec `curl`, on met le `Referer` qu'on veut. Contre quel type d'attaquant ce plugin protège-t-il vraiment, et contre lequel est-il inutile ?

## 4. Revue de code (20 min)

Relisez [handler.lua](../kong/plugins/check-referer/handler.lua) comme si c'était une merge request. Cherchez notamment :

1. **Les logs** : appelez `/carto` puis regardez `docker compose -f docker-compose-local.yml logs --tail 20 kong`. Une ligne `[error]` apparaît alors que tout va bien. Pourquoi ? Quel impact en production (alerting, volume de logs) ?
2. **La gestion d'erreur** : si Cassandra tombe, quel code HTTP le client reçoit-il ? Est-ce le bon ? (Regardez l'ordre des `if` après `kong.cache:get`.)
3. **L'unicité** : `daos.lua` déclare `unique = true` sur `consumer`. Créez un **deuxième** referer pour `site-plop` (`POST /consumers/site-plop/check-referer`). Que se passe-t-il ? Quel referer est appliqué ensuite ? Que dit [API.md](../API.md) à ce sujet ?
4. **La lecture de l'en-tête** : `kong.request.get_headers()['Referer']` charge **tous** les en-têtes pour en lire un seul. Quelle fonction du PDK est plus adaptée ?

Supprimez le referer en double avant de continuer (`DELETE /check-referers/{id}`).

## 5. Faire évoluer le plugin (45 min)

Ajoutez deux options de configuration au plugin :

| Option | Type | Défaut | Comportement |
|--------|------|--------|--------------|
| `allow_empty_referer` | booléen | `false` | Si `true`, une requête **sans** en-tête `Referer` est acceptée (ex : appels serveur à serveur) |
| `match_host_only` | booléen | `false` | Si `true`, la regex est comparée à l'**hôte** du Referer uniquement (`https://plop.fr:8443/page` → `plop.fr`), et doit le couvrir **entièrement** |

Avec `match_host_only=true`, les trois contournements de la partie 3 doivent renvoyer `403`. Corrigez aussi les points relevés en partie 4.

> Pourquoi des valeurs par défaut à `false`, alors que `match_host_only=true` est plus sûr ? Pensez aux configurations déjà en production.

**Boucle de développement.** Le plugin est copié dans l'image, il faut donc rebuilder et recréer le conteneur :

```bash
docker build . -t kong-local
docker compose -f docker-compose-local.yml up -d --force-recreate kong
docker compose -f docker-compose-local.yml logs --tail 50 kong   # vérifier l'absence d'erreur Lua
```

Activez les options :

```bash
curl -s localhost:8001/routes/carto/plugins | jq '.data[] | select(.name=="check-referer") | {id, config}'
curl -s -X PATCH localhost:8001/plugins/<id> \
  --data config.match_host_only=true \
  --data config.allow_empty_referer=true
```

✅ **Checkpoint** (avec les deux options à `true`)

| Referer | Attendu |
|---------|---------|
| `https://plop.fr/page` | 200 |
| `https://PLOP.fr:8443/` | 200 |
| *(absent)* | 200 |
| `https://evil.com/?plop.fr` | 403 |
| `https://plop.fr.evil.com/` | 403 |
| `https://plop.fr@evil.com/` | 403 |

Vérifiez aussi que l'Admin API refuse une option inconnue : `--data config.foo=1` doit renvoyer `400`.

## 6. Tester (35 min)

Les tests se trouvent dans [spec/check-referer/](../spec/check-referer/) et se lancent avec [pongo](https://github.com/Kong/kong-pongo), qui démarre Kong et ses bases dans Docker :

```bash
KONG_VERSION=2.8.5 pongo run
```

> Le premier lancement télécharge plusieurs images. Comptez 10 à 15 minutes : lancez-le à l'avance.

Le fichier [.pongo/pongorc](../.pongo/pongorc) demande Postgres **et** Cassandra : chaque test d'intégration tourne sur les deux bases (voir `helpers.each_strategy()`).

À vous :
1. Lisez [01-unit_spec.lua](../spec/check-referer/01-unit_spec.lua) et [02-integration_spec.lua](../spec/check-referer/02-integration_spec.lua). Quelle différence entre les deux ? Qu'est-ce que `bp` (blueprints) ?
2. Ajoutez des tests unitaires de schéma pour vos deux nouvelles options : valeurs par défaut, et rejet d'une valeur non booléenne.
3. Ajoutez des tests d'intégration :
   - une route avec `match_host_only = true` : les trois contournements renvoient `403` ;
   - une route avec `allow_empty_referer = true` : une requête sans Referer renvoie `200`.
4. Bonus : écrivez un test qui prouve que les contournements **passent** avec la configuration par défaut. Pourquoi est-ce utile de documenter un comportement « non souhaité » par un test ?

Pour itérer plus vite, lancez un seul fichier : `KONG_VERSION=2.8.5 pongo run spec/check-referer/01-unit_spec.lua`.
