
local cjson = require "cjson"
local http = require "resty.ihttp"
local httpc = http:new()
local util = require ("staking2.util")
local config = require ("config")

local _M = {}
local string = string
local table = table

local RET = {}

local function sort_by_vote(a, b)
    return a.total_vote > b.total_vote
end

function get_total_power()
    local res,err = httpc:get("https://explorer.yoyow.org/api/v1/get_witnesses_head_info")


    if not res then
        RET.error = "request failed: ".. (err or "unanticipated response.") 
--        RET.error_teail = res
        return 10588417178166
    end

    return cjson.decode(res).total_witnesses_pledge
end


function get_witnesses_identity()
    
end

function _M.main()
--local detail = {}
_M.code = debug.getinfo(1).currentline 
    local res, err = httpc:get("https://explorer.yoyow.org/api/v1/list_witnesses")

    if not res then
        RET.error = "request failed: ".. (err or "unanticipated response.") 
--        RET.error_teail = res
        return RET
    end

    local totalPower = get_total_power() 
    local ret = cjson.decode(res)
    RET.nodes = {}
    if ret then
--detail.st = ret
        for _, node in pairs(ret) do
            repeat
                local total_vote = node.total_votes
                if type(node.total_votes) == 'string' then
                    total_vote = tonumber(node.total_votes)
                end
                if total_vote == 0 then
                    break
                end

                local vote_percent = (total_vote / totalPower)*10
                local vote_percent_str = string.format("%.4f", vote_percent)

                table.insert(RET.nodes, {
                    alias = node.name,
                    alias_en = node.name,
                    address = string.format("%d",node.account),
                    pub_key = node.signing_key,
                    total_vote = total_vote / 100000,
                    node_type = "producer",
                    vote_percent = vote_percent_str,
                    website = node.url,
                    last_confirmed_block_num = node.last_confirmed_block_num
                })
            until true
        end
    end

    table.sort(RET.nodes, sort_by_vote)
    highest_block = RET.nodes[1].last_confirmed_block_num - 10000
    local producer_number = 0
    for i=1, #RET.nodes do
        RET.nodes[i].rank = i
        if RET.nodes[i].last_confirmed_block_num < highest_block then
            RET.nodes[i].node_type = 'validator'
        end
        RET.nodes[i].last_confirmed_block_num = nil
    end

_M.code = 0


    return RET
end

return _M
