
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

-- stake weight
-- self stake
-- total stake
local function convert_stake(_rpc)
    local _nodesObj = _rpc.result
    local full_stake = 0
    -- convert stake
    for _, value in pairs(_nodesObj) do
        local total_stake = 0
        local total_partners = 0
        local total_clients = 0

        for _, pv in pairs(value.partners) do
            total_partners = total_partners +  tonumber(pv.amount)
        end

        for _, pc in pairs(value.clients) do
            total_clients = total_clients + tonumber(pc.amount)
        end

        local nDecimal = 1000000000000000000
        total_stake = total_partners + total_clients + value.amount
        value.partners_stake = total_partners / nDecimal
        value.partners_size = #value.partners
        value.clients_stake = total_clients / nDecimal
        value.clients_size = #value.clients
        value.total_stake = total_stake / nDecimal


        full_stake = full_stake + value.total_stake
    end

    for _, value in pairs(_nodesObj) do
        value.stake_weight = string.format("%.2f%%", (value.total_stake / full_stake * 100))
        value.max_fee_rate = value.maxFeeRate / 100
        value.fee_rate = value.feeRate / 100
    end

    _rpc.full_stake = string.format("%0.2f",full_stake)
    return _rpc
end


local function get_producers(_requestUri)
    -- get rpc
    local res = gwan_rpc("eth_blockNumber",{})

    if not res then
--        log(ERR, "request"..WANCHAIN_RPC.."failed")
        return nil
    end
    --ngx.say(res.body)
    block_number = tonumber(cjson.decode(res.body).result)
    res = gwan_rpc("pos_getStakerInfo",{block_number})
    
    if not res then
--        log(ERR, "request"..WANCHAIN_RPC.."failed")
        return nil
    end
    -- convert params
    local ret_obj = convert_stake(cjson.decode(res.body))

    return ret_obj
end



function _M.main()
    return get_producers(ngx.var.request_uri)    
end


return _M
