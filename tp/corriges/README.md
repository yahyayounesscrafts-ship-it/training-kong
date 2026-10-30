# Corrigés (formateur)

| TP | Corrigé | Fichiers |
|----|---------|----------|
| TP0 | [TP0-corrige.md](TP0-corrige.md) | — |
| TP1 | [TP1-corrige.md](TP1-corrige.md) | — |
| TP2 | [TP2-corrige.md](TP2-corrige.md) | — |
| TP3 | [TP3-corrige.md](TP3-corrige.md) | — |
| TP4 | [TP4-corrige.md](TP4-corrige.md) | [tp4/kong/](tp4/kong/) (plugin corrigé), [tp4/spec/](tp4/spec/) (tests) |
| TP5 | [TP5-corrige.md](TP5-corrige.md) | [tp5/infra/](tp5/infra/) (uniquement les fichiers modifiés ou ajoutés) |

Toutes les commandes et tous les résultats attendus ont été vérifiés sur Kong 2.8.5 + Cassandra 3.9, avec la stack de `docker-compose-local.yml`.

## Conseils d'animation

- **Lancez pongo la veille** (`KONG_VERSION=2.8.5 pongo run` dans le repo) : le premier build de l'image de test prend 15 à 30 min et télécharge beaucoup.
- Faites aussi le `terragrunt init` du TP5 à l'avance (c'est ce que fait [daas/prepare.sh](../daas/prepare.sh)) : le téléchargement du provider Terraform échoue parfois sur un réseau lent (`unexpected EOF`) ; il suffit de relancer.
- Le piège n°1 des stagiaires : tester dans la seconde qui suit un appel à l'Admin API (propagation ~5 s avec Cassandra).
- Le piège n°2 : sous **zsh**, `H="-H apikey:X"; curl $H ...` ne découpe pas la variable en deux arguments. Écrire les en-têtes en clair.
