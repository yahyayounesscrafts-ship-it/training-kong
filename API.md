# Check-Referer API Documentation

## POST Check Referer on a Route
This endpoint lets you activate the check referer plugin on a Route.

### HTTP Request

```
POST /routes/{route_id}/plugins
```

### Params

| Parameter  | Description           |
|------------|-----------------------|
| route_id   | The id of the route   |

### Data
```json
{
  "name": "check-referer"
}
```

## POST Check Referer on a Service
This endpoint lets you activate the check referer plugin on a Route.

### HTTP Request

```
POST /service/{service_id}/plugins
```

### Params

| Parameter    | Description             |
|--------------|-------------------------|
| service_id   | The id of the service   |


### Data
```json
{
  "name": "check-referer"
}
```

## POST a Check-Referer resource for a consumer
This endpoint will add a new referer for a given consumer.

**_NOTE:_** you can technically create a lot of referers for a consumer, however the last creation is the one taken into account.
When you create a first check-referer resource, you have to get its ID and use it for updates.

### HTTP Request

```
POST /consumers/{consumer_id}/check-referer
```

### Params

| Parameter    | Description             |
|--------------|-------------------------|
| consumer_id   | The id of the consumer   |

### Data
```json
{
  "referer": "regex"
}
```

### Example curl
```
curl -X POST localhost:8001/consumers/45f10540-187c-4bf5-872a-064e41e1da06/check-referer \
  --header "Content-Type: application/json" \
  -d '{"referer": "plop.com"}'
```

### Responses
#### 201
```json
{
  "id": "string",
  "consumer": {
    "id": "string"
  }
}
```

## DELETE a Check-Referer ressource for a consumer

### HTTP Request

```
DELETE /consumers/{consumer_id}/check-referer/{check_referer_id}
```
| Parameter    | Description             |
|--------------|-------------------------|
| consumer_id   | The id of the consumer   |
| check_referer_id   | The id of the check-referer ressource   |

### Example curl
```
curl -X DELETE localhost:8001/consumers/45f10540-187c-4bf5-872a-064e41e1da06/check-referer/36BB0B3E-510E-4495-A878-E867959019A5
```

## UPDATE a Check-Referer ressource for a consumer

### HTTP Request

```
PUT /consumers/{consumer_id}/check-referer/{check_referer_id}
```
| Parameter    | Description             |
|--------------|-------------------------|
| consumer_id   | The id of the consumer   |
| check_referer_id   | The id of the check-referer ressource   |

### Data
```json
{
  "referer": "regex"
}
```

### Example curl
```
curl -X PUT localhost:8001/consumers/45f10540-187c-4bf5-872a-064e41e1da06/check-referer/36BB0B3E-510E-4495-A878-E867959019A5 \
  --header "Content-Type: application/json" \
  -d '{"referer": "plop.fr"}'
```
