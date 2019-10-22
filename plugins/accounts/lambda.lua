
local cjson = require "cjson"
local config = require "config"

local _M = {}
local RET = {}

local function get_24_hour(account)
    http = require "resty.http"
    httpc = http.new()

    local req_uri = string.format("https://explorer.lambdastorage.com/api/tx/txListByAddress?address=%s&pageNum=1&showNum=10&msgType=all", account)
    local res, err = httpc:request_uri(req_uri, {
        method = "GET",
        headers = config.CAMO_UA
    })
    if not res then
        return {status = 1, error = "request "..req_uri.."failed", code = debug.getinfo(1).currentline}
    end
    local ret = cjson.decode(res.body)
    local time_with_24_hour = os.time() - (24 * 60 * 60)

_M.code = debug.getinfo(1).currentline
    if ret then
        local amount_24_hour = 0
        for _,action in pairs(ret.data.tx_list) do
        for _, tx in pairs(action.txs) do
            local _, _, y, m, d, hour, min, sec = string.find(tx.create_time, "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
            local timestamp = os.time({year=y, month = m, day = d, hour = _hour, min = _min, sec = _sec});
            local ulamb_amount = 0
            if time_with_24_hour < timestamp then
                local action_name = tx.action
                if true then 
                    local b,e = string.find(tx.amount, 'ulamb')
                    if b and e then
                        ulamb_amount = tonumber(string.sub(tx.amount,1,b-1)) / 1000000
                    end
                end

                if action_name == "withdraw_delegator_reward" or action_name == "send" then
                    local to = tx.to
                    if to == account then
                        amount_24_hour = amount_24_hour + tonumber(ulamb_amount)
                    end
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

    local ret = cjson.decode(res.body)

    if #ret.data.available == 0 then
        RET.exist = false
        RET.error = "account not exist."
    else
        RET.exist = true
    end


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
    RET.recentFunding = get_24_hour(acc)
_M.code = 0
    RET.status = 0
    return RET
end

return _M
