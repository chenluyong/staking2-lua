
local _M = {}

local cjson = require "cjson"
local config = require "config"
local http = require "resty.ihttp"
local httpc = http:new()

local RET = {}

local function get_bonded_tokens()
    local res, err = httpc:get("https://api.cosmostation.io/v1/status")

_M.code = debug.getinfo(1).currentline
    if not res then
        RET.warning = "request bonded tokens failed."
        return 0
    end
    local ret = cjson.decode(res)
    if ret then
        return ret.bonded_tokens
    end
    return 0
end


local function get_validator_votes(_account)
    local res, err = httpc:get("https://api.cosmostation.io/v1/staking/validator/delegations/".._account)

_M.code = debug.getinfo(1).currentline

    if not res then
        RET.warning = "request validator votes failed."
        return 0
    end

_M.code = debug.getinfo(1).currentline

    local ret = cjson.decode(res)
    if ret then
        return ret.total_delegator_num
    end
    return 0
end


local function sort_by_vote(a, b)
    return a.rank < b.rank
end

function _M.main()
_M.code = debug.getinfo(1).currentline
RET = {}
    local res, err = httpc:get("https://api.cosmostation.io/v1/staking/validators")
    if not res then
        RET.error = "request failed"
        return RET
    end

    local ret = cjson.decode(res)
    RET.nodes = {}

_M.code = debug.getinfo(1).currentline
    if ret then
        local bonded_tokens = get_bonded_tokens()
_M.code = debug.getinfo(1).currentline
        for _, node in pairs(ret) do
            local vote_percent = bonded_tokens == 0 and ngx.null or (node.tokens / bonded_tokens / 1000000)
            local vote_percent_str = string.format("%.4e", vote_percent)
            local temp_pos = string.find(vote_percent_str,"e") - 1
            local voters = 0
            local tokens = tonumber(node.tokens)
            if tokens > 1000000000 and node.rank < 10 and false then
                voters = get_validator_votes(node.operator_address)
            end
            table.insert(RET.nodes, {
                    alias = node.moniker,
                    alias_en = node.moniker,
                    address = node.operator_address,
                    pub_key = node.consensus_pubkey,
                    description = node.details,
                    description_en = node.details,
                    total_vote = tokens / 1000000,
                    rank = node.rank,
                    node_type = node.jailed == true and "validator" or (node.rank < 101 and "producer" or "validator"),
                    vote_percent = string.sub(vote_percent_str, 1, temp_pos),
--                    voters = voters,
                    commission_fee = string.format("%.2f",tonumber(node.rate) * 100)
                })
        end
    end
    table.sort(RET.nodes, sort_by_vote)
_M.code = 0
    return RET
end


return _M
