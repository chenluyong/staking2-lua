local _M = {}

local cjson = require "cjson"
local config = require "config"
local http = require 'resty.ihttp'
local httpc = http.new()


local function get_producers(args)
--    local http = require 'resty.ihttp'
--    local httpc = http.new()
    local request_url = string.format("%s/%s", config.IOST_NODESINFO, args)
    
    -- request 
    local res, err = httpc:get(request_url)
    if not res then
        return { error = "request "..IOST_NODESINFO.." failed: "..err }
    else
        ret = cjson.decode(res)
        ret.status = 0
    end
    return ret
end


local function convert(_obj)
    -- convert object to std node info object
    local ret = {}
    local nodes = {}

    local net_total_vote = 0
    local res, err = httpc:get(config.IOSTABC_GETTOTALVOTE)

    if res then
        net_total_vote = cjson.decode(res).allVotes
    end

    for _, item in pairs(_obj.producers) do
        local vote_percent = 0
        if net_total_vote ~= 0 then
            vote_percent = item.votes / net_total_vote * 100
        end

        table.insert(nodes, {
            alias = item.alias,
            alias_en = item.alias_en,
            address = item.account,
            logo = item.logo,
            statement = item.statement,
            statement_en = item.statement_en,
            description = item.description,
            description_en = item.description_en,
            location = item.loc,
            location_en = item.loc,
            website = item.url,
            total_vote = item.votes,
            pub_key = item.pubkey,
            voters = item.voters,
            roi = item.dividend_rate*100,
            vote_percent = vote_percent
        })
    end

--[[
    local kyes = {}
    for k, _ in pairs(_obj.producers) do
        table.insert(keys, k or 0)
    end
    ret.keys = keys
    ret.source = _obj.producers
]]--
    ret.nodes = nodes
    return ret
end


function _M.main()
    -- get nodes info
    args_len = #ngx.var.request_uri - #ngx.var.uri + 1
    local args = "?page=1&size=50&sort_by=votes&order=desc&search="
    if args_len > 3 then
        args = string.sub(ngx.var.request_uri, #ngx.var.uri + 1, #ngx.var.request_uri)
    end
    local ret_table = get_producers(args)

    return convert(ret_table)
end


return _M
