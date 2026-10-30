# Corrigé TP4 : Le plugin `check-referer`

Les fichiers corrigés sont dans [tp4/kong/plugins/check-referer/](tp4/kong/plugins/check-referer/) (`handler.lua`, `schema.lua`). Les tests sont dans [tp4/spec/check-referer/](tp4/spec/check-referer/) : 33 tests verts avec `KONG_VERSION=2.8.5 pongo run`, sur Postgres et Cassandra.

Pour appliquer le corrigé :

```bash
cp -R tp/corriges/tp4/kong tp/corriges/tp4/spec .
docker build . -t kong-local
docker compose -f docker-compose-local.yml up -d --force-recreate kong
```

## 1. Anatomie

1. Phase **`access`**, exécutée après le routage et avant l'appel au backend. On peut y refuser une requête ou la modifier. Autres phases :
   - `rewrite` : avant le routage, pour réécrire l'URL ;
   - `header_filter` / `body_filter` : modifier la réponse ;
   - `log` : après la réponse, pour envoyer des métriques ou des logs sans ralentir le client ;
   - `certificate` : choisir un certificat TLS.
2. Les plugins s'exécutent par **priorité décroissante**. `key-auth` (1003) identifie le consumer avant `check-referer` (200). Avec `PRIORITY = 2000`, `check-referer` tournerait avant : `kong.client.get_consumer()` serait `nil` et le plugin renverrait 401 à tout le monde.
3. `no_consumer` interdit d'attacher le plugin **à un consumer**. Le referer est déjà par consumer, via l'entité `check_referer`. Configurer le plugin par consumer n'aurait pas de sens.
4. `kong.cache` (mlcache) garde le résultat en mémoire, par worker et en mémoire partagée nginx : pas de requête Cassandra à chaque appel. Une absence de valeur est aussi mise en cache (*negative caching*). Quand on modifie l'entité via l'Admin API, Kong émet un événement d'invalidation sur la clé `cache_key = { "consumer" }`. Le cache est purgé et le changement est **quasi immédiat**, sans attendre les 5 s de propagation du routeur. Sur un cluster, les autres nœuds sont invalidés au prochain `db_update_frequency`.
5. `daos.lua` génère :
   - `GET/POST /consumers/{consumer}/check-referer` (via `admin_api_nested_name`) ;
   - `GET/PUT/PATCH/DELETE /consumers/{consumer}/check-referer/{id}` ;
   - `GET /check-referers` et `GET/PATCH/PUT/DELETE /check-referers/{id}` (via `admin_api_name`).

   [API.md](../../API.md) ne documente que la partie imbriquée, et `POST /service/{id}/plugins` y est mal écrit (`services`).

## 2. Mise en place

Les résultats du checkpoint sont vérifiés : 200 / 403 / 403 / 403.

```bash
REF_ID=<id renvoyé>
curl -s -X PATCH localhost:8001/check-referers/$REF_ID --data-urlencode 'referer=plop\.com'
curl -s -o /dev/null -w "%{http_code}\n" -H 'apikey: CLE-PLOP' -H 'Referer: https://plop.fr/' localhost:8000/carto   # 403 immédiatement
curl -s -X PATCH localhost:8001/check-referers/$REF_ID --data-urlencode 'referer=plop\.fr'
```

## 3. Contournements (tous vérifiés en `200`)

| Referer | Pourquoi ça passe |
|---------|-------------------|
| `https://evil.com/?plop.fr` | La regex n'est pas ancrée : `ngx.re.match` cherche **n'importe où** dans la chaîne |
| `https://plop.fr.evil.com/` | Idem : `plop\.fr` est une sous-chaîne de l'hôte de l'attaquant |
| `https://plop.fr@evil.com/` | Partie *userinfo* de l'URL : l'hôte réel est `evil.com` |
| `https://evil.com/plop.fr/` | Dans le chemin |
| `https://plopXfr.com/` | Uniquement si le referer configuré est `plop.fr` sans échapper le point (le cas de [config.sh](../../config.sh) et d'[API.md](../../API.md)) |

Limite de fond : `Referer` est un en-tête **déclaratif**. Un navigateur ne le falsifie pas, ce qui empêche un **autre site** d'utiliser la clé depuis le navigateur de ses visiteurs. Mais tout script serveur, `curl` ou outil de scraping met la valeur qu'il veut. Le plugin limite donc la réutilisation de la clé dans les pages web d'autrui, il n'authentifie rien. Il faut le compléter par du rate limiting et de la surveillance.

## 4. Revue de code

1. `kong.log.err("error", err)` est appelé **à chaque chargement**, même quand `err` vaut `nil` : on voit `[error] ... errornil` dans les logs. En production, cela pollue les logs, déclenche de fausses alertes et masque les vraies erreurs. `kong.log.info("called-", ...)` est aussi trop bavard.
2. Ordre des tests après `kong.cache:get` : `if not allowed_referer` passe **avant** `if err`. Quand la base est en panne, on a `allowed_referer == nil` et `err ~= nil`, et le client reçoit un `403` au lieu d'un `500` : le `if err` ne sert à rien. Un incident d'infrastructure se fait passer pour un refus d'accès.
3. Unicité : le `unique = true` n'est **pas** garanti avec Cassandra (vérifié). Le second `POST` renvoie `201`, le consumer a deux referers, et c'est l'un des deux, sans garantie lequel, qui s'applique. Ici le plus récent : `plop.fr` se met à renvoyer `403`. [API.md](../../API.md) le reconnaît (« the last creation is the one taken into account »). Pistes :
   - utiliser `PUT /consumers/{c}/check-referer/{id}` ;
   - faire de `consumer` la clé primaire (`endpoint_key`) ;
   - accepter plusieurs referers par consumer, ce qui correspond mieux au besoin.
4. `kong.request.get_header("Referer")` lit un seul en-tête, sans construire la table complète. Elle est insensible à la casse.

Autres remarques possibles :
- le callback de cache reçoit `cache_key` en argument alors qu'il l'ignore ;
- le nom `get_referer_from_db_for_curent_consumer` contient une faute ;
- `matcher` reçoit `nil` quand il n'y a pas de Referer. Ça marche par chance : `ngx.re.match` renvoie `nil`.

## 5. Évolution

Voir [handler.lua](tp4/kong/plugins/check-referer/handler.lua) et [schema.lua](tp4/kong/plugins/check-referer/schema.lua). Points clés :

```lua
-- schema.lua
{ allow_empty_referer = { type = "boolean", required = true, default = false } },
{ match_host_only     = { type = "boolean", required = true, default = false } },
```

```lua
-- handler.lua : extraction de l'hôte, en ignorant le "user@"
local HOST_REGEX = [[^[a-z][a-z0-9+.-]*://(?:[^/?#@]*@)?([^/:?#]+)]]
...
if conf.match_host_only then
  subject = extract_host(request_referer)
  pattern = "^(?:" .. allowed_referer .. ")$"   -- ancrage complet
end
```

Valeurs par défaut à `false` : les instances déjà en base n'ont pas ces champs. Kong applique les valeurs par défaut du schéma à la lecture, et un défaut à `true` changerait le comportement de toutes les routes au déploiement, ce qui pourrait couper des clients. On livre d'abord en mode compatible, on active route par route, puis on peut changer le défaut dans une version majeure.

Checkpoint vérifié avec les deux options à `true` : `200, 200, 200, 403, 403, 403`. L'option inconnue `config.foo=1` renvoie `400`.

Rollback : si on revient à l'ancienne image, l'ancien plugin ignore les champs inconnus à la lecture (vérifié) et le trafic continue. Les options sont simplement sans effet.

## 6. Tests

1. Le **test unitaire** (`01`) appelle directement les fonctions Lua et le schéma, sans Kong ni base : rapide. Le **test d'intégration** (`02`) démarre un vrai Kong avec une vraie base (`each_strategy` = Postgres puis Cassandra) et envoie des requêtes HTTP. `bp` (*blueprints*) insère facilement des entités de test (routes, plugins, consumers, credentials).
2. Voir [01-unit_spec.lua](tp4/spec/check-referer/01-unit_spec.lua) : valeurs par défaut, booléens acceptés, `"yes"` rejeté avec `expected a boolean`, `matcher` avec un referer `nil`.
3. Voir [02-integration_spec.lua](tp4/spec/check-referer/02-integration_spec.lua) : routes `/host-only` et `/empty-ok`.
4. Le test « les contournements passent avec la config par défaut » documente un comportement **connu et assumé**. Si quelqu'un change ce comportement par défaut, le test casse et force la discussion, au lieu d'un changement silencieux en production.
