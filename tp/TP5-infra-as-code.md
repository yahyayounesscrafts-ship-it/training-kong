# TP5 : Configurer Kong avec Terraform et Terragrunt

**Objectif** : arrêter de configurer Kong à coups de `curl`, versionner sa configuration, et en connaître les limites.

**Outils** :
- **Terraform** pilote l'Admin API via le provider [`philips-labs/kong`](https://registry.terraform.io/providers/philips-labs/kong/latest/docs) ;
- **Terragrunt** évite de dupliquer la configuration entre environnements (*tenants* : `local`, `snap`, `recette`).

Les deux tournent dans un conteneur, déclaré dans `docker-compose-local.yml` et branché sur le même réseau que Kong.

## 1. Lire la structure (20 min)

```
infra/
├── modules/             # le "comment" : du Terraform réutilisable
│   ├── kong/            # expose l'Admin API derrière le proxy, plugin prometheus global
│   ├── mappy/           # point d'entrée d'une API métier → appelle service/
│   ├── service/         # un kong_service + N routes → appelle route/
│   └── route/           # une kong_route + ses plugins (key-auth, acl, cors, rate-limiting…)
└── tenants/             # le "quoi" et le "où"
    ├── common/*.hcl     # la définition des APIs, identique pour tous les environnements
    ├── local/
    │   ├── local.hcl    # les valeurs propres à l'environnement (domaine, URL de l'Admin API…)
    │   ├── terragrunt.hcl        # unité "kong"
    │   └── geocode/terragrunt.hcl  # unité "geocode" = module mappy + common/geocode.hcl + local.hcl
    ├── snap/
    └── recette/
```

Questions :
1. Ouvrez [common/geocode.hcl](../infra/tenants/common/geocode.hcl). Combien de routes et de plugins vont être créés ? Avec quels `hosts` (voir `formatlist` dans [modules/route/main.tf](../infra/modules/route/main.tf)) ?
2. Que fait `read_terragrunt_config` ? Et `merge(...)` : dans quel ordre les valeurs sont-elles écrasées ?
3. Pourquoi séparer `common/` des tenants ?
4. Le module `route` active le plugin `check-referer` mais ne crée aucun referer. Qui s'en charge ?

## 2. Revue : trouvez les bugs avant de lancer (15 min)

Ce code n'a jamais tourné en local. En lisant uniquement les fichiers, trouvez :
1. Pourquoi `infra/tenants/local/geocode` ne peut pas fonctionner (comparez avec `infra/tenants/snap/geocode`).
2. Pourquoi l'unité racine du tenant `snap` échouerait, ou demanderait une valeur de manière interactive (comparez les noms de variables entre [snap.hcl](../infra/tenants/snap/snap.hcl) et [modules/kong/variables.tf](../infra/modules/kong/variables.tf)).
3. Pourquoi `make init-local` répond « Nothing to be done », sans rien lancer (voir le [Makefile](../Makefile)).
4. En local, le backend est `httpbin:8080`. Pourquoi le module `service` ne permet-il pas de le cibler ?

## 3. Appliquer l'unité racine du tenant local

```bash
docker compose -f docker-compose-local.yml run --rm terragrunt \
  terragrunt init --terragrunt-working-dir /data/tenants/local
docker compose -f docker-compose-local.yml run --rm terragrunt \
  terragrunt plan --terragrunt-working-dir /data/tenants/local
docker compose -f docker-compose-local.yml run --rm terragrunt \
  terragrunt apply --terragrunt-working-dir /data/tenants/local
```

> ⚠️ N'utilisez pas `run-all` à ce stade : il appliquerait aussi les sous-dossiers, qui sont cassés (partie 2).

**Résultat attendu : une erreur.** Lisez-la.

> **Question** : pourquoi Terraform ne peut-il pas créer le plugin `prometheus` ? Proposez deux façons de s'en sortir.

Réglez le problème **sans** supprimer le plugin existant :

```bash
PROM_ID=$(curl -s localhost:8001/plugins | jq -r '.data[] | select(.name=="prometheus") | .id')
docker compose -f docker-compose-local.yml run --rm terragrunt \
  terragrunt import kong_plugin.global_prometheus_plugin $PROM_ID --terragrunt-working-dir /data/tenants/local
```

Relancez `plan`, puis `apply`.

✅ **Checkpoint** : l'Admin API est accessible **via le proxy**, protégée par une clé :

```bash
curl -i localhost:8000/admin/status                           # 401
curl -s -H 'apikey: UNE-CLE-KONG' localhost:8000/admin/status  # 200
```

> **Questions**
> 1. Relancez `plan` sans rien changer. Terraform veut **encore** modifier la route (`methods`). Pourquoi ce diff permanent est-il un problème en CI ?
> 2. Exposer l'Admin API derrière le proxy avec une simple clé d'API : bonne ou mauvaise idée ?

## 4. Réparer et déployer une API métier (30 min)

À vous : faites fonctionner `infra/tenants/local/geocode` contre httpbin.

1. Corrigez le bug de la partie 2.1.
2. Dans `local.hcl`, mettez `domain = "formation.local"`, `service_host = "httpbin"` et `filelog_path = "/tmp/kong-gateway.log"`.
3. Ajoutez une variable `service_port` (défaut `80`) au module `mappy`, transmise au module `service`. Les tenants `snap` et `recette` ne doivent **pas** être impactés : vérifiez-le en relisant leur configuration.
4. httpbin ne répond que sur `/anything/...`. Pour le tenant local **uniquement**, surchargez `host_path` à `/anything`, sans toucher à `common/geocode.hcl`.

```bash
docker compose -f docker-compose-local.yml run --rm terragrunt \
  terragrunt init --terragrunt-working-dir /data/tenants/local/geocode
docker compose -f docker-compose-local.yml run --rm terragrunt \
  terragrunt apply --terragrunt-working-dir /data/tenants/local/geocode
```

✅ **Checkpoint** : 25 ressources créées, et :

```bash
curl -i -H 'Host: api-search.formation.local' localhost:8000/forward/1.0/find   # 401
```

> **Question** : relisez la question CORS du TP3. Que renvoie un preflight avec `Origin: http://evil.com` sur cette route ? Que faudrait-il changer dans le module `route` ?

## 5. Gérer les consumers en code (30 min)

Pour l'instant, rien ne peut appeler `/forward/1.0/find` : il faut un consumer avec une clé, le groupe ACL `front-iti` et un referer.

À vous : créez un module `infra/modules/consumers` et une unité `infra/tenants/local/consumers` qui déclarent une liste de consumers, chacun avec :
- une clé d'API ;
- une liste de groupes ACL ;
- un referer, optionnel (pas de referer si la valeur est vide).

Indices :
- `kong_consumer` crée le consumer.
- `kong_consumer_plugin_config` fait un `POST /consumers/{id}/{plugin_name}` avec `config_json`. Cela fonctionne pour `key-auth`… mais aussi pour **n'importe quel endpoint** imbriqué sous un consumer. Pensez à l'API générée par `daos.lua` au TP4.
- Ce provider n'a pas de ressource dédiée aux ACL.

✅ **Checkpoint** :

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  -H 'Host: api-search.formation.local' -H 'apikey: <votre clé>' \
  -H 'Referer: http://www.formation.local/' \
  localhost:8000/forward/1.0/find      # 200
```

> **Questions**
> 1. Avec le plugin d'origine, quelle regex de referer faut-il écrire pour autoriser `http://www.formation.local/` **sans** ouvrir les contournements du TP4 ?
> 2. Modifiez le referer et lancez `plan`. Terraform fait-il une mise à jour, ou une destruction suivie d'une création ? Quel impact pour les utilisateurs pendant le déploiement ?
> 3. La clé d'API est en clair dans le code Terraform **et** dans le state. Comment feriez-vous en vrai ?

## 6. Les limites : le drift (15 min)

Modifiez « à la main » le rate-limiting d'une route geocode :

```bash
RL_ID=$(curl -s localhost:8001/plugins | jq -r '[.data[] | select(.name=="rate-limiting" and .config.minute==100)][0].id')
curl -s -X PATCH localhost:8001/plugins/$RL_ID --data config.minute=9999
```

Lancez `plan` sur l'unité geocode et lisez attentivement la sortie.

> **Questions**
> 1. Terraform **voit-il** la modification ? La **corrige-t-il** ? Pourquoi ? (Comparez `config_json` et `computed_config`.)
> 2. Quelle règle d'équipe en découle (Konga, `curl`…) ?
> 3. Kong propose aussi **decK**, un outil déclaratif (un fichier YAML qui décrit l'état complet). Quels avantages et inconvénients par rapport à Terraform ?

## 7. Nettoyage

```bash
docker compose -f docker-compose-local.yml run --rm terragrunt \
  terragrunt destroy --terragrunt-working-dir /data/tenants/local/geocode
```

> **Question** : le consumer `front-iti`, si vous l'aviez créé à la main, a-t-il été supprimé ? Pourquoi ?
