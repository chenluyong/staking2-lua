--[[
[iost nodes example]
- request url:http://192.168.1.93/iost/getnodes?page=1&size=50&sort_by=votes&order=desc&search=
- return body:
{
    "page":1,
    "producers":[
        {
            "dividend_rate":0.064254763168375,
            "account":"huobipool",
            "isProducer":true,
            "dividend_rate_ranking":77,
            "statement":"",
            "ReceivedAward":6395219.6801236,
            "social_media":{
                "twitter":"https://twitter.com/eos_huobipool"
            },
            "ranking":1,
            "tag":{
                "daily_dividend":false,
                "tier_info":"19Q2",
                "Tier":2
            },
            "alias":"chinese name",
            "block_count":1515807,
            "logo":"https://assets.biss.com/iost/iost_bl_3.png",
            "rate_of_dividend":[
                50,
                50,
                0
            ],
            "description":"",
            "alias_en":"Huobi Pool",
            "type_en":"Exchange",
            "voters":191,
            "contribute":205482307081.55,
            "status":1,
            "description_en":"Huobi pool is the first-ever pool platform which combines cryptocurrency mining and exchanging activities. Backed by the powerful resources and financial support provided by Huobi Group, Huobi excels in R&D abilities and has a large user base around the world, and can accommodate various mechanisms such as PoW, PoS, and DPos.",
            "last_create_block_time":1564653992500100000,
            "_id":"5c84f5e7b5f052038764b772",
            "statement_en":"We will do our utmost efforts to carry out the mission of building up IOST ecosystem and maintaining the network security. We will help to market IOST and be fully involved in the IOST community development. We will concentrate on what we are doing and forge a synergy with other nodes to push the ship of the IOST sailing far and beyond.",
            "url":"https://www.huobipool.com/",
            "pubkey":"31ibPtxBLW5e7yTsV9XSDVZ5Hs5w9n7UtHNzXpuP7EUB",
            "online":true,
            "type":"exchange",
            "loc":"China",
            "votes":422231297.56286,
            "netId":"12D3KooWQb2rKmc2biceGCE2LTxQGRgmdn9cigiytGXx4K585Y5a"
        }
    ],
    "size":50,
    "total":359
}
]]--

-- modules
local cjson = require "cjson"


-- var
IOST_NODESINFO = "https://www.iostabc.com/api/producers"
local RET = {}
local args = ngx.req.get_uri_args()
local log = ngx.log
local ERR = ngx.ERR
local acc = args.acc
if not acc then
    acc = "page=1&size=50&sort_by=votes&order=desc&search="
end


-- function
local function get_producers_cache(key)
    return nil, nil
end

local function set_producers_cache(key, value)
    return nil 
end

local function get_producers(acc)
    local http = require 'resty.ihttp'
    local httpc = http.new()
    local _, rds_res = get_producers_cache(acc)
    
    if rds_res then
        ret = cjson.decode(rds_res)
    else
        request_url = string.format("%s?%s", IOST_NODESINFO, acc)
        local res, err = httpc:get(request_url)

        if not res then
            RET.error = "request "..IOST_NODESINFO.." failed: "..err
        else
            ret = cjson.decode(res)
        end
    end

    return ret
end


-- logic
RET = get_producers(acc)

-- response
ngx.header.content_type = 'application/json'
ngx.say(cjson.encode(RET))
