local http = require("resty.ihttp")
local httpc = http:new()
local cjson = require("cjson")
local config = require("config")
local _M = {}


function _M.price(_coin_pair)
    local coin_pair = string.upper(_coin_pair)
    url = "https://api.binance.com/api/v3/ticker/bookTicker?symbol=WANUSDT"--..coin_pair
    --if true then return {url = url} end
    local res, err = httpc:get(url,{
          timeout = 5--,
--          headers = config.STD_HEADERS 
    })
    if not res or err then
        return { error = res or err or url }
    end

    local ret = cjson.decode(res)
    return 
        {
            symbol = _coin_pair,
            source = "http://binance.com",
            price = v.askPrice
        }

end

function _M.price_usdt(_coin)
    local coin = string.upper(_coin)
    ticker = _M.price(coin.. "usdt")
    
    return {
        ticker = ticker 
    }
end

function _M.main()
    return _M.price_usdt("wan")
end

return _M
