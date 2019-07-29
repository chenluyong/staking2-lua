-- chainx
local cjson = require "cjson"
local base58 = require("resty.base58")

local args = ngx.req.get_uri_args()
local log = ngx.log
local ERR = ngx.ERR
RET = {}
--RET = { status : 1, error : "unkonw error." }


CHAINX_GETACCOUNT = "https://api.chainx.org.cn/account"

-- define function
local function bin2hex(s)
    s=string.gsub(s,"(.)",function (x) return string.format("%02x",string.byte(x)) end)
    return s
end


-- get parms
local acc = args.acc
if not acc then
    log(ERR, "ERR not chainx account provided.")
    ngx.say(cjson.encode({status = 1, error = "missing arguments"}))
    return
end
local adr_check = bin2hex(base58.decode(acc))
local adr = string.sub(adr_check, 3, string.len(adr_check)-4)
local request_url = string.format("%s/0x%s/balance", CHAINX_GETACCOUNT, adr)

-- python script
local chainx_py = "/usr/local/openresty/nginx/conf/staking2/scripts/chainx.py"

-- request account info
local cmd = string.format("%s %s 0x%s",chainx_py, request_url, adr)
local t = io.popen(cmd)
local a = t:read("*all")
RET = a

-- response
ngx.header.content_type = 'application/json'
ngx.say(RET)
