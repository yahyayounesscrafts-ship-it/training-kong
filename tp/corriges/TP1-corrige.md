# Corrigé TP1 : Services et routes

## 1. Premier service

- `url` = `http://httpbin:8080/anything?x=1` : le préfixe `/echo` a été retiré (`strip_path=true` par défaut).
- `X-Forwarded-For`, `-Host`, `-Port`, `-Proto`, `-Path`, `-Prefix`, `X-Real-Ip` : ajoutés par Kong pour que le backend connaisse le client et l'URL d'origine (logs, génération de liens absolus, redirections).
- `Host: httpbin:8080` : par défaut Kong envoie l'hôte de l'upstream.
- `Via: kong/2.8.5` ; `X-Kong-Upstream-Latency` = temps de réponse du backend ; `X-Kong-Proxy-Latency` = temps passé dans Kong (plugins, routage). La toute première requête est plus lente (cache froid).

## 2. `strip_path=false`

```bash
curl -s localhost:8000/anything/foo | jq .url   # "http://httpbin:8080/anything/foo"
```
Utile quand le backend attend le chemin complet (ex : les routes `/forward/1.0/find` du TP5).

## 3. Routage par hôte

```bash
curl -s -o /dev/null -w "%{http_code}\n" localhost:8000/headers                 # 404 : aucune route ne matche (pas de path, pas le bon host)
curl -s -H 'Host: api.formation.local' localhost:8000/headers | jq '.headers.Host'  # ["httpbin:8080"]

curl -s -X PATCH localhost:8001/routes/byhost --data preserve_host=true
sleep 5
curl -s -H 'Host: api.formation.local' localhost:8000/headers | jq '.headers.Host'  # ["api.formation.local"]
```
Besoin du `Host` d'origine : backend multi-tenant / virtual hosts, URLs absolues, cookies de domaine.

## 4. Méthodes

```bash
curl -s -X PATCH localhost:8001/routes/echo --data 'methods[]=GET'
sleep 5
curl -s -o /dev/null -w "%{http_code}\n" -X POST localhost:8000/echo/post   # 404
curl -s -o /dev/null -w "%{http_code}\n" localhost:8000/echo/get            # 200
```
`404` : la méthode est un **critère de routage** ; une requête qui ne remplit pas tous les critères ne correspond à aucune route. Kong ne sait pas qu'une « autre méthode » aurait marché.

## 5. Regex

Avec `--data`, le `+` est décodé en espace : la route enregistrée est `/users/(?<id>\d )$` et ne matche plus rien. D'où `--data-urlencode`.

```bash
curl -s localhost:8000/users/42 | jq .url                                   # ".../anything/user/42"
curl -s -o /dev/null -w "%{http_code}\n" localhost:8000/users/abc            # 404
```

## 6. Chemin du service

```bash
curl -s -X POST localhost:8001/services --data name=status --data url=http://httpbin:8080/status
curl -s -X POST localhost:8001/services/status/routes --data name=status --data 'paths[]=/status'
sleep 5
curl -s -o /dev/null -w "%{http_code}\n" localhost:8000/status/418   # 418
```
Chemin upstream = chemin du service + reste après `strip_path` : `/status` + `/418`.

## 7. Synthèse

1. Avec `Host: api.formation.local` et `/anything/z`, deux routes candidates (`byhost` et `nostrip`) : c'est `byhost` qui gagne (`url` = `http://api.formation.local/anything/z`). Kong 2.x trie les routes par nombre de critères, puis donne la priorité aux hôtes, puis aux chemins (les plus longs d'abord ; les regex selon `regex_priority`).
2. `404` de Kong : `Server: kong/2.8.5` + `X-Kong-Response-Latency`, pas de `Via`. `404` du backend : `Via: kong/2.8.5` + `X-Kong-Upstream-Latency`.
