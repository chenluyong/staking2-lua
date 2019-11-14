
local cjson = require "cjson"
local config = require "config"
local log = ngx.log
local ERR = ngx.ERR
local _M = {}
local RET = {}

local function get_24_hour(account)
    http = require "resty.http"
    httpc = http.new()

    local req_uri = string.format("https://www.iostabc.com/api/account/%s/actions?page=1&size=20", account)
    local res, err = httpc:request_uri(req_uri, {
        method = "GET",
        headers = config.CAMO_UA
    })
    if not res then
RET.warning = "request ".. req_uri .. "error"
        return 0
    end
     
    local ret = cjson.decode(res.body)
    local time_with_24_hour = os.time() - (24 * 60 * 60)

    if ret then
        local amount_24_hour = 0
        for _,action in pairs(ret.actions) do
            local _, _, y, m, d, hour, min, sec = string.find(action.created_at, "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
            local timestamp = os.time({year=y, month = m, day = d, hour = _hour, min = _min, sec = _sec});
            if time_with_24_hour < timestamp then
                local action_name = action.action_name
                local data_obj = cjson.decode(action.data)

                if action_name == "transfer" and data_obj[1] == "iost" then
                    local to = action.to
                    if to == account then
                        amount_24_hour = amount_24_hour + tonumber(data_obj[4])
                    end
                end
            end
        end
       return amount_24_hour
    end
end

function _M.main()
_M.code = debug.getinfo(1).currentline
RET = {}
    local args = ngx.req.get_uri_args()
    local acc = args.acc
    if not acc then
        log(ERR, "ERR not iost account provided.")
_M.code = debug.getinfo(1).currentline
        return {status = 1, error = "missing arguments", code = debug.getinfo(1).currentline}
    end

--    log(ERR, "iost acc " .. acc .. " not found in rds")
    --request from iostabc.com
    http = require "resty.http"
    httpc = http.new()

    local res, err = httpc:request_uri( string.format("%s/%s/0", config.IOSTABC_GETACCOUNT, acc), {
        method = "GET",
        headers = config.CAMO_UA
    })

    if not res then
_M.code = debug.getinfo(1).currentline
        return {status = 1, error = "request "..config.IOSTABC_GETACCOUNT.."failed", code = debug.getinfo(1).currentline}
    end


    if res.status ~= 200 then
        RET.exist = false
        RET.error = "account not exist."
        log(ERR, ">> response: ".. res.status .. " " .. res.body)
        log(ERR, ">> response: ".. cjson.encode(RET))
_M.code = debug.getinfo(1).currentline
        return RET
    else
        RET.exist = true
    end

_M.code = debug.getinfo(1).currentline
    local ret = cjson.decode(res.body)
    if ret and ret.name then
        local voted = 0
        local pledged = 0

        if table.getn(ret.vote_infos) > 0 then
            RET.pledged = true
        else
            RET.pledged = false
        end

        if #ret.vote_infos >= 1 then
            for _, vote in pairs(ret.vote_infos) do
                if vote.votes then voted = voted + vote.votes end
            end
        end
        if #ret.gas_info.pledged_info >= 1 then
            for _, pledge in pairs(ret.gas_info.pledged_info) do
                if pledge.amount then pledged = pledged + pledge.amount end
            end
        end

        RET.balanceUsable = ret.balance
        RET.balanceLocking = voted
        RET.balanceTotal = RET.balanceLocking + RET.balanceUsable + pledged
        RET.balance = RET.balanceTotal

    end
    RET.recentFunding = get_24_hour(acc)
    RET.status = 0
_M.code = 0
    return RET
end

return _M
