
local os = os
local cjson = require "cjson"
local redis = require "resty.iredis"
local rds = redis:new()
local http = require "resty.ihttp"
local httpc = http:new()
local util = require "util"

local CHAINXTOOLS_API = "https://api.chainxtools.com/price?t="

local RET = {}

local ok, err = rds:get('chainx:price')
if not ok then
    util.log(CHAINXTOOLS_API, os.time())
    local res, err = httpc:get(string.format("%s%s", CHAINXTOOLS_API, os.time()))
    if not res then
        RET.error = "request "..CHAINXTOOLS_API.."failed: "..err
    end

    local ret = cjson.decode(res)
    if res.error then
        RET.error = string.format("rpc error %s", res.err.message)
    else
        if ret['cyb-price'] and ret['cyb-usd-cny'] then
            RET.pcxusdt = ret['cyb-price']
            RET.pcxcny = ret['cyb-price'] * ret['cyb-usd-cny']
            RET.pcxbtc = ret['cyb-price'] * ret['cyb-usd-cny'] / ret['btc-cny']
        end
    end

    if not RET.error then
        ok, err = rds:set('chainx:price', cjson.encode(RET))
        if not ok then
            log(ERR, "save result to redis failed: "..err)
        end
        ok, err = rds:expire('chainx:price', 180)
        if not ok then
            log(ERR, "set key expire failed")
        end
    end
else
    RET = cjson.decode(ok)
end

ngx.say(cjson.encode(RET))
