--[[
[iost nodes example]
- request url:http://192.168.1.93/iost/getnodes?page=1&size=50&sort_by=votes&order=desc&search=
]]--

-- modules
local cjson = require "cjson"
local redis = require "resty.redis"
local const = require "constant"

-- var
local args = ngx.req.get_uri_args()
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
    WANCHAIN_RPC = "http://192.168.1.93:18545"
end
-- connect redis
local ok, err = rds:connect(rds_ip, 6379)
if not ok and DEBUG then
   RET.debug = "failed to connect: "..err
end


-- function
local function rds_set(k, v)
    k = "wanchain:account:"..k
    local ok, err = rds:set(k, v)
    if ok then
        rds:expire(k, 600)
    end
    return
end

local function rds_get(k)
    k = "wanchain:account:"..k
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

local function get_balance(_addr)
    local res = gwan_rpc("eth_getBalance",{_addr,"latest"})

    if not res then
        log(ERR, "request"..WANCHAIN_RPC.."failed")
        return 0
    end
    return tonumber(cjson.decode(res.body).result)
end

local function get_account_stake(_addr)
    local res = ngx.location.capture('/wanchain/getnodes')
    response = cjson.decode(res.body).result
    total_stake = 0

    for _, value in pairs(response) do
        for _, pv in pairs(value.partners) do
            if pv.address == _addr then
                total_stake = total_stake + tonumber(pv.amount)
                break
            end
        end

        for _, pc in pairs(value.clients) do
            if pc.address == _addr then
                total_stake = total_stake + tonumber(pc.amount)
                break
            end
        end
    end

    return total_stake
end


local function get_account(_addr)
    local iBalance = get_balance(_addr) / 1000000000000000000
    local locking = get_account_stake(_addr) / 1000000000000000000

    return { 
        balance = iBalance,
        balanceTotal = iBalance + locking,
        exist = true,
        pledged = false,
        balanceUsable = iBalance + locking,
        balanceLocking = locking
    }
end

-- logic
local ok, err = pcall(function()
    local res = get_account(string.lower(args.acc))
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
