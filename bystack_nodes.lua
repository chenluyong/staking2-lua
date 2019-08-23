
local cjson = require "cjson"
local redis = require "resty.redis"
local http = require 'resty.http'
local httpc = http.new()

local const = require "constant"

local args = ngx.req.get_uri_args()
local rds = redis:new()
rds:set_timeout(1000)

local log = ngx.log
local ERR = ngx.ERR

local RET = {}

-- https://api.bystack.com/supernode/v1/sn-table
BYSTACK_NODESINFO = "https://api.bystack.com/supernode/v1/sn-table"
BYSTACK_NODESDETAIL = "https://vapor.blockmeta.com/api/v1/nodes?page=1&limit=200"

local ok, err = rds:connect("127.0.0.1", 6379)
if not ok then
    log(ERR, "failed to connect rds.")
    RET.error = "internal error: rfailed."
end

local ok, err = rds:get('bystack:nodes')
if not ok then
    log(ERR, "get bystack nodes info from rds failed: "..err)
    RET.error = "internal error: rfailed."
elseif ok == ngx.null then

    local res, err = httpc:request_uri(BYSTACK_NODESINFO, { method = "GET",
    headers = const.CAMO_UA
    })

    if not res then
        log(ERR, "request" .. BYSTACK_NODESINFO .. "failed: " .. err )
        RET.error = "request " .. BYSTACK_NODESINFO .. "failed: " .. err
    end

    local ret = cjson.decode(res.body)

    if ret.status and ret.status ~= "success" then
        log(ERR, "bystack api return error, abort: "..ret.error)
        RET.error = ret.error
    else
        local nodeinfo = {}

        for _, node in pairs(ret.data) do
            if node.name ~= "-" then
                nodeinfo[node.name] = {
                    name = node.name,
                    introduce = node.introduce,
                    icon = string.format("https://api.bystack.com/supernode/v1%s", node.reserved_1),
                    --totalVote = node.vote_count / 100000000,
                    votePercent = tonumber(string.format("%.4f", node.percent)),
                    commissionFee = 100 - tonumber(string.match(node.reward, "%d+")) .. "%",
                    --nodeAddress = node.reserved_2,
                    --nodePubKey = node.public_key,
                    homePage = node.homepage
                }
            end
        end

        local res, err = httpc:request_uri(BYSTACK_NODESDETAIL, {
            method = "GET",
            headers = const.CAMO_UA
        })

        if not res then
            log(ERR, "request" .. BYSTACK_NODESDETAIL .. "failed: " .. err )
        end

        local ret = cjson.decode(res.body)

        if ret.code and ret.code == 200 then
            local netTotalVote = ret.data.vote_total_count
            for _, node in pairs(ret.data.lists) do
                local name = node.name -- avoid empty name
                if nodeinfo[name] then
                    nodeinfo[name].totalVote = node.vote_count / 100000000
                    nodeinfo[name].nodeType = node.type
                    nodeinfo[name].nodeAddress = node.address
                    nodeinfo[name].nodePubKey = node.pub_key
                    nodeinfo[name].userYield = node.expected_return
                    nodeinfo[name].votePercent = tonumber(string.format("%.4f", node.vote_count / netTotalVote))
                else
                    log(ERR, ">>name: '"..name.."' not found")
                end
            end
        else
            log(ERR, "bystack api return error, abort: ".. ret.code)
        end

        for _, info in pairs(nodeinfo) do
            table.insert(RET, info)
        end

    end

    if not RET.error then
        ok, err = rds:set('bystack:nodes', cjson.encode(RET))
        if not ok then
            log(ERR, "save result to redis failed: "..err)
        end
        ok, err = rds:expire('bystack:nodes', 3600)
        if not ok then
            log(ERR, "set key bystack:nodes expire failed")
        end
    end
else
    log(ERR, "bystack nodes info found in cache")
    RET = cjson.decode(ok)
end


local ok, err = rds:set_keepalive(30000, 100)
if not ok then
    RET.error = "internal error: rfailed."
end

ngx.say(cjson.encode(RET))
