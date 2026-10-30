# Pré requis
* Avoir `docker` et `docker-compose` installés
> [lien vers l'installation](https://docs.docker.com/engine/install/)
* Avoir `pongo` installé
> [lien vers l'installation](https://github.com/Kong/kong-pongo#requirements)



## Lancer kong en local

### Builder l'image de kong
        docker build . -t kong-local

### Lancer kong et les migrations
        docker-compose up -d

### Initialiser terraform pour le tenant snap (à faire une seule fois)
        make init-snap

### Appliquer la configurationpour le tenant snap via terraform et terragrunt
        make apply-snap

### Éteindre kong et supprimer les volumes
        docker-compose down -v

## Accéder à kong

La gateway kong est ensuite accessible sur l'url :`http://localhost:8000`

L'API Admin est accessible sur l'url : `http://localhost:8001`

Une GUI permet de visualiser et modifier manuellement la configuration : `http://localhost:1337`

## Lancer les tests
        pongo run



