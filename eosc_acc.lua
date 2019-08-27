
local cjson = require "cjson"
local redis = require "resty.iredis"
local rds = redis:new()
local http = require "resty.ihttp"
local httpc = http:new()
local util = require "util"

local string = string
local table = table

local args = ngx.req.get_uri_args()

--curl -H "Content-Type: application/json" -X POST -d '{"account_name":"bepal.eosc"}' 'https://explorer.eosforce.io/web/get_account_info' | jq
local EOSC_GETACCOUNT = "https://explorer.eosforce.io/web/get_account_info"

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

local addr = args.acc
if not addr then
    log(ERR, "ERR not bystack address provided.")
    ngx.say(cjson.encode({status = 1, error = "missing arguments"}))
    return
end

local ok, err = rds:get('eosc:account:'..addr)
if not ok then
    local res, err = httpc:post(EOSC_GETACCOUNT, {
        headers = {['Content-Type'] = 'application/json;charset=UTF-8'},
        body = cjson.encode({
            account_name = addr
        })
    })
    if not res then
        RET.error = "request "..EOSC_GETACCOUNT.."failed: "..err
    end

    local ret = cjson.decode(res)
    if not ret.data then
        RET.exist = false
        RET.error = string.format("account don't exist")
    else
        udata = cjson.decode(ret.data.origin_data)
        RET.exist = true
        RET.balance = normalize(udata.core_liquid_balance)
        RET.balanceUsable = normalize(udata.core_liquid_balance)
        local locking = 0
        for _, vote in pairs(udata.votes) do
            if vote then
                locking = locking + normalize(vote.voteage.staked)
            end
        end
        for _, fixvote in pairs(udata.fix_votes) do
            if fixvote then
                locking = locking + normalize(fixvote.vote)
            end
        end
        RET.balanceLocking = locking
        RET.balanceTotal = RET.balanceUsable + RET.balanceLocking
        RET.pledged = locking == 0 and false or true
    end

    if not RET.error then
        ok, err = rds:set('eosc:account:'..addr, cjson.encode(RET))
        if not ok then
            util.log("save result to redis failed: "..err)
        end
        ok, err = rds:expire('eosc:account:'..addr, 300)
        if not ok then
            util.log("set key expire failed")
        end
    end
else
    RET = cjson.decode(ok)
end

ngx.say(cjson.encode(RET))
