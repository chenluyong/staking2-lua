--[[
[iost nodes example]
- request url:http://192.168.1.93/iost/getnodes?page=1&size=50&sort_by=votes&order=desc&search=
]]--

-- modules
local cjson = require "cjson"
local redis = require "resty.redis"
local const = require "constant"

-- var
local rds = redis:new()
local WANCHAIN_RPC = "http://47.99.50.243:80"
local RET = {}
local log = ngx.log
local ERR = ngx.ERR
local DEBUG = false 
RET.status = 1

-- local ip
local rds_ip = "127.0.0.1"
if DEBUG then
    rds_ip = "192.168.1.93"
end
-- connect redis
local ok, err = rds:connect(rds_ip, 6379)
if not ok and DEBUG then
   RET.debug = "failed to connect: "..err
end


-- function
local function rds_set(k, v)
    k = "wanchain:nodes:"..k
    local ok, err = rds:set(k, v)
    if ok then
        rds:expire(k, 600)
    end
    return
end

local function rds_get(k)
    k = "wanchain:nodes:"..k
    local ok, err = rds:get(k)
    if not ok then
        return nil
    end
    return ok 
end


local function gwan_rpc(_method, _params)
   
    local http = require 'resty.http'
    local httpc = http.new()

    local res, err = httpc:request_uri(WANCHAIN_RPC, {
        method = "POST",
        headers = const.CAMO_UA,
        body = cjson.encode({
           jsonrpc = "2.0",
           method = _method,
           params = _params,
           id = 67
       })
    })

    return res
end

local function get_producers()
    -- get redis
    local ok = rds_get("default")
    if ok ~= ngx.null and ok then
        local ret = cjson.decode(ok)
        ret.status = 0
        if DEBUG then
            ret.debug = "from redis"
        end
        return ret
    end

    -- get rpc
    local res = gwan_rpc("eth_blockNumber",{})

    if not res then
        log(ERR, "request"..WANCHAIN_RPC.."failed")
        return nil
    end

    block_number = tonumber(cjson.decode(res.body).result)
    res = gwan_rpc("pos_getStakerInfo",{block_number})

    if not res then
        log(ERR, "request"..WANCHAIN_RPC.."failed")
        return nil
    end

    rds_set("default",res.body)
    -- cache redis

    return cjson.decode(res.body)
end


-- logic
local ok, err = pcall(function()
    local res = get_producers()
    if not res then
        RET.status = 1
    else
        RET = res
        RET.status = 0
    end
    
    return nil
end)

if not ok then
    if DEBUG then
        RET.error = err
    else
        RET.error = "unknown error."
    end
    log(ERR, err)
end


-- response
ngx.header.content_type = 'application/json'
ngx.say(cjson.encode(RET))
