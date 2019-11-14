local config = require("config")
local redis = require("resty.redis")
local cjson = require("cjson")

local RET = {}
local rds = redis:new()
rds:set_timeout(config.REDIS.timeout)

log = ngx.log
ERR = ngx.ERR

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

    local ok, err = rds:get(_k)

    if not ok then
        return nil
    end
    return ok 
end

function rds_set(_k, _v)
    return rds_set(_k, _v, config.REDIS.default_time)
end

function rds_set(_k, _v, _time)
    if not _k or not rds_connect() then
        return false
    end

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

string.split = function(s, p)

    local rt= {}
    string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end )
    return rt

end

local function main()
RET.code = 1
    -- get request uri
    local request_all_uri = ngx.var.request_uri
    local request_uri = ngx.var.uri

    -- get lua path
    local request_table = string.split(request_uri,"/")
    local request_type = request_table[1]
    local request_module = request_table[2]
    local path = request_type .. "." .. request_module
    

    local ok, err = pcall(function()
        -- get cache
        local ret = rds_get(request_all_uri)
        if ret ~= nil and ret ~= ngx.null then
            local ret_value = cjson.decode(ret)
            ret_value.cache = true
            return ret_value
        end

        -- call
        local lua = require(path)
        local ret_table = {}
        local ok, err = pcall(function()
            ret_table = lua.main() 
        end
        )
        RET.code = lua.code
        if RET.code ~= 0 and RET.code ~= nil then
            RET.error =  err 
        end
        return ret_table
    end
    )
    local ok, err = pcall(function()
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

        if not RET.code and not RET.error then
            RET.code = 0
            RET.debug = 0
        end

        -- cache result
        if RET.code == 0 and not RET.error and not RET.warning and request_type and request_module and config.REDIS[request_type] then
            local expire_time = config.REDIS[request_type][request_module]
            if not expire_time then
                expire_time = config.REDIS[request_type]['default']
            end
            if expire_time ~= 0 then
                -- tpis: for now that's all.
                --       after tactics cache,
                pcall(rds_set(ngx.var.request_uri, cjson.encode(RET), expire_time))
            end
        end
    end

    -- put it into the connection poll
    rds:set_keepalive(10000,100)
    end)
    if not ok then
        RET.code = debug.getinfo(1).currentline
        RET.error = "internal error:" .. err
    end
end

main()
RET.version = config.VERSION
-- return
ngx.say(cjson.encode(RET))
