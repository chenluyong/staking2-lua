
local _M = {}

local cjson = require "cjson"
local config = require "config"


local function sort_by_vote(a, b)
    return a.total_vote > b.total_vote
end


local function convert_dto(_obj)
    local ret = {}
    local nodes = {}
    for _, v in pairs(_obj.list) do
        if not v.agentAlias or v.agentAlias == ngx.null then
            v.agentAlias = string.upper(v.agentId)
        end 
            table.insert(nodes,{
                alias = v.agentAlias,
                alias_en = v.agentAlias,
                address = v.agentAddress,
                total_vote = v.totalDeposit / 100000000,
                voters = v.depositCount,
                note_type = "producer",
                vote_percent = string.format("%.4f",v.totalDeposit / _obj.full_stake*100),
                commission_fee = string.format("%.2f",v.commissionRate),
            })
    end

    table.sort(nodes, sort_by_vote)
    for i=1, #nodes do
        nodes[i].rank = i
    end

    ret.nodes = nodes
    return ret
end


local function rpc(_method, _params)
   
    local http = require 'resty.http'
    local httpc = http.new()

    local res, err = httpc:request_uri(config.NULSCAN_GETACCOUNT, {
        method = "POST",
        headers = {
                ['User-Agent'] = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36',
                ['Content-Type'] = "application/json"
        },
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
    if true then return _rpc.result end
    local _nodesObj = _rpc.result.list
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
        value.stake_weight = tonumber(string.format("%.4f", (value.total_stake / full_stake * 100)))
        value.max_fee_rate = value.maxFeeRate / 100
        value.fee_rate = value.feeRate / 100
    end

    _rpc.full_stake = tonumber(string.format("%0.4f",full_stake))
    return _rpc
end


local function get_producers(_requestUri)
    -- get rpc
    local res = rpc("getConsensusNodes",{1,1,200,0})

    if not res then
        log(ERR, "request nuls rpc failed")
        return { error = "request nuls rpc failed" } 
    end
    -- convert params
    local ret_obj = convert_stake(cjson.decode(res.body))
    
    res = rpc("getCoinInfo",{1})
    if not res then
        log(ERR, "request `getCoinInfo` nuls rpc failed")
        ret_obj.full_stake = 3629934121590815
    else
        ret_obj.full_stake = cjson.decode(res.body).result.consensusTotal
    end


    return convert_dto(ret_obj)
--    return cjson.decode(res.body)
--    return ret_obj
end



function _M.main()
    ret = get_producers(ngx.var.request_uri)
    _M.code = 0
    return ret
end


return _M
