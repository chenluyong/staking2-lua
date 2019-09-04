local config = require("config")
local redis = require("resty.redis")
local cjson = require("cjson")

local RET = {}
local rds = redis:new()
rds:set_timeout(config.REDIS.timeout)

function rds_connect()
    rds:set_keepalive(10000,100)
    local ok, err = rds:connect(config.REDIS.ip, config.REDIS.port)
    if not ok then
        RET.warning = "internal error: " .. err .. ". " .. debug.getinfo(1).name
        RET.code = debug.getinfo(1).currentline
        return false
    end
    return true
end

function rds_get(_k)
    if not rds_connect() then
        return nil
    end

--    _k = "accounts:".._k
    local ok, err = rds:get(_k)

    if not ok then
        return nil
    end
    return ok 
end

function rds_set(_k, _v)
    return rds_set(_k, _v, 1800)
end

function rds_set(_k, _v, _time)
    if not _k or not rds_connect() then
        return false
    end

--    _k = "accounts:" .. _k
    local ok, err = rds:set(_k, _v)

    if ok then
        rds:expire(_k, _time)
    else
        RET.warning = "internal error:" .. err .. ". " .. debug.getinfo(1).name
        RET.code = debug.getinfo(1).currentline
        return false
    end
    return true
end


local ok, err = pcall(function()
    -- get request uri
    local request_all_uri = ngx.var.request_uri
    local request_uri = ngx.var.uri

    --[[
    get info
    --]]
    -- get cache
    local ret = rds_get(request_all_uri)
    if ret ~= nil and ret ~= ngx.null then
        return cjson.decode(ret)
    end

    -- get lua path
    local path = string.gsub(request_uri, "/", ".")
    path = string.sub(path,2)

    -- call
    local lua = require(path)
    local ret_table = lua.main()

    --[[
    check
    --]]

    return ret_table
end
--, function() RET.tracebak = debug.traceback() end, 133
)

-- alias
local ret_table = err 

if not ok then
    RET.error = err
    -- RET.tracebak = debug.traceback()
    if not RET.code then
        RET.code = debug.getinfo(1).currentline
    end
else
    -- merge tables
    for k,v in pairs(ret_table) do
        RET[k] = v
    end

    -- cache result
    if not RET.error and not RET.warning then
        rds_set(ngx.var.request_uri, cjson.encode(RET))
    end
end


-- put it into the connection poll
rds:set_keepalive(10000,100)
-- return
ngx.say(cjson.encode(RET))