# Corrigé TP3 : Consumers, authentification et ACL

## 2. Consumers et clés

```bash
curl -s -H 'apikey: CLE-ALICE' localhost:8000/echo/get | jq '.headers | with_entries(select(.key | startswith("X-Consumer") or startswith("X-Credential") or . == "Apikey"))'
```

1. httpbin reçoit `X-Consumer-Id`, `X-Consumer-Username: alice`, `X-Consumer-Custom-Id: client-001` et `X-Credential-Identifier`. Le backend sait **qui** appelle sans gérer l'authentification lui-même (logs, facturation, données par client). Il doit en revanche n'être joignable **que** via Kong, sinon n'importe qui peut forger ces en-têtes.
2. `apikey` n'est pas transmise (`hide_credentials=true`) : le backend n'a pas besoin du secret, et ne risque donc pas de le logger.
3. `?apikey=CLE-ALICE` renvoie `200`. Risque : la clé finit dans les logs d'accès (Kong, proxies, CDN), l'historique du navigateur et le `Referer` envoyé aux sites tiers. Pour l'interdire : `config.key_in_query=false`.
4. Une clé invalide renvoie `401 {"message":"Invalid authentication credentials"}`, contre `"No API key found in request"` sans clé. C'est acceptable : le message ne dit rien sur les clés existantes.

Clés en clair dans la base : en Kong OSS 2.x, `key-auth` stocke les clés sans les hacher. Il faut protéger l'accès à la base et à l'Admin API. Alternatives : JWT (Kong ne stocke que le secret ou la clé publique), OAuth2/OIDC (avec un IdP externe), mTLS.

## 3. ACL

```bash
curl -s -o /dev/null -w "%{http_code}\n" -H 'apikey: CLE-ALICE' localhost:8000/anything   # 200
curl -s -o /dev/null -w "%{http_code}\n" -H "apikey: $BOB_KEY" localhost:8000/anything     # 403 "You cannot consume this service"
curl -s -o /dev/null -w "%{http_code}\n" -H "apikey: $BOB_KEY" localhost:8000/echo/get     # 200
```

ACL sans authentification : le plugin ne sait pas qui appelle, donc il refuse tout, avec un `401` ou `403` selon le cas. Pour le vérifier sur la route `status` :

```bash
curl -s -X POST localhost:8001/routes/status/plugins --data name=acl --data 'config.allow[]=admin'
sleep 5
curl -si localhost:8000/status/200 | head -1
```

L'ACL **dépend** d'un plugin d'authentification placé avant elle : priorité de `acl` = 950, de `key-auth` = 1003.

## 4. Quota par consumer

1. Sur `/echo/get` : bob `200 200 429 429`, soit 2 requêtes ; alice `200 ×5 puis 429`, soit 5 requêtes. Le plugin consumer **l'emporte** sur le plugin route.
2. Sur `/status/200`, bob n'est pas limité : le service `status` n'a pas de `key-auth`, Kong ne sait donc pas que c'est bob.

Précédence complète, en Kong 2.x, de la plus forte à la plus faible :

1. consumer + route + service
2. consumer + route
3. consumer + service
4. route + service
5. consumer
6. route
7. service
8. global

## 5. CORS

Le navigateur envoie d'abord un **preflight** `OPTIONS` (méthode inhabituelle ou en-tête non standard comme `apikey`). Ce preflight ne porte **pas** la clé : `key-auth` répond `401` et le navigateur bloque.

```bash
curl -s -X POST localhost:8001/routes/ratelimited/plugins \
  --data name=cors \
  --data 'config.origins[]=http://localhost:3000' \
  --data 'config.headers[]=apikey' \
  --data 'config.methods[]=GET'
```

Le plugin `cors` (priorité 2000) répond au preflight **avant** `key-auth`. Autre solution, moins propre : `key-auth` avec `config.run_on_preflight=false`.

1. Avec `Origin: http://evil.com`, Kong renvoie quand même `200` et `Access-Control-Allow-Origin: http://localhost:3000`. Ce n'est pas une faille : c'est le **navigateur** qui compare cette valeur à l'origine de la page et bloque. CORS protège les utilisateurs d'un navigateur, **pas l'API** : `curl` ignore tout ça.
2. Avec `origins: ["*"]` et `credentials: true`, Kong **renvoie l'origine reçue** (`Access-Control-Allow-Origin: http://evil.com`) avec `Access-Control-Allow-Credentials: true`. Tout site peut alors appeler l'API avec les cookies de l'utilisateur. C'est la pire combinaison : il faut lister les origines, ou retirer `credentials`.
3. `CLE-FRONT` n'est plus un secret (visible dans le source). Elle **identifie** le front sans l'**authentifier** : n'importe quel site ou script peut la réutiliser. D'où le plugin `check-referer` du TP4, qui ne gêne que les navigateurs, plus un rate limiting.
