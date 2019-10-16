
local cjson = require "cjson"
local http = require "resty.ihttp"
local httpc = http:new()
local util = require ("staking2.util")
local config = require ("config")

local _M = {}
local string = string
local table = table

local RET = {}

function _M.main()
--local detail = {}
    local res, err = httpc:get("https://polkascan.io/kusama/api/v1/session/validator?&filter[latestSession]=true&page[size]=25")
    local ok = string.find(res,"<html>")

    if not res or ok then
        RET.error = "request failed: ".. (err or "unanticipated response.") 
--        RET.error_teail = res
        return RET
    end

    local totalPower = 0
    local ret = cjson.decode(res)
    RET.nodes = {}
    if ret then
--detail.st = ret
        for _, node in pairs(ret.data) do
            repeat
                local inline_node = node.attributes
                table.insert(RET.nodes, {
                    alias = inline_node.validator_stash,
                    alias_en = inline_node.validator_stash,
                    total_vote = inline_node.bonded_total == ngx.null and 0 or inline_node.bonded_total,
                    rank = inline_node.rank_validator + 1,
                    voters = inline_node.count_nominators,
                    commission_fee = inline_node.commission == ngx.null and 0 or inline_node.commission,
                    node_type = node.type
                })
            until true
        end
    end

--    RET = convert(RET)
--RET.detail = detail
    return RET
end

return _M
