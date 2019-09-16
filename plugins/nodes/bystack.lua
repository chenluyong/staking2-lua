local cjson = require "cjson"
local http = require 'resty.http'
local httpc = http.new()
local config = require ("config")

local _M = {}


_M.code = debug.getinfo(1).currentline

local RET = {}

local function convert(_t)
--    for _, v in pairs(_t) do 
--    end
    return _t
end

function _M.main_btm()
_M.code = debug.getinfo(1).currentline
    local res, err = httpc:request_uri(config.BYSTACK_NODESINFO, {
        method = "GET",
        headers = config.CAMO_UA
    })
--local detail = {}
    if not res then
--        log(ERR, "request" .. BYSTACK_NODESINFO .. "failed: " .. err )
        RET.error = "request " .. config.BYSTACK_NODESINFO .. "failed: " .. err
    end
_M.code = debug.getinfo(1).currentline

    local ret = cjson.decode(res.body)

    if ret.status and ret.status ~= "success" then
--        log(ERR, "bystack api return error, abort: "..ret.error)
        RET.error = ret.error
    else
--detail.st = ret
        local nodeinfo = {}

_M.code = debug.getinfo(1).currentline

        for _, node in pairs(ret.data) do
            if node.name ~= "-" then
                nodeinfo[node.name] = {
                    alias = node.name,
                    alias_en = node.name,
                    company_type = node.node_type,
                    company_type_en = node.node_type_en,
                    address = node.wallet_address,
                    description = node.introduce,
                    description_en = node.introduce,
                    statement = node.declaration,
                    statement_en = node.declaration_en,
                    location = node.location,
                    location_en = node.location_en,
                    logo = string.format("https://api.bystack.com/supernode/v1%s", node.reserved_1),
                    --vote_amount = node.vote_count / 100000000,
                    --vote_percent = tonumber(string.format("%.4f", node.percent)),
                    commission_fee = 100 - tonumber(string.match(node.reward, "%d+")),
                    --nodeAddress = node.reserved_2,
                    --nodePubKey = node.public_key,
                    website = node.homepage
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
--detail.nd = ret
_M.code = debug.getinfo(1).currentline

        if ret.code and ret.code == 200 then
            local netTotalVote = ret.data.vote_total_count
            for _, node in pairs(ret.data.lists) do
                local name = node.name -- avoid empty name
                if nodeinfo[name] then
                    nodeinfo[name].total_vote = node.vote_count / 100000000
                    nodeinfo[name].type = node.type
                    --nodeinfo[name].ip = node.address
                    nodeinfo[name].pub_key = node.pub_key
                    nodeinfo[name].roi = (node.expected_return)
                    nodeinfo[name].vote_percent = tonumber(string.format("%.4f", node.vote_count / netTotalVote)) * 100
                else
--                    log(ERR, ">>name: '"..name.."' not found")
                end
            end
        else
--            log(ERR, "bystack api return error, abort: ".. ret.code)
        end
        RET.nodes = {}
        for _, info in pairs(nodeinfo) do
            table.insert(RET.nodes, info)
        end

    end

_M.position = debug.getinfo(1).currentline

--RET.detail = detail
    return convert(RET)
end

function _M.main()
    ret = _M.main_btm()
_M.code = 0
    return ret
end


return _M
