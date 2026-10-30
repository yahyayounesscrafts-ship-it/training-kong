# GET SANS API KEY
curl 'http://localhost:8000'

# GET AVEC API KEY
curl 'http://localhost:8000/plop' \
  --header 'apikey: CLE-FRONT' \
  --header 'referer: plop.fr'

curl 'http://localhost:8000/ratelimited' \
  --header 'referer: localhost'

curl 'http://localhost:8000/openbar' \
  --header 'apikey: CLE-FRONT' \
  --header 'referer: localhost'
