service_name='monService'
service_url='http://mockbin.org/bin/a63a0c40-b73b-40c8-8d17-b97f847911d2'

# CRÉATION D'UN SERVICE
curl -i -X POST \
--url http://localhost:8001/services/ \
--data 'name=monService' \
--data 'url=http://mockbin.org/bin/a63a0c40-b73b-40c8-8d17-b97f847911d2/api'

# AJOUT D'UNE ROUTE
curl -i -X POST \
--url 'http://localhost:8001/services/monService/routes' \
--data 'id=C5FADFE7-EC2A-42D2-901F-FD1F97BA11BD' \
--data 'hosts[]=localhost' \
--data 'paths[]=/plop' \
--data 'methods[]=GET' \
--data 'methods[]=OPTIONS'


# ACTIVER LE PLUGIN KEY AUTH SUR LE SERVICE POUR L'API KEY
curl -X POST http://localhost:8001/services/monService/plugins \
    --data "name=key-auth"  \
    --data 'config.run_on_preflight=false' \
    --data "config.key_names=apikey" \
    --data "config.key_in_header=true"


# CRÉER UN CONSOMMATEUR
curl http://localhost:8001/consumers/ \
    --data "username=consumer-plop"

# AJOUTER UNE API KEY
curl -X POST http://localhost:8001/consumers/23a252cb-fbd8-49d9-83e4-597910a76627/key-auth \
    --data "key=CLE-FRONT"

# ACTIVER LE PLUGIN CHECK-REFERER SUR LA ROUTE
curl -X POST http://localhost:8001/routes/C5FADFE7-EC2A-42D2-901F-FD1F97BA11BD/plugins \
    --data "name=check-referer"

# AJOUTER UN REFERER A UN CONSUMER
curl -X POST http://localhost:8001/consumers/23a252cb-fbd8-49d9-83e4-597910a76627/check-referer \
    --data "referer=plop.fr"

curl -X PUT http://localhost:8001/consumers/23a252cb-fbd8-49d9-83e4-597910a76627/check-referer/ad493731-93d7-4210-ade8-e229c6b55f16 \
    --data "referer=plop.com"
