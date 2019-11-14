--[[
[chainx account example]
- request url: http://192.168.1.93/chainx/getaccount?acc=5VLFvns2zgpJGFjz6ob5U3Vbomy71aHrM3ieVH5MNTPpeyzB
- return body:
{
    "balanceTotal":1.600473,
    "balance":1.600473, -- the same as `balanceTotal`
    "status":0,
    "balanceLocking":0,
    "account":"0xfbdc9c53d8ebc2f2a00636cf4cc9b5f50fb0415bb1058c194ff9c9c148369371",
    "balanceUsable":1.600473,
    "pledged":false
}
]]--

local _M = {}
_M.error = nil
_M.code = 0

local cjson = require("cjson")
local base58 = require("resty.base58")
local config = require("config")



-- define function
local function bin2hex(s)
    s=string.gsub(s,"(.)",function (x) return string.format("%02x",string.byte(x)) end)
    return s
end

local function get_24_hour(account)
    http = require "resty.http"
    httpc = http.new()

    local req_uri = string.format("https://api.chainx.org.cn/account/0x%s/transfers?page=0&page_size=20", account)
    local res, err = httpc:request_uri(req_uri, {
        method = "GET",
        headers = config.CAMO_UA,
    ssl_verify = false})
    if not res then
        return {status = 1, error = "request "..req_uri.." failed", code = debug.getinfo(1).currentline, res = cjson.encode(res), err = err}
    end

    local ret = cjson.decode(res.body)
    local time_with_24_hour = os.time() - (24 * 60 * 60)

    if ret then
        local amount_24_hour = 0
        for _,action in pairs(ret.items) do
            local timestamp = action.time / 1000;
            if time_with_24_hour < timestamp then
                if action.payee == account then
                    amount_24_hour = amount_24_hour + tonumber(action.value) / 100000000
                end
            end
        end
       return amount_24_hour
    end
    return 0
end


-- get account info
local function get_info(acc)
    local adr_check = bin2hex(base58.decode(acc))
    local adr = string.sub(adr_check, 3, string.len(adr_check)-4)
    local request_url = string.format("%s/0x%s/balance", config.CHAINX_GETACCOUNT, adr)

    if ( #adr ~= 64 ) then
        return { error = "address format error." }
    end


--    return { success = true, account = adr, request_url = request_url}

    -- request account info
    -- demo: /usr/local/openresty/nginx/conf/staking2/scripts/chainx.py https://api.chainx.org.cn/account/0xfbdc9c53d8ebc2f2a00636cf4cc9b5f50fb0415bb1058c194ff9c9c148369371/balance 0xfbdc9c53d8ebc2f2a00636cf4cc9b5f50fb0415bb1058c194ff9c9c148369371
    local cmd = string.format("%s %s 0x%s",config.CHAINX_ACCOUNT_PY, request_url, adr)
    local t = io.popen(cmd)
    local a = t:read("*all")
    local ret_obj = cjson.decode(a)
--    if (ret_obj["status"] ~= 0) then
        --log(ERR,a)
--    end
    ret_obj.recentFunding = get_24_hour(adr)
    return ret_obj
end



function _M.main()
RET = {}
_M.code = debug.getinfo(0).currentline    
    local ret = {}
    local acc = ngx.req.get_uri_args().acc
    if not acc then
        log(ERR, "ERR not chainx account provided.")
        ret.error = "missing arguments"
        return ret
    end

    ret = get_info(acc)
_M.code = 0
    return ret
end


return _M

