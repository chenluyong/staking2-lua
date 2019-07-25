
local cjson = require "cjson"
local redis = require "resty.redis"
http = require 'resty.http'
httpc = http.new()

local const = require "constant"

local args = ngx.req.get_uri_args()
local rds = redis:new()
rds:set_timeout(1000)

local log = ngx.log
local ERR = ngx.ERR

local RET = {}

-- https://api.bystack.com/supernode/v1/sn-table
BYSTACK_NODESINFO = "https://api.bystack.com/supernode/v1/sn-table"
BYSTACK_NODESDETAIL = "http://vapor.blockmeta.com/api/v1/nodes?page=1&limit=200"

local ok, err = rds:connect("127.0.0.1", 6379)
if not ok then
    log(ERR, "failed to connect rds.")
    RET.error = "internal error: rfailed."
end

local nodeinfo = {}

local res, err = httpc:request_uri(BYSTACK_NODESINFO, {
    method = "GET",
    headers = const.CAMO_UA
})

if not res then
    log(ERR, "request" .. BYSTACK_NODESINFO .. "failed: " .. err )
end

local ret = cjson.decode(res.body)

if ret.status and ret.status ~= "success" then
    log(ERR, "bystack api return error, abort: "..ret.error)
else
    for _, node in pairs(ret.data) do
        if node.name ~= "-" then
            nodeinfo[node.name] = {
                name = node.name,
                introduce = node.introduce,
                icon = string.format("https://api.bystack.com/supernode/v1%s", node.reserved_1),
                --totalVote = node.vote_count,
                votePercent = tonumber(string.format("%.4f", node.percent)),
                commissionFee = 100 - tonumber(string.match(node.reward, "%d+")) .. "%",
                --nodeAddress = node.reserved_2,
                --nodePubKey = node.public_key,
                homePage = node.homepage
            }
        end
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


local ok, err = rds:set_keepalive(30000, 100)
if not ok then
    RET.error = "internal error: rfailed."
end

ngx.say(cjson.encode(RET))
