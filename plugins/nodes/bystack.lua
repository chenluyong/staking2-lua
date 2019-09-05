
local cjson = require "cjson"
local http = require 'resty.http'
local httpc = http.new()
local config = require ("config")

local _M = {}


local RET = {}

function _M.main()
    local res, err = httpc:request_uri(config.BYSTACK_NODESINFO, {
        method = "GET",
        headers = config.CAMO_UA
    })

    if not res then
--        log(ERR, "request" .. BYSTACK_NODESINFO .. "failed: " .. err )
        RET.error = "request " .. BYSTACK_NODESINFO .. "failed: " .. err
    end

    local ret = cjson.decode(res.body)

    if ret.status and ret.status ~= "success" then
--        log(ERR, "bystack api return error, abort: "..ret.error)
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

        local res, err = httpc:request_uri(config.BYSTACK_NODESDETAIL, {
            method = "GET",
            headers = config.CAMO_UA
        })

        if not res then
--            log(ERR, "request" .. BYSTACK_NODESDETAIL .. "failed: " .. err )
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
--                    log(ERR, ">>name: '"..name.."' not found")
                end
            end
        else
--            log(ERR, "bystack api return error, abort: ".. ret.code)
        end

        for _, info in pairs(nodeinfo) do
            table.insert(RET, info)
        end

    end

    return RET
end

return _M
