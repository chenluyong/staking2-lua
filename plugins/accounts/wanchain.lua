local _M = {}

local cjson = require "cjson"
local config = require "config"

local function gwan_rpc(_method, _params)
   
    local http = require 'resty.http'
    local httpc = http.new()

    local res, err = httpc:request_uri(config.WANCHAIN_RPC, {
        method = "POST",
        headers = config.CAMO_UA,
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

    local http = require 'resty.http'
    local httpc = http.new()
    local res, _ = httpc:request_uri(config.WANCHAIN_NODESINFO, {
        method = "GET",
        headers = config.CAMO_UA
    })
--    local res = ngx.location.capture('/nodes/wanchain')
--ngx.say(type(cjson.decode(res.body)))
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

    local isPledged = false
    if locking > 0 then
        isPledged = true
    end
    return { 
        balance = iBalance,
        balanceTotal = iBalance + locking,
        exist = true,
        pledged = isPledged,
        balanceUsable = iBalance + locking,
        balanceLocking = locking
    }
end


function _M.main()
    local args = ngx.req.get_uri_args()
    return get_account(string.lower(args.acc))
end

return _M
