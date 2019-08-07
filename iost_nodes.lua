--[[
[iost nodes example]
- request url:http://192.168.1.93/iost/getnodes?page=1&size=50&sort_by=votes&order=desc&search=
]]--

-- modules
local cjson = require "cjson"
local redis = require "resty.redis"

-- var
local rds = redis:new()
local IOST_NODESINFO = "https://www.iostabc.com/api/producers"
local RET = {}
local log = ngx.log
local ERR = ngx.ERR
local DEBUG = true 
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
    k = "iost:nodes:"..k
    local ok, err = rds:set(k, v)
    if ok then
        rds:expire(k, 600)
    end
    return
end

local function rds_get(k)
    k = "iost:nodes:"..k
    local ok, err = rds:get(k)
    if not ok then
        return
    end
    return ok 
end

local function get_producers(args)
    local http = require 'resty.ihttp'
    local httpc = http.new()
    local request_url = string.format("%s/%s", IOST_NODESINFO, args)
    
    -- get nodes from redis
    local ok = rds_get(request_url)
    if ok ~= ngx.null and ok then
        local ret = cjson.decode(ok)
        ret.status = 0
        if DEBUG then
            ret.debug = "from redis"
        end
        return ret
    end
    
    -- request 
    local res, err = httpc:get(request_url)
    if not res then
        return { error = "request "..IOST_NODESINFO.." failed: "..err }
    else
        rds_set(request_url,res)
        ret = cjson.decode(res)
        ret.status = 0
    end
    return ret
end


-- logic
local ok, err = pcall(function()
    -- get nodes info
    args_len = #ngx.var.request_uri - #ngx.var.uri + 1
    local args = "?page=1&size=50&sort_by=votes&order=desc&search="
    if args_len > 3 then
        args = string.sub(ngx.var.request_uri, #ngx.var.uri + 1, #ngx.var.request_uri)
    end
    ngx.say(args)
    local ret_table = get_producers(args)

    -- merge tables
    for k,v in pairs(ret_table) do  
        RET[k] = v
    end
    
    return
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
