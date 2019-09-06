local cjson = require "cjson"
local http = require 'resty.http'
local httpc = http.new()
local config = require ("config")

local _M = {}


local RET = {}

local function convert(_t)
--    for _, v in pairs(_t) do 
--    end
    return _t
end



function _M.main_vapor()
    local res,err = httpc:request_uri(config.VAPOR_NODESINFO, {
        method = "GET",
        headers = config.CAMO_UA
    })

    if not res then
        RET.error = "request " .. config.VAPOR_NODESINFO .. "failed: " .. err
        return RET
    end
--    ngx.say((res.body))
    local ret = cjson.decode(res.body)
    nodes = {}
    if ret.code == 200 then
        net_total_vote = ret.data.vote_total_count
        for _, item in pairs(ret.data.lists) do
            nodes[item.pub_key] = {
                alias = item.name,
                alias_en = item.name_en,
                location = item.location,
                location_en = item.location_en,
                address = "",
                logo = "",
                vote_percent = tonumber(string.format("%.4f", item.vote_count / net_total_vote * 100)),
                description = "",
                description_en = "",
                total_vote = item.vote_count,
                voters = 0,
                roi = tonumber(item.ratio),
                pub_key = item.pub_key
            }
--[[
--]]
            local res, err = httpc:request_uri(config.VAPOR_NODEINFO .. item.pub_key, {
                method = "GET",
                headers = config.CAMO_UA
            })
            if res then
                local ret = cjson.decode(res.body)
                if ret.code == 200 then
                    nodes[item.pub_key].address = ret.data.super_node.address
                    nodes[item.pub_key].website = ret.data.super_node_detail.homepage
--                    nodes[item.pub_key].declaration = ret.data.super_node_detail.declaration
--                    nodes[item.pub_key].declaration_en = ret.data.super_node_detail.declaration_en
                    nodes[item.pub_key].description = ret.data.super_node_detail.introduce
                    nodes[item.pub_key].description_en = ret.data.super_node_detail.introduce_en
                    nodes[item.pub_key].logo = ret.data.super_node_detail.logo
                    nodes[item.pub_key].voters = ret.data.pagination.total
                end
            end
--[[]]--
        end
    end
    RET.nodes = {}
    for _, info in pairs(nodes) do
        table.insert(RET.nodes, info)
    end


    return RET
end


function _M.main()
    return _M.main_vapor()
end


return _M
