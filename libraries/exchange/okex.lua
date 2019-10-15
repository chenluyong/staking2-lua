local http = require("resty.ihttp")
local httpc = http:new()
local cjson = require("cjson")
local config = require("config")
local _M = {}


function _M.price(_coin_pair)
    local coin_pair = string.lower(_coin_pair)
    url = "https://www.okex.me/api/spot/v3/instruments/"..coin_pair.."/trades?limit=1"

    local res, err = httpc:get(url,{
          timeout = 5,
          headers = config.STD_HEADERS 
    })
    if not res then
        return { error = res or err or url }
    end

    local ret = cjson.decode(res)
    if ret.code ~= nil then
        return {
            ticker = {
                symbol = _coin_pair,
                source = "http://www.okex.me",
                price = 0
            },
            error = ret.message
        }

    end

    for _, v in pairs(ret) do
    return {
            ticker={
                symbol = _coin_pair,
                source = "http://www.okex.me",
                price = v.price
            }}
    end

end

function _M.price_usdt(_coin)
    local coin = string.upper(_coin)
    ticker = _M.price(coin.. "-USDT")
    
    return ticker 
end
function _M.price_btc(_coin)
    local coin = string.upper(_coin)
    ticker = _M.price(coin.. "-BTC")
    
    return ticker 
end


function _M.main()
    return _M.price_usdt("eth")
end

return _M
