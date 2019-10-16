local cjson = require "cjson"
local base58 = require("resty.base58")
local bit = require("bit")
local http = require "resty.http"
local httpc = http.new()
local config = require ("config")

local log = ngx.log
local ERR = ngx.ERR

local _M = {}

local RET = {}

function _M.main()
_M.code = debug.getinfo(1).currentline 
--    if true then return {a="a"} end
    local args = ngx.req.get_uri_args()
    local addr = args.acc
    if not addr then
        return  {status = 1, error = "missing arguments", code = debug.getinfo(1).currentline}
    end

    local request_url = "http://47.96.84.173:8088/getFreeBalance/" .. addr
    local res, err = httpc:request_uri(request_url, {
        method = "GET",
        headers = config.CAMO_UA 
    })
    if not res then
        return  {status = 1, error = "internal error.", code = debug.getinfo(1).currentline}
    end

_M.code = debug.getinfo(1).currentline
    local ret = cjson.decode(res.body)
    if ret.statusCode ~= 200 then
        return {status = 1, exist = false, error = ret.object, code = debug.getinfo(1).currentline}
    end
    local free_balance = ret.object

    local request_url = "http://47.96.84.173:8088/getLockBalance/" .. addr
    local res, err = httpc:request_uri(request_url, {
        method = "GET",
        headers = config.CAMO_UA
    })
    if not res then
        return  {status = 1, error = "internal error.", code = debug.getinfo(1).currentline}
    end

_M.code = debug.getinfo(1).currentline
    local ret = cjson.decode(res.body)
    if ret.statusCode ~= 200 then
        return {status = 1, exist = false, error = ret.object, code = debug.getinfo(1).currentline}
    end
    local lock_balance = ret.object
    -- temporarily not implemented
    lock_balance = 0

_M.code = debug.getinfo(1).currentline
    if ret and ret.error then
--        if not validate_address(addr) then
            --the address is validated, but no tx on chain yet.
--            RET.exist = false
--            RET.balance = 0
--            RET.balanceTotal = 0
--            RET.balanceLocking = 0
--            RET.balanceUsable = 0
--            RET.pledged = false
--        end
    else
_M.code = debug.getinfo(1).currentline
        RET.balance = (free_balance + lock_balance) / 1000000000000 
        RET.balanceTotal = (free_balance + lock_balance) / 1000000000000
        RET.balanceLocking = lock_balance / 1000000000000
        RET.balanceUsable = free_balance / 1000000000000
        RET.pledged = false 
    end

    RET.recentFunding = 0--get_24_hour(addr)
    RET.status = 0
_M.code = 0
    return RET
end


return _M
