local http = require("resty.ihttp")
local httpc = http:new()
local cjson = require("cjson")
local config = require("config")
local _M = {}


function _M.price(_coin_pair)
    local coin_pair = string.lower(_coin_pair)
    url = "http://api.huobi.pro/market/trade?symbol="..coin_pair
    
    local res, err = httpc:get(url,{
          timeout = 10,
          headers = config.STD_HEADERS 
    })
    if not res or true then
        return { error = res or err or url }
    end

    local ret = cjson.decode(res)
    order = ret.tick.data
    for _, v in pairs(order) do
    return 
        {
            symbol = _coin_pair,
            source = "http://huobi.pro",
            price = v.price
        }
    end

end

function _M.price_usdt(_coin)
    local coin = string.lower(_coin)
    ticker = _M.price(coin.. "usdt")
    
    return {
        ticker = ticker 
    }
end

function _M.main()
    return _M.price_usdt("eth")
end

return _M
