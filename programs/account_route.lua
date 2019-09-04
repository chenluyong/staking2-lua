local config = require("config")
local redis = require("resty.redis")
local cjson = require("cjson")

local RET = {}
local rds = redis:new()
rds:set_timeout(config.REDIS.timeout)

function connect_rds()
    rds:set_keepalive(10000,100)
    local ok, err = rds:connect(config.REDIS.ip, config.REDIS.port)
    if not ok then
        RET.warning = "internal error: " .. err .. ". " .. debug.getinfo(1).name
        RET.warning_code = debug.getinfo(1).currentline
        return false
    end
    return true
end

function rds_get(_k)
    if not connect_rds() then
        return nil 
    end

    _k = "accounts:".._k
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
    if not connect_rds() then
        return false
    end

    _k = "accounts:" .. _k
    local ok, err = rds:set(_k, _v)

    if ok then
        rds:expire(_k, _time)
    else
        RET.warning = "internal error:" .. err .. ". " .. debug.getinfo(1).name
        RET.warning_code = debug.getinfo(1).currentline
        return false
    end
    return true
end


local ok, err = pcall(function()

    --[[
    analyze request uri
    --]]

    -- read config.lua
    -- get request uri
    local request_uri = ngx.var.request_uri

    --[[
    get info
    --]]
    -- get cache
    rds_get(request_uri)

    -- call 

--     ngx.say(CONST.REDIS.account_list["wanchain"])
--     ngx.say(request_uri)
    local ret_table = {
        success = true
    }
    --[[
    check
    --]]
    



    -- merge tables
    for k,v in pairs(ret_table) do  
        RET[k] = v
    end
    if not RET.error then
        rds_set(request_uri, cjson.encode(RET))
    end
end)


-- put it into the connection poll
--local ok, err = rds:set_keepalive(10000,100)
--ngx.say('ok'..ok)
--ngx.say('redis err'..err)
--if not ok then

--end

ngx.say(cjson.encode(RET))
