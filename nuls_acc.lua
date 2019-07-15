
local cjson = require "cjson"
local redis = require "resty.redis"

local args = ngx.req.get_uri_args()
local rds = redis:new()
rds:set_timeout(1000)

local log = ngx.log
local ERR = ngx.ERR

local RET = {}

-- https://api.nuls.io/ POST "{"jsonrpc":"2.0","method":"getAccount","params":["NsdxvCLJ7prS7WQbrAoJd9H8diSm5AcK"],"id":5898}"
-- {
  --"jsonrpc": "2.0",
  --"id": 5898,
  --"result": {
    --"address": "NsdxvCLJ7prS7WQbrAoJd9H8diSm5AcK",
    --"alias": null,
    --"type": 1,
    --"txCount": 69666,
    --"totalOut": 1340678698100,
    --"totalIn": 13259228522021,
    --"consensusLock": 11848100000000,
    --"timeLock": 452897467,
    --"balance": 69996926454,
    --"totalBalance": 11918549823921,
    --"tokens": [
      --"NseNjY5E5rLS6qqrNrLCCn4VRjRwdKhX,wave",
      --"NseCpCRzVU3U9RSYyTwSFhdL71wEnpDv,ANG"
    --],
    --"new": false
  --}
-- }
NULSCAN_GETACCOUNT = "https://api.nuls.io"

local ok, err = rds:connect("127.0.0.1", 6379)
if not ok then
    log(ERR, "failed to connect rds.")
    RET.error = "internal error: rfailed."
end

local addr = args.acc
if not addr then
    log(ERR, "ERR not nuls address provided.")
    ngx.say(cjson.encode({status = 1, error = "missing arguments"}))
    return
end

ok, err = rds:get('nuls:account:'..addr)
if not ok then
    log(ERR, "get nuls from rds failed: "..err)
    RET.error = "internal error: rfailed."
elseif ok == ngx.null then
    log(ERR, "nuls address " .. addr .. " not found in rds")
    --request from nulscan.com
    http = require "resty.http"
    httpc = http.new()

    local res, err = httpc:request_uri(NULSCAN_GETACCOUNT, {
        method = "POST",
        headers = {
            ['User-Agent'] = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36'
        },
        body = cjson.encode({
            jsonrpc = "2.0",
            method = "getAccount",
            params = {addr},
            id = 5898
        })
    })

    if not res then
        log(ERR, "request "..NULSCAN_GETACCOUNT.."failed")
        return
    end

    log(ERR, ">>response: ".. res.status .. " " .. res.body)

    --if res.status ~= 200 then
        --RET.exist = false
        --RET.error = "account not exist."
    --else
        --RET.exist = true
    --end

    local ret = cjson.decode(res.body)
    if ret and ret.error then
        if ret.error.code == 1000 then
            RET.exist = false
            RET.error = ret.error.data
        end
    else
        RET.balance = ret.result.totalBalance / 100000000
        if ret.result.consensusLock > 0 then
            RET.pledged = true
        else
            RET.pledged = false
            local res, err = httpc:request_uri(NULSCAN_GETACCOUNT, {
                method = "POST",
                headers = {
                    ['User-Agent'] = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36'
                },
                body = cjson.encode({
                    jsonrpc = "2.0",
                    method = "getAccountTxs",
                    params = {1, 10, addr, 0, true}, -- page,size,addr,?,hide consensus txs
                    id = 5898
                })
            })
            log(ERR, ">>response: ".. res.status .. " " .. res.body)
            local ret = cjson.decode(res.body)
            for _, tx in pairs(ret.result.list) do
                if tx.type == 5 or tx.type == 6 then
                    RET.pledged = true
                end
            end
        end
    end

    ok, err = rds:set('nuls:account:'..addr, cjson.encode(RET))
    if not ok then
        log(ERR, "save result to redis failed: "..err)
    end
    ok, err = rds:expire('nuls:account:'..addr, 300)
    if not ok then
        log(ERR, "set key expire failed")
    end

    RET.status = 0
else
    log(ERR, "nuls address ".. addr .." found in cache")
    RET = cjson.decode(ok)
    RET.status = 0
end

local ok, err = rds:set_keepalive(30000, 100)
if not ok then
    RET.error = "internal error: rfailed."
end

ngx.say(cjson.encode(RET))
