--[[
[chainx account example]
- request url: http://192.168.1.93/chainx/getaccount?acc=5VLFvns2zgpJGFjz6ob5U3Vbomy71aHrM3ieVH5MNTPpeyzB
- return body:
{
    "balanceTotal":1.600473,
    "balance":1.600473, -- the same as `balanceTotal`
    "status":0,
    "balanceLocking":0,
    "account":"0xfbdc9c53d8ebc2f2a00636cf4cc9b5f50fb0415bb1058c194ff9c9c148369371",
    "balanceUsable":1.600473,
    "pledged":false
}
]]--


local cjson = require "cjson"
local base58 = require("resty.base58")
local redis = require "resty.redis"

local rds = redis:new()
local args = ngx.req.get_uri_args()
local log = ngx.log
local ERR = ngx.ERR
local RET = {}
local CHAINX_GETACCOUNT = "https://api.chainx.org.cn/account"
local DEBUG = false

RET.status = 1

rds:set_timeout(1000)

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

-- define function
local function bin2hex(s)
    s=string.gsub(s,"(.)",function (x) return string.format("%02x",string.byte(x)) end)
    return s
end

local function rds_set(k, v)
    local ok, err = rds:set(k, v)
    if ok then
        rds:expire(k, 3600)
    end
    return
end

local function rds_get(k)
    local ok, err = rds:get(k)
    if not ok then
        return
    end
    return ok
end

-- get account info
local function get_info(acc)
    local adr_check = bin2hex(base58.decode(acc))
    local adr = string.sub(adr_check, 3, string.len(adr_check)-4)
    local request_url = string.format("%s/0x%s/balance", CHAINX_GETACCOUNT, adr)

    if ( #adr ~= 64 ) then
        return { error = "address format error." }
    end
    local ok = rds_get("chainx:account:"..adr)
    if ok ~= ngx.null and ok then
        local ret = cjson.decode(ok)
        ret.status = 0
        if DEBUG then
            ret.debug = "from redis"
        end
        return ret
    end

    -- python script
    local chainx_py = "/usr/local/openresty/nginx/conf/staking2/scripts/chainx.py"

    -- request account info
    -- demo: /usr/local/openresty/nginx/conf/staking2/scripts/chainx.py https://api.chainx.org.cn/account/0xfbdc9c53d8ebc2f2a00636cf4cc9b5f50fb0415bb1058c194ff9c9c148369371/balance 0xfbdc9c53d8ebc2f2a00636cf4cc9b5f50fb0415bb1058c194ff9c9c148369371
    local cmd = string.format("%s %s 0x%s",chainx_py, request_url, adr)
    local t = io.popen(cmd)
    local a = t:read("*all")
    local ret_obj = cjson.decode(a)
    if (ret_obj["status"] ~= 0) then
        log(ERR,a)
    else
        rds_set("chainx:account:"..adr, a)
    end

    return cjson.decode(a)
end

local ok, err = pcall(function()
    -- get params
    local acc = args.acc
    if not acc then
        log(ERR, "ERR not chainx account provided.")
        RET.error = "missing arguments"
        return
    end

    -- get account info
    local ret_table = get_info(acc)
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
