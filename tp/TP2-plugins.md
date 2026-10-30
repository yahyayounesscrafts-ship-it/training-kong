# TP2 : Plugins

**Objectif** : ajouter du comportement à la gateway sans toucher au backend, et comprendre la **portée** d'un plugin.

Un plugin peut être attaché :
- **globalement** (`POST /plugins`) : il s'applique à toutes les requêtes ;
- à un **service** (`POST /services/{service}/plugins`) ;
- à une **route** (`POST /routes/{route}/plugins`) ;
- à un **consumer**, ce qu'on verra au TP3.

Prérequis : le service `httpbin` et la route `echo` du TP1.

## 1. Rate limiting sur une route

```bash
curl -s -X POST localhost:8001/routes/echo/plugins \
  --data name=rate-limiting \
  --data config.minute=5 \
  --data config.policy=local
```

À vous : envoyez 6 requêtes d'affilée sur `/echo/get`, et affichez seulement le code de retour :

```bash
for i in 1 2 3 4 5 6; do curl -s -o /dev/null -w "%{http_code} " localhost:8000/echo/get; done
```

✅ **Checkpoint** : `200 200 200 200 200 429`.

**À observer** avec `curl -i` : les en-têtes `RateLimit-*`, `X-RateLimit-*` et `Retry-After`. À quoi servent-ils pour un client bien élevé ?

> **Questions**
> 1. `policy=local` : les compteurs sont en mémoire dans chaque nœud Kong. Que se passe-t-il avec 3 nœuds derrière un load balancer ? Quelles autres valeurs existent pour `policy` ?
> 2. Le `429` a-t-il atteint httpbin ? Comment le prouver ? (Indice : en-têtes de latence)
> 3. Par défaut, le compteur est par adresse IP (`limit_by=ip`). Quel problème cela pose-t-il derrière un NAT d'entreprise ?

## 2. Transformer la requête

```bash
curl -s -X POST localhost:8001/routes/echo/plugins \
  --data name=request-transformer \
  --data 'config.add.headers=X-Formation:kong' \
  --data 'config.add.querystring=source:kong'
```

✅ **Checkpoint** : `curl -s localhost:8000/echo/get | jq '.headers["X-Formation"], .args'` montre l'en-tête et le paramètre ajoutés.

À vous : avec le même plugin, **retirez** l'en-tête `User-Agent` avant qu'il n'arrive au backend (sans supprimer le plugin : modifiez-le avec `PATCH /plugins/{id}`).

## 3. Transformer la réponse, au niveau du service

```bash
curl -s -X POST localhost:8001/services/httpbin/plugins \
  --data name=response-transformer \
  --data 'config.add.headers=X-Powered-By:formation'
```

À vous : vérifiez que l'en-tête apparaît sur **toutes** les routes du service (`/echo`, `/anything`, `/users/42`), mais **pas** sur `/status/200`.

## 4. Un plugin global : identifiant de corrélation

```bash
curl -s -X POST localhost:8001/plugins \
  --data name=correlation-id \
  --data config.header_name=X-Request-ID \
  --data config.echo_downstream=true
```

À vous :
1. Vérifiez que chaque réponse (sur tous les services) porte un `X-Request-ID`.
2. Vérifiez que httpbin reçoit le même identifiant.
3. Envoyez vous-même `-H 'X-Request-ID: test-123'`. Kong le conserve-t-il ?

> **Question** : à quoi sert cet identifiant quand une requête traverse 5 microservices ?

## 5. Précédence : quand deux plugins identiques se rencontrent

Ajoutez un rate-limiting de **100/minute** sur le **service** `httpbin`. La route `echo` a déjà son propre rate-limiting à 5/minute.

> **Question** : quelle limite s'applique sur `/echo/get` ? Et sur `/anything` ? Formulez la règle, puis vérifiez avec les en-têtes `X-RateLimit-Limit-Minute`.

## 6. Observabilité

### Métriques Prometheus

```bash
curl -s -X POST localhost:8001/plugins --data name=prometheus
```

Générez un peu de trafic (dont des `429`), puis :

```bash
curl -s localhost:8001/metrics | grep '^kong_http_status'
curl -s localhost:8001/metrics | grep '^kong_latency_count'
```

> **Question** : avec ces métriques, quelle alerte mettriez-vous en place en production ?

### Logs d'accès structurés

```bash
curl -s -X POST localhost:8001/services/httpbin/plugins \
  --data name=file-log \
  --data config.path=/tmp/kong-formation.log
```

```bash
curl -s localhost:8000/echo/get > /dev/null
docker compose -f docker-compose-local.yml exec kong tail -1 /tmp/kong-formation.log | jq
```

À vous : repérez dans ce log la latence de Kong, celle du backend, le service et la route matchés, et l'IP du client.

> **Question** : en production, pourquoi préférer `http-log`, `tcp-log` ou `syslog` à `file-log` ?

## 7. Bilan

```bash
curl -s localhost:8001/plugins | jq '.data[] | {name, service: .service.id, route: .route.id, consumer: .consumer.id}'
```

Pour chaque plugin, retrouvez sa portée (globale, service ou route).
