
local cjson = require "cjson"
local http = require "resty.ihttp"
local httpc = http:new()
local util = require ("staking2.util")
local config = require ("config")

local _M = {}
local string = string
local table = table
local log = ngx.log
local ERR = ngx.ERR

local RET = {}


local function sort_by_vote(a, b)
    return a.total_vote > b.total_vote
end




function _M.main()
--local detail = {}
_M.code = debug.getinfo(1).currentline
    local res, err = httpc:get("https://explorer.lambdastorage.com/api/validator/validatorList?type=0&status=0")
    local ok = string.find(res,"<html>")
--log(ERR,"error:" .. res)
    if not res or ok then
        RET.error = "request failed: ".. (err or "unanticipated response.") 
--        RET.error_teail = res
        return RET
    end

_M.code = debug.getinfo(1).currentline
    local totalPower = 0
    local ret = cjson.decode(res)
log(ERR,type(ret))
    RET.nodes = {}
    if ret then
--detail.st = ret
_M.code = debug.getinfo(1).currentline
        for _, node in pairs(ret.data.validatorList) do
            repeat
                voters = nil
                if false then
                    local res,err = httpc:get("https://explorer.lambdastorage.com/api/delegations/queryDelegationsForValidator?validator=" .. node.operator_address)
                    if res then
                        voters = cjson.decode(res).data.count
                    end
                end
                table.insert(RET.nodes, {
                    alias = node.description_moniker,
                    alias_en = node.description_moniker,
                    total_vote = tonumber(node.tokens) / 1000000,
                    website = node.description_website,
                    description = node.description_details,
                    description_en = node.description_details,
                    voters = voters,
                    commission_fee = string.format("%.2f",tonumber(node.commission_rate) * 100)
                })
            until true
        end
    end


_M.code = debug.getinfo(1).currentline

    table.sort(RET.nodes, sort_by_vote)
    for i=1, #RET.nodes do
        RET.nodes[i].rank = i
    end
_M.code = 0
--    RET = convert(RET)
--RET.detail = detail
    return RET
end

return _M
