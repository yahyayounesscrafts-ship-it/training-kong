local re_match = ngx.re.match
local kong = kong

local CheckRefererHandler = {
  PRIORITY = 200,
  VERSION = "1.1.0",
}


local EMPTY = {}

-- Extrait l'hôte d'une URL : "https://user@plop.fr:8443/page?x=1" -> "plop.fr"
-- (la partie "user@" est ignorée, sinon "https://plop.fr@evil.com" passerait pour plop.fr)
local HOST_REGEX = [[^[a-z][a-z0-9+.-]*://(?:[^/?#@]*@)?([^/:?#]+)]]


-- Callback appelé par kong.cache en cas de "miss" : (valeur, err)
-- Un nil sans erreur est mis en cache comme "pas de referer configuré".
local function load_referer(consumer_id)
  local row, err = kong.db.check_referer:select_by_consumer({ id = consumer_id })
  if err then
    return nil, err
  end

  return row and row.referer
end

local function get_current_consumer_id()
  return (kong.client.get_consumer() or EMPTY).id or
         (kong.client.get_credential() or EMPTY).consumer_id
end

local function extract_host(url)
  local m = re_match(url, HOST_REGEX, "joi")
  return m and m[1]:lower()
end

function CheckRefererHandler:matcher(allowed_referer, request_referer)
  if not request_referer then
    return false
  end

  return re_match(request_referer, allowed_referer, "jo") ~= nil
end

function CheckRefererHandler:access(conf)
  local consumer_id = get_current_consumer_id()
  if not consumer_id then
    return kong.response.error(401, "You cannot consume this service")
  end

  local cache_key = kong.db.check_referer:cache_key(consumer_id)
  local allowed_referer, err = kong.cache:get(cache_key, nil, load_referer, consumer_id)
  -- l'erreur doit être testée AVANT l'absence de valeur, sinon une panne de base
  -- de données se transforme silencieusement en 403
  if err then
    kong.log.err("could not load referer for consumer ", consumer_id, ": ", err)
    return kong.response.error(500, "Unexpected error")
  end

  if not allowed_referer then
    kong.log.debug("no referer configured for consumer ", consumer_id)
    return kong.response.error(403, "You cannot consume this service")
  end

  local request_referer = kong.request.get_header("Referer")
  if not request_referer then
    if conf.allow_empty_referer then
      return
    end
    return kong.response.error(403, "You cannot consume this service")
  end

  local subject, pattern = request_referer, allowed_referer
  if conf.match_host_only then
    -- on compare uniquement l'hôte, et la regex doit le couvrir entièrement
    subject = extract_host(request_referer)
    pattern = "^(?:" .. allowed_referer .. ")$"
  end

  if not self:matcher(pattern, subject) then
    kong.log.debug("referer '", request_referer, "' refused for consumer ", consumer_id)
    return kong.response.error(403, "You cannot consume this service")
  end
end

return CheckRefererHandler
