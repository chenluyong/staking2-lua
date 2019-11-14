local cjson = require "cjson"
local base58 = require("resty.base58")
local bit = require("bit")
local http = require "resty.ihttp"
local httpc = http.new()
local config = require ("config")



local _M = {}


local RET = {}


function validate_address(_addr)
    return false
end

function _M.main()
_M.code = debug.getinfo(1).currentline
RET = {}
    local args = ngx.req.get_uri_args()
    local addr = args.acc
    if not addr then
--        log(ERR, "ERR not nuls address provided.")
        return  {status = 1, error = "missing arguments", code = debug.getinfo(1).currentline}
    end


    if validate_address(addr) then
        return  {status = 1, error = "invalid address arguments", code = debug.getinfo(1).currentline}
    end

    local res, err = httpc:get("https://api.cosmostation.io/v1/account/"..addr)

    if not res then
        return  {error = "request account failed.", code = debug.getinfo(1).currentline}
    end
    local ret = cjson.decode(res)
    if ret.error_code == 203 then
        return { error = "address not exist.", code = debug.getinfo(1).currentline }
    end

    local i = 1
    while i <= #ret.balance do
        if ret.balance[i].denom == 'uatom' then
            RET.balanceUsable = tonumber(ret.balance[i].amount) / 1000000
        end
        i = i + 1
    end
    i = 1
    while i <= #ret.rewards do
        if ret.rewards[i].denom == 'uatom' then
            RET.balanceLocking = tonumber(ret.rewards[i].amount) / 1000000
            RET.recentFunding = RET.balanceLocking
        end
        i = i + 1
    end
    for _, delegation in pairs(ret.delegations) do
        RET.balanceLocking = RET.balanceLocking + tonumber(delegation.amount) / 1000000
    end
    RET.balanceTotal = RET.balanceUsable + RET.balanceLocking
    RET.balance = RET.balanceTotal
    RET.pleged = false
    if RET.balanceLocking > 0 then
        RET.pleged = true
    end
_M.code = 0
    return RET
end


return _M
