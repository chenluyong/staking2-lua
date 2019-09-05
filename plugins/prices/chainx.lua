local os = os
local cjson = require "cjson"
local http = require "resty.ihttp"
local httpc = http:new()
local util = require "staking2.util"
local config = require("config")
local _M = {}
local RET = {}


function _M.main()
    util.log(config.CHAINXTOOLS_API, os.time())
    local res, err = httpc:get(string.format("%s%s", config.CHAINXTOOLS_API, os.time()))
    if not res then
        RET.error = "request "..config.CHAINXTOOLS_API.."failed: "..err
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

    return RET
end
return _M
