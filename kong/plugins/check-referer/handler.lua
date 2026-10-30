local re_match = ngx.re.match
local kong = kong

local CheckRefererHandler = {
  PRIORITY = 200,
  VERSION = "1.0.0",
}


local EMPTY = {}


local function get_referer_from_db_for_curent_consumer(consumer_id)
  kong.log.info("called-", consumer_id)
  local resultat, err = kong.db.check_referer:select_by_consumer({ id = consumer_id })
  kong.log.err("error", err)
  if not resultat then
    return nil, err
  end

  return resultat.referer, nil
end

local function get_current_consumer_id()
  return (kong.client.get_consumer() or EMPTY).id or
         (kong.client.get_credential() or EMPTY).consumer_id
end

local function get_request_referer()
  local headers = kong.request.get_headers()
  return headers['Referer']
end

function CheckRefererHandler:matcher(allowed_referer, request_referer)
  return re_match(request_referer, allowed_referer, "jo")
end

function CheckRefererHandler:access(conf)
  local consumer_id = get_current_consumer_id()
  kong.log.info("consumer_id-", consumer_id)
  if not consumer_id then
    return kong.response.error(401, "You cannot consume this service")
  end

  local referer_from_cache = kong.db.check_referer:cache_key(consumer_id)
  local referer_from_db = function() return get_referer_from_db_for_curent_consumer(consumer_id) end

  local allowed_referer, err = kong.cache:get(referer_from_cache, nil, referer_from_db, referer_from_cache)
  if not allowed_referer then
    return kong.response.error(403, "You cannot consume this service")
  end
  if err then
    kong.log.err(err)
    return kong.response.exit(500, {
      message = "Unexpected error"
    })
  end

  local request_referer = get_request_referer()
  kong.log.info("request_referer-", request_referer)

  local ok = CheckRefererHandler:matcher(allowed_referer, request_referer)
  if not ok then
    return kong.response.error(403, "You cannot consume this service")
  end
end

return CheckRefererHandler
