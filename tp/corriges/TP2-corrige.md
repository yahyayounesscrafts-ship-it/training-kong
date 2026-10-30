# Corrigé TP2 : Plugins

## 1. Rate limiting

```bash
for i in 1 2 3 4 5 6; do curl -s -o /dev/null -w "%{http_code} " localhost:8000/echo/get; done
# 200 200 200 200 200 429
```

En-têtes : `X-RateLimit-Limit-Minute: 5`, `X-RateLimit-Remaining-Minute`, `RateLimit-Limit/Remaining/Reset` (format standardisé), `Retry-After` sur le 429. Un client bien élevé attend `Retry-After` secondes au lieu de réessayer en boucle.

1. `policy=local` + 3 nœuds : chaque nœud compte de son côté, donc la limite réelle peut aller jusqu'à 3 × 5. Autres valeurs : `cluster` (compteurs en base, coûteux en écritures) et `redis` (compteur partagé et rapide, la solution habituelle en production).
2. Le 429 n'a pas atteint httpbin : il porte `X-Kong-Response-Latency` (réponse générée par Kong) et pas `X-Kong-Upstream-Latency`.
3. Derrière un NAT, tous les salariés partagent une seule IP et donc un seul quota. Solution : `limit_by=consumer` (TP3), `credential` ou `header`.

## 2. request-transformer

```bash
curl -s localhost:8000/echo/get | jq '.headers["X-Formation"], .args'   # ["kong"]  {"source":["kong"]}

PLUGIN_ID=$(curl -s localhost:8001/routes/echo/plugins | jq -r '.data[] | select(.name=="request-transformer") | .id')
curl -s -X PATCH localhost:8001/plugins/$PLUGIN_ID --data 'config.remove.headers=User-Agent'
sleep 5
curl -s localhost:8000/echo/get | jq '.headers["User-Agent"]'           # null
```

Attention : un `PATCH` sur `config.remove.headers` **remplace** le tableau, il ne l'enrichit pas.

## 3. response-transformer sur le service

`X-Powered-By: formation` apparaît sur `/echo`, `/anything` et `/users/42` (routes du service `httpbin`), mais pas sur `/status/200` (service `status`).

## 4. correlation-id global

1. Toutes les réponses portent `X-Request-ID: <uuid>#<compteur>`, y compris sur `/status`.
2. httpbin reçoit `X-Request-Id` avec la même valeur.
3. Avec `-H 'X-Request-ID: test-123'`, Kong conserve la valeur fournie. Il n'en génère une que si l'en-tête est absent.

Usage : propager l'identifiant de service en service et le logger partout, pour reconstituer le parcours d'une requête (tracing du pauvre, en attendant OpenTelemetry).

## 5. Précédence

```bash
curl -s -X POST localhost:8001/services/httpbin/plugins \
  --data name=rate-limiting --data config.minute=100 --data config.policy=local
sleep 5
curl -si localhost:8000/echo/get  | grep -i x-ratelimit-limit-minute   # 5
curl -si localhost:8000/anything  | grep -i x-ratelimit-limit-minute   # 100
```

Règle : pour un même plugin, **une seule instance s'exécute**, celle dont la portée est la plus spécifique. Ici route > service > global. Le TP3 ajoute le consumer.

## 6. Observabilité

```bash
curl -s localhost:8001/metrics | grep '^kong_http_status'
# kong_http_status{service="httpbin",route="echo",code="200"} 7
# kong_http_status{service="httpbin",route="echo",code="429"} 2
```

Sur Kong 2.8, les métriques s'appellent `kong_http_status`, `kong_latency_bucket/_count/_sum`, `kong_bandwidth`, `kong_datastore_reachable`, etc. (pas `kong_http_requests_total`, qui est le nom en 3.x).

Alertes possibles :
- taux de 5xx par service ;
- p95 de `kong_latency{type="upstream"}` ;
- `kong_datastore_reachable == 0` ;
- hausse anormale des 429 ou des 401 (client cassé, tentative d'abus).

file-log : une ligne JSON par requête, avec `latencies.kong`, `latencies.proxy` (le backend), `latencies.request`, `service`, `route`, `client_ip`, `request`, `response`, `upstream_uri`.

Pourquoi `http-log`, `tcp-log` ou `syslog` en production : `file-log` fait des écritures disque **bloquantes** dans le worker nginx, impose de gérer la rotation, et oblige à collecter le fichier conteneur par conteneur. Les autres envoient les logs directement vers la stack de logs (ELK, Loki…).

## 7. Bilan

```bash
curl -s localhost:8001/plugins | jq '.data[] | {name, service: .service.id, route: .route.id, consumer: .consumer.id}'
```

Portée attendue : `correlation-id` et `prometheus` globaux ; `response-transformer`, `rate-limiting` (100) et `file-log` sur le service ; `rate-limiting` (5) et `request-transformer` sur les routes `echo` et `users`.
