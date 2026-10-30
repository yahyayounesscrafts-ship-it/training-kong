# Corrigé TP5 : Terraform et Terragrunt

Les fichiers modifiés ou ajoutés sont dans [tp5/infra/](tp5/infra/), avec la même arborescence que `infra/`. Pour les appliquer : `cp -R tp/corriges/tp5/infra .`

Alias utilisé ci-dessous :

```bash
TG="docker compose -f docker-compose-local.yml run --rm terragrunt terragrunt"
```

## 1. Structure

1. `common/geocode.hcl` déclare 4 routes : forward et reverse, chacune en front et en back. Pour chaque route, jusqu'à 6 plugins : `acl`, `check-referer`, `key-auth`, `rate-limiting`, `file-log`, `cors`. Les hôtes sont `api-search.<domaine>` et `api-search-batch.<domaine>`, via `formatlist("%s.${var.domain}", ...)`. Total : 1 service + 4 routes + 20 plugins = **25 ressources** (vérifié).
2. `read_terragrunt_config` lit un autre fichier `.hcl` et expose ses `inputs`. `merge(a, b, c)` : en cas de clé commune, **c'est le dernier argument qui gagne**.
3. `common/` décrit les APIs une seule fois, les tenants ne fournissent que ce qui change d'un environnement à l'autre (DRY). Une nouvelle route se déclare à un seul endroit.
4. Personne : les referers sont des données **par consumer** (entité du plugin), pas de la configuration de route. Voir la partie 5.

## 2. Bugs

1. `tenants/local/*/terragrunt.hcl` lisent `../snap.hcl`, qui n'existe pas dans `local/` (copier-coller depuis `snap/`). Il faut `../local.hcl`.
2. `snap.hcl` et `recette.hcl` définissent `kongadmin_uri`, alors que le module attend `kong_admin_uri`. La variable n'a pas de valeur par défaut : Terraform la demande en interactif, ou échoue en non-interactif.
3. Le Makefile déclare `.PHONY: init-local`, mais la cible s'appelle `init-snap-local`. `make init-local` n'a donc aucune recette : « Nothing to be done ». Même problème pour `apply-local`. Les cibles appellent aussi `docker-compose` (v1).
4. `modules/service/main.tf` code en dur `port = 80`. Aucune variable ne permet de cibler `httpbin:8080`.

## 3. Unité racine

L'erreur attendue (vérifiée) :

```
UNIQUE violation detected on '{consumer=null,name="prometheus",route=null,service=null}'
```

Le plugin `prometheus` global existe déjà (créé au TP2) et Kong n'en accepte qu'un par portée. Deux façons de s'en sortir :
- le supprimer à la main et relancer ;
- **l'importer** dans le state, ce qui préserve l'existant (c'est ce qui est demandé).

```bash
PROM_ID=$(curl -s localhost:8001/plugins | jq -r '.data[] | select(.name=="prometheus") | .id')
$TG import kong_plugin.global_prometheus_plugin $PROM_ID --terragrunt-working-dir /data/tenants/local
$TG apply --terragrunt-working-dir /data/tenants/local
```

Checkpoint vérifié : `/admin/status` renvoie `401` sans clé et `200` avec `apikey: UNE-CLE-KONG`.

1. Diff permanent sur `methods` : le provider compare des listes **ordonnées** alors que Kong les renvoie dans un autre ordre. En CI, un `plan` n'est jamais vide : on ne peut plus utiliser `-detailed-exitcode` pour détecter un vrai changement, et les reviewers s'habituent à ignorer les diffs. Contournements :
   - trier les valeurs dans le code dans l'ordre renvoyé par Kong ;
   - `lifecycle { ignore_changes = [methods] }` ;
   - monter de version de provider.
2. Mauvaise idée : l'Admin API donne **le contrôle total** de la gateway. Une clé statique, sans rotation, transmise dans un en-tête, et la même pour tout le monde, c'est trop faible. Il vaut mieux garder l'Admin API sur un réseau privé ou en `127.0.0.1`, ou au minimum ajouter une ACL, une restriction d'IP et du mTLS.

## 4. API métier

Fichiers : [local.hcl](tp5/infra/tenants/local/local.hcl), [geocode/terragrunt.hcl](tp5/infra/tenants/local/geocode/terragrunt.hcl), [modules/mappy](tp5/infra/modules/mappy/), [modules/service](tp5/infra/modules/service/).

```hcl
# modules/service/variables.tf
variable "port" {
  type    = number
  default = 80        # snap et recette ne passent rien : comportement inchangé
}
# modules/service/main.tf :  port = var.port
# modules/mappy : variable "service_port" (défaut 80), transmise avec  port = var.service_port
```

```hcl
# tenants/local/geocode/terragrunt.hcl
inputs = merge(
  local.tenant.inputs,
  local.service.inputs,
  { host_path = "/anything" }   # en dernier : écrase la valeur de common/geocode.hcl
)
```

Checkpoint vérifié : 25 ressources, et `401` sans clé.

CORS : un preflight avec `Origin: http://evil.com` renvoie `Access-Control-Allow-Origin: http://evil.com` et `Access-Control-Allow-Credentials: true` (vérifié). Avec `origins = ["*"]` et `credentials = true`, Kong renvoie n'importe quelle origine. Il faut une liste d'origines par tenant (variable), ou `credentials = false`.

## 5. Consumers en code

Fichiers : [modules/consumers/](tp5/infra/modules/consumers/), [tenants/local/consumers/terragrunt.hcl](tp5/infra/tenants/local/consumers/terragrunt.hcl).

L'idée clé : `kong_consumer_plugin_config` fait `POST /consumers/{id}/{plugin_name}`. Elle fonctionne donc pour :
- `key-auth` ;
- `acls`, puisque le provider n'a pas de ressource ACL : une ressource par couple (consumer, groupe), via un `for_each` sur une map aplatie ;
- **`check-referer`**, l'endpoint généré par `daos.lua` au TP4.

```bash
$TG init  --terragrunt-working-dir /data/tenants/local/consumers
$TG apply --terragrunt-working-dir /data/tenants/local/consumers
```

Checkpoint vérifié (`200`) avec `apikey: CLE-TF-ITI`, `Referer: http://www.formation.local/`, sur `/forward/1.0/find` et `/reverse/1.0/find`. `Referer: http://evil.com/www.formation.local` renvoie `403`.

1. Avec le plugin d'origine, la regex est appliquée à **l'URL complète** : `^https?://www\.formation\.local(/|$)`. Attention : `^www\.formation\.local$` renvoie `403` (vérifié), parce que le Referer commence par `http://`. Avec le plugin corrigé et `match_host_only=true`, on écrirait simplement `www\.formation\.local`.
2. **Destruction puis recréation** (`-/+ ... forces replacement`, vérifié). Entre les deux, le consumer n'a plus de referer et reçoit des `403`. La coupure est brève, mais réelle. C'est une limite de la ressource générique, qui ne sait pas faire de mise à jour.
3. Secrets en clair dans le code et dans le state :
   - les passer en variables `sensitive`, lues depuis un coffre (Vault, SOPS, secrets de la CI) ;
   - stocker le state dans un backend chiffré, à accès restreint ;
   - ou laisser Kong générer les clés et les distribuer par un autre canal.

## 6. Drift

Résultat vérifié du `plan` :

```
Note: Objects have changed outside of Terraform
  ~ computed_config = { ~ minute = 100 -> 9999 }
...
No changes. Your infrastructure matches the configuration.
```

1. Terraform **voit** la modification, mais ne la **corrige pas**. Le provider ne compare que `config_json`, ce que **nous** avons écrit, et pas `computed_config`, ce que Kong renvoie. La configuration modifiée à la main reste en place indéfiniment.
2. Règle d'équipe : **aucune modification manuelle** en dehors du local. Konga en lecture seule, Admin API non accessible aux humains en recette et en production. Si une modification d'urgence est nécessaire, la reporter dans le code tout de suite.
3. decK :
   - **avantages** : un fichier décrit **tout** l'état, et ce qui n'y est pas est supprimé, donc pas de drift ; `deck diff` est fiable ; c'est l'outil officiel de Kong, il suit les versions et gère les entités de plugins custom ;
   - **inconvénients** : un outil de plus ; moins de modularité et de logique que Terraform ; il gère mal la cohabitation entre équipes (prévoir des `select_tags`).

## 7. Nettoyage

```bash
$TG destroy --terragrunt-working-dir /data/tenants/local/consumers
$TG destroy --terragrunt-working-dir /data/tenants/local/geocode
```

Un consumer créé à la main n'est **pas** supprimé : Terraform ne touche qu'aux ressources de **son state**.
