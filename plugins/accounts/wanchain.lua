local _M = {}

local cjson = require "cjson"
local config = require "config"

local RET = {}

local function gwan_rpc(_method, _params)
_M.code = debug.getinfo(1).currentline   
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
_M.code = debug.getinfo(1).currentline
    local res = gwan_rpc("eth_getBalance",{_addr,"latest"})
    if not res then
        log(ERR, "request"..WANCHAIN_RPC.."failed")
        return 0
    end
    local ret = tonumber(cjson.decode(res.body).result)
--ngx.say(res.body)
    return ret
end

local function get_account_stake(_addr)
_M.code = debug.getinfo(1).currentline
--    local http = require 'resty.http'
--    local httpc = http.new()
--    local res, err = httpc:request_uri(config.WANCHAIN_NODESINFO, {
--        method = "GET",
--        headers = config.CAMO_UA
--    })
--    if err or not res then
--        return 0
--    end


    -- get rpc
    local res = gwan_rpc("eth_blockNumber",{})

    if not res then
--        log(ERR, "request"..WANCHAIN_RPC.."failed")
        return nil
    end
    --ngx.say(res.body)
    block_number = tonumber(cjson.decode(res.body).result)
    res = gwan_rpc("pos_getStakerInfo",{block_number})
    

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
--    local locking = 0
--ngx.say(locking)
--    if not ok then
--        locking = err / 1000000000000000000
--    end
_M.code = debug.getinfo(1).currentline
    local isPledged = false
    if locking > 0 then
        isPledged = true
    end
    return { 
        balance = iBalance + locking,
        balanceTotal = iBalance + locking,
        exist = true,
        pledged = isPledged,
        balanceUsable = iBalance,
        balanceLocking = locking
    }
end


function _M.main()
RET = {}
_M.code = debug.getinfo(1).currentline
    local args = ngx.req.get_uri_args()
    if not args.acc then
        return {
            error = "please input address args.",
            code = debug.getinfo(1).currentline
        }
    end
    local ret = get_account(string.lower(args.acc))
_M.code = 0
    return ret
end

return _M
