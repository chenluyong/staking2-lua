
local cjson = require "cjson"
local http = require "resty.ihttp"
local httpc = http:new()
local util = require ("staking2.util")
local config = require ("config")

local _M = {}
local string = string
local table = table

local RET = {}
local function convert(_obj)
    local RET = { nodes = {} }
--    RET.nodes = _obj
    for _, v in pairs(_obj) do
        table.insert(RET.nodes,{
           alias = v.name,
           alias_en = v.name,
           pub_key = "0x" .. v.accountId,
           -- tips: this should be `base58`,
           --       but too troublesome.
           address = "0x" .. v.accountId,
           total_vote = v.totalVote,
           website = v.url,
           statement = v.about,
           statement_en = v.about,
           node_type = v.nodeType
        })
    end
    return RET
end


local function normalize(num, unit)
    local unit = unit or config.CHAINX_DECIMAL
    return tonumber(string.format("%f", num/config.CHAINX_DECIMAL))
end

function _M.main()
--local detail = {}
    local res, err = httpc:post(config.CHAINX_RPC, {
        headers = {['Content-Type'] = 'application/json'},
        body = cjson.encode({
            id = 1,
            jsonrpc = "2.0",
            method = "chainx_getIntentions",
            params = setmetatable({}, cjson.empty_array_mt)
        })
    })
    local ok = string.find(res,"<html>")

    if not res or ok then
        RET.error = "request "..config.CHAINX_RPC.."failed: ".. (err or "unanticipated response.") 
        RET.error_teail = res
        return RET
    end

    local totalPower = 0
    local ret = cjson.decode(res)
    if ret.error then
        RET.error = string.format("rpc error %s", ret.err.message)
    else
--detail.st = ret
        for _, node in pairs(ret.result) do
            repeat
                if node and #node.isTrustee ~= 0 then
                    nodeType = 'trustee'
                elseif node.isActive == false then
                    break -- skip non-active nodes
                else
                    nodeType = node.isValidator == true and 'validator' or 'normal'
                end
                if node.totalNomination then
                    totalPower = totalPower + normalize(node.totalNomination)
                end
                table.insert(RET, {
                    name = node.name,
                    nodeType = nodeType,
                    url = node.url,
                    totalVote = normalize(node.totalNomination),
                    selfVote = normalize(node.selfVote),
                    about = node.about,
                    accountId = string.sub(node.account, 3, -1)
                })
            until true
        end
    end

    local res, err = httpc:post(config.CHAINX_RPC, {
        headers = {['Content-Type'] = 'application/json'},
        body = cjson.encode({
            id = 1,
            jsonrpc = "2.0",
            method = "chainx_getPseduIntentions",
            params = setmetatable({}, cjson.empty_array_mt)
        })
    })
    if not res then
        RET.error = "request "..CHAINX_RPC.."failed: "..err
    end
    --util.log(res)

    local ret = cjson.decode(res)
--detail.nd = ret
    if ret.error then
        RET.error = string.format("rpc error %s", ret.err.message)
    else
        for _, coin in pairs(ret.result) do
            if coin.id == "SDOT" then
                totalPower = totalPower + normalize(coin.circulation) * 0.08
            else
                totalPower = totalPower + normalize(coin.power) * normalize(coin.circulation)
            end
        end
    end

    local nominator = {}

    for _, nodeinfo in pairs(RET) do
        local userYield = 1 / totalPower * 14400 * 0.9 * 0.8 * 365
        nodeinfo.userYield = tonumber(string.format("%.4f", userYield))
        if nominator[nodeinfo.accountId] then
            nodeinfo.voter = nominator[nodeinfo.accountId]
        else
            util.log(string.format("> node %s[%s] voter was missing", nodeinfo.name, nodeinfo.accountId))
        end
    end
    RET = convert(RET)
--RET.detail = detail
    return RET
end

return _M
