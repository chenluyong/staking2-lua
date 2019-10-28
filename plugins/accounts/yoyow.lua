local cjson = require "cjson"
local base58 = require("resty.base58")
local bit = require("bit")
local http = require "resty.ihttp"
local httpc = http.new()
local config = require ("config")
local _M = {}
local RET = {}

function get_24_hour(_addr)
    local request_url = string.format("https://explorer.yoyow.org/api/v1/get_relative_history?uid=%s&op_type=&order=desc&offset=0&limit=10", _addr)
    local res, err = httpc:get(request_url)
    if err or not res then
        RET.warning = "request 24 hour transfer error."
        return 0
    end
--    if true then return request_url  end
    local ret = cjson.decode(res)
    local amount_24_hour = 0
    local time_with_24_hour = os.time() - (24 * 60 * 60)
    for _, tx in pairs(ret.rows) do
        local _, _, y, m, d, hour, min, sec = string.find(tx.block_time, "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
        local timestamp = os.time({year=y, month = m, day = d, hour = _hour, min = _min, sec = _sec});
        if time_with_24_hour < timestamp then
            if tx.infos[1] == 0 then
--if true then return tx.infos[1] end
                if tonumber(_addr) == tx.infos[2].to then
                    if tx.infos[2].amount.asset_id == 0 then
                        amount_24_hour = amount_24_hour + (tx.infos[2].amount.amount / 100000)
                    end
                end
            end
        end
    end
    return amount_24_hour
end


function validate_address(_addr)
    return false
end

function _M.main()
_M.code = debug.getinfo(1).currentline

    local args = ngx.req.get_uri_args()
    local addr = args.acc
    if not addr then
        return  {status = 1, error = "missing arguments", code = debug.getinfo(1).currentline}
    end

    if validate_address(addr) then
        return  {status = 1, error = "invalid address arguments", code = debug.getinfo(1).currentline}
    end

    local res, err = httpc:get("https://explorer.yoyow.org/api/v1/get_full_account_with_ext?uid="..addr)

    if err or not res then
        return  {error = "request account failed.", code = debug.getinfo(1).currentline}
    end
    
    local pos = string.find(res,"<html>")
    if pos then
        return { error = "address not exist.", code = debug.getinfo(1).currentline }
    end
    local ret = cjson.decode(res)

    if type(ret.statistics.core_balance) == 'string' then
        ret.statistics.core_balance = tonumber(ret.statistics.core_balance)
    end
    if type(ret.statistics.total_witness_pledge) == 'string' then
        ret.statistics.total_witness_pledge = tonumber(ret.statistics.total_witness_pledge)
    end
    if type(ret.statistics.prepaid) == 'string' then
        ret.statistics.prepaid = tonumber(ret.statistics.prepaid)
    end

    RET.balanceUsable = (ret.statistics.core_balance - ret.statistics.total_witness_pledge + ret.statistics.prepaid) / 100000
    RET.balanceLocking = ret.statistics.total_witness_pledge / 100000

    RET.pledged = false
    if RET.balanceLocking ~= 0 then
        RET.pledged = true
    end
    
    RET.balanceTotal = RET.balanceLocking + RET.balanceUsable
    RET.balance = RET.balanceTotal
    RET.recentFunding = get_24_hour(addr)
_M.code = 0
    return RET
end


return _M
