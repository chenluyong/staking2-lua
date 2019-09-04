
local cjson = require "cjson"
local redis = require "resty.iredis"
local rds = redis:new()
local http = require "resty.ihttp"
local httpc = http:new()
local util = require "util"

local string = string
local table = table

--curl -H "Content-Type: application/json" -X POST -d '{"code":"eosio","json":true,"limit":1000,"scope":"eosio","table":"bps"}' 'https://w3.eosforce.cn/v1/chain/get_table_rows' | jq
local EOSC_NODESINFO = "https://w3.eosforce.cn/v1/chain/get_table_rows"

local RET = {}

local function split(str, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for s in string.gmatch(str, "([^"..sep.."]+)") do
        table.insert(t, s)
    end
    return t
end

local function normalize(str)
    local val = split(str)
    return tonumber(val[1])
end

local function sort_by_vote(a, b)
    return a.totalVote > b.totalVote
end

local ok, err = rds:get('eosc:nodes')
if not ok then
    local res, err = httpc:post(EOSC_NODESINFO, {
        headers = {['Content-Type'] = 'application/json;charset=UTF-8'},
        body = cjson.encode({
            code = "eosio",
            json = true,
            limit = 1000,
            scope = "eosio",
            table = "bps"
        })
    })
    if not res then
        RET.error = "request "..EOSC_NODESINFO.."failed: "..err
    end

    local nodesinfo = {}
    local totalvoted = 0

    local ret = cjson.decode(res)
    if not ret.rows then
        RET.error = string.format("rpc error, no data returned")
    else
        for _, node in pairs(ret.rows) do
            totalvoted = totalvoted + node.total_staked
            table.insert(nodesinfo, {
                name = node.name,
                homePage = node.url,
                totalVote = node.total_staked,
                nodePubKey = node.block_signing_key,
                commissionFee = node.commission_rate / 100 / 100
            })
        end
    end

    for _, node in pairs(nodesinfo) do
        if node.totalVote == 0 then
            node.votePrecent = 0
            node.userYield = 0
        else
            local votePrecent = node.totalVote / totalvoted
            local userYield = 2.7 * 28800 * 365 * votePrecent * 0.7 * (1 - node.commissionFee) / node.totalVote
            node.votePrecent = tonumber(string.format("%.4f", votePrecent))
            node.userYield = tonumber(string.format("%.6f", userYield))
        end
        --util.log(string.format(">> name: %s, vote: %s(%s), fee:%s, yield: %s.",
            --node.name,
            --node.totalVote,
            --node.votePrecent,
            --(1 - node.commissionFee),
            --node.userYield)
        --)
    end

    table.sort(nodesinfo, sort_by_vote)
    for i=1, #nodesinfo do
        if i < 24 then
            nodesinfo[i].type = "BP"
        elseif nodesinfo[i].votePrecent > 0.05 then
            nodesinfo[i].type = "Reward"
        else
            nodesinfo[i].type = "Normal"
        end
        nodesinfo[i].rank = i
    end

    RET = nodesinfo

    if not RET.error then
        ok, err = rds:set('eosc:nodes', cjson.encode(RET))
        if not ok then
            util.log("save result to redis failed: "..err)
        end
        ok, err = rds:expire('eosc:nodes', 3600)
        if not ok then
            util.log("set key expire failed")
        end
    end
else
    RET = cjson.decode(ok)
end

ngx.say(cjson.encode(RET))
