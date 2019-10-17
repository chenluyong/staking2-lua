
local cjson = require "cjson"
local config = require "config"

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
        return {status = 1, error = "request "..req_uri.."failed", code = debug.getinfo(1).currentline}
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
    local args = ngx.req.get_uri_args()
    local acc = args.acc
    if not acc then
        log(ERR, "ERR not iost account provided.")
        return {status = 1, error = "missing arguments", code = debug.getinfo(1).currentline}
    end

    http = require "resty.http"
    httpc = http.new()

_M.code = debug.getinfo(1).currentline
    local res, err = httpc:request_uri( string.format("https://explorer.lambdastorage.com/api/proxy/balance?address=%s", acc), {
        method = "GET",
        headers = config.CAMO_UA
    })

    if not res then
        return {status = 1, error = "request "..config.IOSTABC_GETACCOUNT.."failed", code = debug.getinfo(1).currentline}
    end

--    log(ERR, ">>response: ".. res.status .. " " .. res.body)

    if res.status ~= 200 then
        RET.exist = false
        RET.error = "account not exist."
    else
        RET.exist = true
    end

    local ret = cjson.decode(res.body)
_M.code = debug.getinfo(1).currentline
    if ret then
        local voted = ret.data.delegated / 1000000
        local balance = 0
_M.code = debug.getinfo(1).currentline
        if #ret.data.delegate_list > 0 then
            RET.pledged = true
        else
            RET.pledged = false
        end

_M.code = debug.getinfo(1).currentline
        local available = ret.data.available
        for _, token in pairs(available) do
            if token.denom == "ulamb" then
                balance = tonumber(token.amount) / 1000000
            end
        end

        RET.balanceUsable = balance
        RET.balanceLocking = voted
        RET.balanceTotal = RET.balanceLocking + RET.balanceUsable
        RET.balance = RET.balanceTotal

    end
_M.code = 0
--    RET.recentFunding = get_24_hour(acc)
    RET.status = 0
    return RET
end

return _M
