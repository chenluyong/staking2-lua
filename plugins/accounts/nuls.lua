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
local ADDRESS_LENGTH = 32
local CHAINID = 8964
local ACCOUNT_TYPE = 1


local function get_24_hour(account)
    http = require "resty.http"
    httpc = http.new()

_M.code = debug.getinfo(1).currentline
    local res, err = httpc:request_uri(config.NULSCAN_GETACCOUNT, {
        method = "POST",
        headers = {
            ['User-Agent'] = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36',
            ['Content-Type'] = "application/json"
        },
        body = cjson.encode({
            jsonrpc = "2.0",
            method = "getAccountTxs",
            params = {1,1,20,account,0,-1,-1},
            id = 5898
        })
    })

_M.code = debug.getinfo(1).currentline
    if not res then
        return 0
    end

    local ret = cjson.decode(res.body)
    local time_with_24_hour = os.time() - (24 * 60 * 60)

_M.code = debug.getinfo(1).currentline

log(ERR, ">>response: ".. res.status .. " " .. res.body)
    if ret then
_M.code = debug.getinfo(1).currentline
        if ret.error then
            return 0 
        end
        local amount_24_hour = 0
        for _,action in pairs(ret.result.list) do
            local timestamp = action.createTime;
_M.code = debug.getinfo(1).currentline
            if time_with_24_hour < timestamp then
_M.code = debug.getinfo(1).currentline
                if action.type == 2 and action.transferType == 1 then
                    if action.address == account then
                        amount_24_hour = amount_24_hour + (action.values / config.NULSCAN_DECIMAL)
                    end
                end
            end
        end
        return amount_24_hour
    end
_M.code = debug.getinfo(1).currentline
end


function hex_dump (str)
    local len = string.len( str )
    local dump = ""
    local hex = ""
    local asc = ""

    for i = 1, len do
        if 1 == i % 8 then
            dump = dump .. hex .. asc .. "\n"
            hex = string.format( "%04x: ", i - 1 )
            asc = ""
        end

        --TODO check XOR https://github.com/nuls-io/nuls/blob/master/core-module/kernel/src/main/java/io/nuls/kernel/utils/AddressTool.java#L169
        local ord = string.byte( str, i )
        hex = hex .. string.format( "%02x ", ord )
        if ord >= 32 and ord <= 126 then
            asc = asc .. string.char( ord )
        else
            asc = asc .. "."
        end
    end


    return dump .. hex
    .. string.rep( "   ", 8 - len % 8 ) .. asc
end

function validate_address(addr)
    local addr = addr

    if addr == '' or string.len(addr) ~= ADDRESS_LENGTH then
        return nil
    end

    local bytes, err = base58.decode(addr)
    if not bytes then
        return nil
    end

    --local chainId = string.byte(bytes, 1)
    local low = bit.lshift(bit.tobit(string.byte(bytes, 2)), 8)
    local high = bit.band(bit.tobit(string.byte(bytes, 1)), 0xff)
    local chainId = bit.bor(low, high)
    local accType = string.byte(bytes, 3)

    if chainId == CHAINID and accType == ACCOUNT_TYPE then
        return true
    end

    return false
end


function _M.main()
_M.code = debug.getinfo(1).currentline 
--    if true then return {a="a"} end
    local args = ngx.req.get_uri_args()
    local addr = args.acc
    if not addr then
--        log(ERR, "ERR not nuls address provided.")
        return  {status = 1, error = "missing arguments", code = debug.getinfo(1).currentline}
    end

    if validate_address(addr) then
        return  {status = 1, error = "invalid address arguments", code = debug.getinfo(1).currentline}
    end


_M.code = debug.getinfo(1).currentline
--    log(ERR, "nuls address " .. addr .. " not found in rds")
    --request from nulscan.com
--if true then    return{error= "request body: " .. cjson.encode({
--            jsonrpc = "2.0",
--            method = "getAccount",
--            params = {1,addr},
--            id = 5898
--        }) .. "\n\t" .. config.NULSCAN_GETACCOUNT}end
    local res, err = httpc:request_uri(config.NULSCAN_GETACCOUNT, {
        method = "POST",
        headers = {
            ['User-Agent'] = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36',
            ['Content-Type'] = "application/json"
        },
        body = cjson.encode({
            jsonrpc = "2.0",
            method = "getAccount",
            params = {1,addr},
            id = 5898
        })
    })
--log(ERR,"error test")

_M.code = debug.getinfo(1).currentline 
    if not res then
        log(ERR, "request "..NULSCAN_GETACCOUNT.."failed")
--return {a="b"}
        return  {status = 1, error = "internal error.", code = debug.getinfo(1).currentline}
    end

_M.code = debug.getinfo(1).currentline 
--    log(ERR, ">>response: ".. res.status .. " " .. res.body)

    --if res.status ~= 200 then
        --RET.exist = false
        --RET.error = "account not exist."
    --else
        --RET.exist = true
    --end

_M.code = debug.getinfo(1).currentline 
    local ret = cjson.decode(res.body)
    if ret and ret.error then
        if not validate_address(addr) then
            RET.exist = false
            RET.error = "address error: "..ret.error.message
_M.code = debug.getinfo(1).currentline 
            return RET
        else
            --the address is validated, but no tx on chain yet.
            RET.exist = false
            RET.balance = 0
            RET.balanceTotal = 0
            RET.balanceLocking = 0
            RET.balanceUsable = 0
            RET.pledged = false
        end
    else
_M.code = debug.getinfo(1).currentline 
        RET.balance = ret.result.totalBalance / config.NULSCAN_DECIMAL 
        RET.balanceTotal = ret.result.totalBalance / config.NULSCAN_DECIMAL
        RET.balanceLocking = (ret.result.consensusLock + ret.result.timeLock) / config.NULSCAN_DECIMAL
        RET.balanceUsable = ret.result.balance / config.NULSCAN_DECIMAL
        if ret.result.consensusLock > 0 then
            RET.pledged = true
        else
_M.code = debug.getinfo(1).currentline 
            RET.pledged = false
            local res, err = httpc:request_uri(config.NULSCAN_GETACCOUNT, {
                method = "POST",
                headers = {
                    ['User-Agent'] = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36',
                    ['Content-Type'] = "application/json"
                },
                body = cjson.encode({
                    jsonrpc = "2.0",
                    method = "getAccountTxs",
--                    params = {1, 10, addr, 0, true}, -- page,size,addr,?,hide consensus txs
                    params = {1,1,20,addr,0,-1,-1},
                    id = 5898
                })
            })
_M.code = debug.getinfo(1).currentline 
--            log(ERR, ">>response: ".. res.status .. " " .. res.body)
            local ret = cjson.decode(res.body)
_M.code = debug.getinfo(1).currentline 
            for _, tx in pairs(ret.result.list) do
                if tx.type == 5 or tx.type == 6 then
                    RET.pledged = true
                end
            end
_M.code = debug.getinfo(1).currentline 
        end
    end

_M.code = debug.getinfo(1).currentline
    RET.recentFunding = get_24_hour(addr)
    RET.status = 0
_M.code = 0
    return RET
end


return _M
