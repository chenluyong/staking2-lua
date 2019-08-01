
local cjson = require "cjson"
local redis = require "resty.iredis"
local rds = redis:new()
local http = require "resty.ihttp"
local httpc = http:new()
local util = require "util"

local CHAINX_DECIMAL = 100000000

local CHAINX_RPC = "http://127.0.0.1:8081/chainx/"
if jit and jit.os and jit.os == "OSX" then
    CHAINX_RPC = "http://121.196.208.250:8081/chainx/" -- for local test
end

local RET = {}

local function normalize(num, unit)
    local unit = unit or CHAINX_DECIMAL
    return tonumber(string.format("%f", num/CHAINX_DECIMAL))
end

local ok, err = rds:get('chainx:nodes')
if not ok then
    local res, err = httpc:post(CHAINX_RPC, {
        headers = {['Content-Type'] = 'application/json'},
        body = cjson.encode({
            id = 1,
            jsonrpc = "2.0",
            method = "chainx_getIntentions",
            params = setmetatable({}, cjson.empty_array_mt)
        })
    })
    if not res then
        RET.error = "request "..CHAINX_RPC.."failed: "..err
    end

    local totalPower = 0

    local ret = cjson.decode(res)
    if ret.error then
        RET.error = string.format("rpc error %s", ret.err.message)
    else
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
                    totalVote = normalize(node.totalNomination),
                    selfVote = normalize(node.selfVote),
                    accountId = string.sub(node.account, 3, -1)
                })
            until true
        end
    end

    local res, err = httpc:post(CHAINX_RPC, {
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

    for _, nodeinfo in pairs(RET) do
        local userYield = 1 / totalPower * 14400 * 0.9 * 0.8 * 365
        nodeinfo.userYield = tonumber(string.format("%.4f", userYield))
    end

    if not RET.error then
        ok, err = rds:set('chainx:nodes', cjson.encode(RET))
        if not ok then
            log(ERR, "save result to redis failed: "..err)
        end
        ok, err = rds:expire('chainx:nodes:', 3600)
        if not ok then
            log(ERR, "set key expire failed")
        end
    end
else
    RET = cjson.decode(ok)
end

ngx.say(cjson.encode(RET))
