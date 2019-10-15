local cjson = require "cjson"
local http = require "resty.ihttp"
local httpc = http:new()
local util = require "staking2.util"
local config = require "config"

local log = ngx.log
local ERR = ngx.ERR

local _M = {}

local string = string
local table = table

local args = ngx.req.get_uri_args()

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


local function get_24_hour(account)
    http = require "resty.http"
    httpc = http.new()
_M.code = debug.getinfo(1).currentline
    local req_uri = "https://explorer.eosforce.io/web/get_action"
    local request_body = cjson.encode({
              account_name = account, 
              limit = 10000000000, 
              offset = 1, 
              pos = 0, 
              pre_id = -1})
    local res, err = httpc:request_uri(req_uri, {
        method = "POST",
        headers = {
            ['User-Agent'] = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36',
           ['Content-Type'] = "application/json"
        },
--        headers = config.CAMO_UA, 
        body = request_body 
    })

_M.code = debug.getinfo(1).currentline

    if not res then
        return {status = 1, error = "request "..req_uri.."failed", code = debug.getinfo(1).currentline}
    end

    local ret = cjson.decode(res.body)
    local time_with_24_hour = os.time() - (24 * 60 * 60)
_M.code = debug.getinfo(1).currentline

    if ret then
        local amount_24_hour = 0
        for _,action in pairs(ret.data) do
            local _, _, y, m, d, hour, min, sec = string.find(action.block_time, "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
            local timestamp = os.time({year=y, month = m, day = d, hour = _hour, min = _min, sec = _sec});
            if time_with_24_hour < timestamp then
                if action.name == "transfer" and action.token_type == "EOS" then
                    local to = action.to
                    if to == account then
                        amount_24_hour = amount_24_hour + tonumber(string.sub(action.quantity,1,-4))
                    end
                end
            end
        end
       return amount_24_hour
    end
end

local function normalize(str)
    local val = split(str)
    return tonumber(val[1])
end

function _M.main()
--if true then return { aaa = "aaa"} end
    local addr = args.acc
    if not addr then
    --    log(ERR, "ERR not bystack address provided.")
        return {
            status = 1,
            error = "missing arguments",
            code = debug.getinfo(1).currentline
        }
    end

    local res, err = httpc:post(config.EOSC_SEARCHACCOUNT, {
        headers = {['Content-Type'] = 'application/json;charset=UTF-8'},
        timout = 10,
        body = cjson.encode({
            category = "accounts",
            key_word = addr
        })
    })

    if not res then
        RET.status = 1
        RET.error = "can not access data"
        RET.message = err
        return RET
    end

    local ret = cjson.decode(res)
    if ret.data and #ret.data == 0 then
        RET.exist = false
        RET.error = string.format("account doesn't exist")
    else
        local res, err = httpc:post(config.EOSC_GETACCOUNT, {
            headers = {['Content-Type'] = 'application/json;charset=UTF-8'},
            timeout = 10,
            body = cjson.encode({
                account_name = addr
            })
        })
        if not res then
            RET.status = 1
            RET.error = "can not access data"
            RET.message = err
            return RET
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
            if locking == 0 and tonumber(ret.data.staked) ~= 0 then
                -- the explorer will calc 'staked' with txs history,
                -- but not every vote tx will correct record in raw data.
                -- should be explorer bug.
                locking = tonumber(ret.data.staked)
            end
            RET.balanceLocking = locking
            RET.balanceTotal = RET.balanceUsable + RET.balanceLocking
            if locking == 0 then
                RET.pledged = false
            else
                RET.pledged = true
            end
        end

    end
    RET.recentFunding = get_24_hour(addr)
_M.code = 0
    return RET
end


return _M
