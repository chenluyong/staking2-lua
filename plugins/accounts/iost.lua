
local cjson = require "cjson"
local config = require "config"

local _M = {}
local RET = {}

function _M.main()
    local args = ngx.req.get_uri_args()
    local acc = args.acc
    if not acc then
        log(ERR, "ERR not iost account provided.")
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
        return {status = 1, error = "request "..IOSTABC_GETACCOUNT.."failed", code = debug.getinfo(1).currentline}
    end

--    log(ERR, ">>response: ".. res.status .. " " .. res.body)

    if res.status ~= 200 then
        RET.exist = false
        RET.error = "account not exist."
    else
        RET.exist = true
    end

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

    RET.status = 0
    return RET
end

return _M
