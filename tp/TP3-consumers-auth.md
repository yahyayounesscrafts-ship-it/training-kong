# TP3 : Consumers, authentification et ACL

**Objectif** : savoir **qui** appelle l'API, et décider **ce qu'il a le droit de faire**.

Un **consumer** représente un client de l'API (une application, un partenaire, un front…). On lui associe :
- des **credentials** : clé d'API, JWT, OAuth2… Ils servent à l'*authentification* ;
- des **groupes ACL**, qui servent à l'*autorisation* ;
- éventuellement ses **propres plugins** (ex : un quota particulier).

Prérequis : le TP2.

## 1. Protéger un service par clé d'API

```bash
curl -s -X POST localhost:8001/services/httpbin/plugins \
  --data name=key-auth \
  --data 'config.key_names[]=apikey' \
  --data config.hide_credentials=true
```

✅ **Checkpoint** : `curl -i localhost:8000/echo/get` renvoie `401` avec `"No API key found in request"`.

## 2. Créer des consumers et leurs clés

```bash
curl -s -X POST localhost:8001/consumers --data username=alice --data custom_id=client-001
curl -s -X POST localhost:8001/consumers --data username=bob

# clé choisie
curl -s -X POST localhost:8001/consumers/alice/key-auth --data key=CLE-ALICE
# clé générée par Kong
curl -s -X POST localhost:8001/consumers/bob/key-auth | jq -r .key
```

À vous :
1. Appelez `/echo/get` avec l'en-tête `apikey: CLE-ALICE`. Quels en-têtes `X-Consumer-*` httpbin reçoit-il ? À quoi peuvent-ils servir au backend ?
2. L'en-tête `apikey` est-il transmis à httpbin ? Pourquoi ? (Voir `hide_credentials`.)
3. Passez la clé en paramètre de requête (`?apikey=CLE-ALICE`). Ça marche ? Quel risque cela pose-t-il (pensez aux logs, à l'historique du navigateur…) ? Comment l'interdire ? (Indice : `config.key_in_query`)
4. Essayez une clé invalide. Le message d'erreur est-il le même que sans clé ? Est-ce une bonne chose ?

> **Question** : la clé d'alice est stockée en clair dans la base de Kong (`GET /consumers/alice/key-auth`). Qu'en pensez-vous ? Quelles alternatives connaissez-vous (JWT, OAuth2, mTLS…) ?

## 3. Autorisation par groupes (ACL)

On veut que seuls les clients du groupe `admin` puissent appeler la route `nostrip` (`/anything`).

```bash
curl -s -X POST localhost:8001/consumers/alice/acls --data group=admin
curl -s -X POST localhost:8001/consumers/bob/acls --data group=lecteur

curl -s -X POST localhost:8001/routes/nostrip/plugins \
  --data name=acl \
  --data 'config.allow[]=admin' \
  --data config.hide_groups_header=true
```

À vous, vérifiez que :
- alice obtient `200` sur `/anything` ;
- bob obtient `403` sur `/anything`, mais `200` sur `/echo/get`.

> **Question** : que se passe-t-il si on met le plugin `acl` sur une route **sans** plugin d'authentification ? Testez sur la route `status`.

## 4. Un quota propre à un consumer

bob est un client « gratuit » : on le limite à 2 requêtes par minute, quelle que soit la route.

```bash
curl -s -X POST localhost:8001/plugins \
  --data name=rate-limiting \
  --data consumer.username=bob \
  --data config.minute=2 \
  --data config.policy=local
```

À vous :
1. Sur `/echo/get` (qui a déjà sa limite à 5/minute), combien de requêtes passent pour bob ? Et pour alice ?
2. Sur `/status/200`, bob est-il limité ? Expliquez. (Indice : Kong sait-il que c'est bob qui appelle ?)

> **Question** : complétez la règle de précédence du TP2 avec le consumer. Que l'emporte-t-il : un plugin consumer, ou un plugin route ?

## 5. Appeler l'API depuis un navigateur : CORS

Le fichier [front/index.html](../front/index.html) fait un `fetch` vers `http://localhost:8000/ratelimited` avec l'en-tête `apikey: CLE-FRONT`. Mettons-le en place.

```bash
curl -s -X POST localhost:8001/services --data name=front-api --data url=http://httpbin:8080/anything
curl -s -X POST localhost:8001/services/front-api/routes --data name=ratelimited --data 'paths[]=/ratelimited'
curl -s -X POST localhost:8001/services/front-api/plugins --data name=key-auth --data 'config.key_names[]=apikey'
curl -s -X POST localhost:8001/consumers/alice/key-auth --data key=CLE-FRONT
```

Servez le front sur une autre origine :

```bash
cd front && python3 -m http.server 3000
```

Ouvrez http://localhost:3000, puis l'onglet *Réseau* des outils de développement.

> **Question** : le `fetch` échoue. Quelle requête le navigateur envoie-t-il **avant** le `GET` ? Pourquoi échoue-t-elle ?

Vous pouvez reproduire la même requête avec curl :

```bash
curl -i -X OPTIONS localhost:8000/ratelimited \
  -H 'Origin: http://localhost:3000' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: apikey'
```

À vous : ajoutez le plugin `cors` sur la route `ratelimited`. N'autorisez que l'origine `http://localhost:3000`, l'en-tête `apikey` et la méthode `GET`. Rechargez la page : le `fetch` doit réussir.

> **Questions**
> 1. Refaites le preflight avec `Origin: http://evil.com`. Kong renvoie `200`… La protection est-elle cassée ? Qui applique réellement la politique CORS ?
> 2. Le module [infra/modules/route/main.tf](../infra/modules/route/main.tf) configure `cors` avec `origins: ["*"]` **et** `credentials: true`, une combinaison que les navigateurs refusent normalement. Reconfigurez votre plugin de cette façon, refaites le preflight avec `Origin: http://evil.com` et regardez `Access-Control-Allow-Origin`. Que fait Kong ? Est-ce une configuration sûre ?
> 3. La clé `CLE-FRONT` est visible dans le code source de la page. Est-ce encore un secret ? Qu'est-ce qui empêche n'importe quel site de la réutiliser ? → C'est le problème que résout (en partie) le plugin du TP4.
