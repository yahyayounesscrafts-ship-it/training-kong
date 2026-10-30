# Formation Kong : travaux pratiques

Ces TPs s'appuient sur le repo : une gateway Kong 2.8 (base Cassandra), un plugin maison `check-referer` écrit en Lua, et une configuration « infra as code » en Terraform/Terragrunt.

| TP | Sujet | Durée indicative |
|----|-------|------------------|
| [TP0](TP0-mise-en-route.md) | Mise en route de la stack | 30 min |
| [TP1](TP1-services-routes.md) | Services et routes : comment Kong aiguille une requête | 1 h |
| [TP2](TP2-plugins.md) | Plugins : rate limiting, transformations, observabilité | 1 h |
| [TP3](TP3-consumers-auth.md) | Consumers, authentification par clé, ACL, CORS | 1 h 15 |
| [TP4](TP4-plugin-custom.md) | Le plugin maison `check-referer` : lecture, revue, évolution, tests | 2 h |
| [TP5](TP5-infra-as-code.md) | Configurer Kong avec Terraform et Terragrunt | 1 h 15 |

Les TPs s'enchaînent : chacun réutilise ce qui a été créé dans le précédent. Les corrigés sont dans [corriges/](corriges/).

## Prérequis

- Docker Desktop (ou Docker Engine + plugin `docker compose`)
- `curl`, et idéalement `jq` pour lire le JSON (`brew install jq` / `apt install jq`)
- Pour le TP4 : [pongo](https://github.com/Kong/kong-pongo#installation)

Pour vérifier qu'une machine est prête : `bash tp/daas/check-env.sh`. Pour une formation sur le DaaS Ambient IT, voir [daas/README.md](daas/README.md).

## À savoir avant de commencer

**Les modifications ne sont pas instantanées.** Avec une base de données, chaque nœud Kong relit la configuration toutes les 5 secondes (`db_update_frequency`). Après un appel à l'Admin API, **attendez ~5 secondes** avant de tester. Si une route « n'existe pas » juste après sa création, c'est probablement ça.

**Encodez vos valeurs.** `curl --data` envoie du `application/x-www-form-urlencoded` : un `+` devient un espace. Dès qu'une valeur contient `+`, `&`, `%` ou un espace (ex : une regex), utilisez `--data-urlencode`.

**Deux ports, deux rôles.**

| URL | Rôle |
|-----|------|
| `http://localhost:8000` | Proxy : là où arrivent les clients de vos APIs |
| `http://localhost:8001` | Admin API : là où on configure Kong (jamais exposée publiquement) |
| `http://localhost:1337` | Konga, une interface graphique pour l'Admin API |

**Repartir de zéro** à tout moment :

```bash
docker compose -f docker-compose-local.yml down -v
```

puis refaire le [TP0](TP0-mise-en-route.md).
