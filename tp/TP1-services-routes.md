# TP1 : Services et routes

**Objectif** : comprendre comment Kong décide où envoyer une requête, et ce qu'il modifie au passage.

**Les deux briques de base :**
- un **service**, c'est le backend (l'*upstream*) : une URL vers laquelle Kong relaie les requêtes ;
- une **route**, ce sont les règles qui disent quelles requêtes entrantes vont vers quel service (chemin, hôte, méthode…).

Un service peut avoir plusieurs routes.

> Rappel : attendez ~5 s entre une modification et le test (voir [README](README.md)).

## 1. Premier service, première route

```bash
curl -s -X POST localhost:8001/services \
  --data name=httpbin \
  --data url=http://httpbin:8080

curl -s -X POST localhost:8001/services/httpbin/routes \
  --data name=echo \
  --data 'paths[]=/echo'
```

Testez :

```bash
curl -i 'localhost:8000/echo/anything?x=1'
```

✅ **Checkpoint** : vous recevez `200`, et un JSON qui décrit la requête **telle que httpbin l'a reçue**.

**À observer** dans la réponse :

1. Le champ `url` : quel chemin httpbin a-t-il reçu ? Qu'est devenu le préfixe `/echo` ?
2. Les en-têtes `X-Forwarded-*` et `X-Real-Ip` : qui les a ajoutés, et à quoi servent-ils pour le backend ?
3. L'en-tête `Host` reçu par httpbin.
4. Dans les en-têtes de **réponse** : `Via`, `X-Kong-Upstream-Latency`, `X-Kong-Proxy-Latency`. Que mesure chacun ?

## 2. `strip_path`

Le préfixe `/echo` a disparu parce que `strip_path` vaut `true` par défaut. Créez une deuxième route qui le garde :

```bash
curl -s -X POST localhost:8001/services/httpbin/routes \
  --data name=nostrip \
  --data 'paths[]=/anything' \
  --data strip_path=false

curl -s localhost:8000/anything/foo | jq .url
```

> **Question** : quel chemin httpbin reçoit-il cette fois ? Dans quel cas réel choisiriez-vous `strip_path=false` ?

## 3. Router sur l'hôte

```bash
curl -s -X POST localhost:8001/services/httpbin/routes \
  --data name=byhost \
  --data 'hosts[]=api.formation.local'
```

À vous :
1. Appelez `localhost:8000/headers` **sans** en-tête `Host` particulier. Quel code obtenez-vous, et pourquoi ?
2. Appelez-le avec `-H 'Host: api.formation.local'`. Quelle valeur de `Host` httpbin reçoit-il ?
3. Passez `preserve_host` à `true` sur cette route (`PATCH /routes/byhost`) et recommencez. Qu'est-ce qui change ?

> **Question** : dans quel cas un backend a-t-il besoin du `Host` d'origine ?

## 4. Restreindre les méthodes

À vous : modifiez la route `echo` pour qu'elle n'accepte que `GET`, puis vérifiez que :
- `curl -X POST localhost:8000/echo/post` renvoie `404` ;
- `curl localhost:8000/echo/get` renvoie `200`.

> **Question** : pourquoi `404` et pas `405 Method Not Allowed` ?

## 5. Chemins en regex et réécriture

Kong 2.x reconnaît automatiquement un chemin contenant une regex. Les groupes nommés sont capturés.

```bash
curl -s -X POST localhost:8001/services/httpbin/routes \
  --data name=users \
  --data strip_path=false \
  --data-urlencode 'paths[]=/users/(?<id>\d+)$'
```

> Essayez la même commande avec `--data` au lieu de `--data-urlencode`, puis regardez le chemin enregistré (`GET /routes/users`). Que s'est-il passé ?

Pour réécrire l'URL envoyée au backend à partir de la capture, on utilise un premier plugin, `request-transformer` :

```bash
curl -s -X POST localhost:8001/routes/users/plugins \
  --data name=request-transformer \
  --data 'config.replace.uri=/anything/user/$(uri_captures.id)'
```

À vous, vérifiez que :
- `localhost:8000/users/42` arrive chez httpbin sur `/anything/user/42` ;
- `localhost:8000/users/abc` renvoie `404`.

## 6. Le chemin du service

Un service peut lui-même avoir un chemin. Créez un service `status` dont l'URL est `http://httpbin:8080/status`, avec une route `/status`.

À vous : sans regarder la doc, prédisez le code HTTP de `localhost:8000/status/418`, puis vérifiez.

## 7. Bilan

```bash
curl -s localhost:8001/routes | jq '.data[] | {name, paths, hosts, methods, strip_path, preserve_host}'
```

**Questions de synthèse**
1. Une requête peut correspondre à plusieurs routes (essayez `/anything` avec `Host: api.formation.local`). Comment Kong choisit-il ?
2. Quelle différence entre un `404` renvoyé par Kong et un `404` renvoyé par le backend ? Comment les distinguer avec `curl -i` ? (Indice : en-têtes `Server` et `X-Kong-*`)
