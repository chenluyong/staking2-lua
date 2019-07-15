
local cjson = require "cjson"
local redis = require "resty.redis"

local args = ngx.req.get_uri_args()
local rds = redis:new()
rds:set_timeout(1000)

local log = ngx.log
local ERR = ngx.ERR

local RET = {}

-- https://www.iostabc.com/endpoint/getAccount/hibarui/0
IOSTABC_GETACCOUNT = "https://www.iostabc.com/endpoint/getAccount/"

local ok, err = rds:connect("127.0.0.1", 6379)
if not ok then
    log(ERR, "failed to connect rds.")
    RET.error = "internal error: rfailed."
end

local acc = args.acc
if not acc then
    log(ERR, "ERR not iost account provided.")
    ngx.say(cjson.encode({status = 1, error = "missing arguments"}))
    return
end

ok, err = rds:get('iost:account:'..acc)
if not ok then
    log(ERR, "get iost from rds failed: "..err)
    RET.error = "internal error: rfailed."
elseif ok == ngx.null then
    log(ERR, "iost acc " .. acc .. " not found in rds")
    --request from iostabc.com
    http = require "resty.http"
    httpc = http.new()

    local res, err = httpc:request_uri( string.format("%s/%s/0", IOSTABC_GETACCOUNT, acc), {
        method = "GET",
        headers = {
            ['User-Agent'] = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36'
        }
    })

    if not res then
        log(ERR, "request "..IOSTABC_GETACCOUNT.."failed")
        return
    end

    --log(ERR, ">>response: ".. res.status .. " " .. res.body)

    if res.status ~= 200 then
        RET.exist = false
        RET.error = "account not exist."
    else
        RET.exist = true
    end

    local ret = cjson.decode(res.body)
    if ret and ret.name then
        RET.balance = ret.balance
        if table.getn(ret.vote_infos) > 0 then
            RET.pledged = true
        else
            RET.pledged = false
        end
    end

    ok, err = rds:set('iost:account:'..acc, cjson.encode(RET))
    if not ok then
        log(ERR, "save result to redis failed: "..err)
    end
    ok, err = rds:expire('iost:account:'..acc, 180)
    if not ok then
        log(ERR, "set key expire failed")
    end

    RET.status = 0
else
    log(ERR, "iost acc ".. acc .."found in cache")
    RET = cjson.decode(ok)
    RET.status = 0
end

local ok, err = rds:set_keepalive(30000, 100)
if not ok then
    RET.error = "internal error: rfailed."
end

ngx.say(cjson.encode(RET))
