local cjson = require "cjson"
local base58 = require("resty.base58")
local bit = require("bit")
local http = require "resty.http"
local httpc = http.new()
local config = require ("config")

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
    local args = ngx.req.get_uri_args()
    local addr = args.acc
    if not addr then
--        log(ERR, "ERR not nuls address provided.")
        return  {status = 1, error = "missing arguments", code = debug.getinfo(1).currentline}
    end

--    log(ERR, "nuls address " .. addr .. " not found in rds")
    --request from nulscan.com
    local res, err = httpc:request_uri(config.NULSCAN_GETACCOUNT, {
        method = "POST",
        headers = config.CAMO_UA,
        body = cjson.encode({
            jsonrpc = "2.0",
            method = "getAccount",
            params = {addr},
            id = 5898
        })
    })

    if not res then
--        log(ERR, "request "..NULSCAN_GETACCOUNT.."failed")
        return  {status = 1, error = "internal error.", code = debug.getinfo(1).currentline}
    end

    --log(ERR, ">>response: ".. res.status .. " " .. res.body)

    --if res.status ~= 200 then
        --RET.exist = false
        --RET.error = "account not exist."
    --else
        --RET.exist = true
    --end

    local ret = cjson.decode(res.body)
    if ret and ret.error then
        if not validate_address(addr) then
            RET.exist = false
            RET.error = ret.error.message
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
        RET.balance = ret.result.totalBalance / 100000000
        RET.balanceTotal = ret.result.totalBalance / 100000000
        RET.balanceLocking = (ret.result.consensusLock + ret.result.timeLock) / 100000000
        RET.balanceUsable = ret.result.balance / 100000000
        if ret.result.consensusLock > 0 then
            RET.pledged = true
        else
            RET.pledged = false
            local res, err = httpc:request_uri(config.NULSCAN_GETACCOUNT, {
                method = "POST",
                headers = config.CAMO_UA,
                body = cjson.encode({
                    jsonrpc = "2.0",
                    method = "getAccountTxs",
                    params = {1, 10, addr, 0, true}, -- page,size,addr,?,hide consensus txs
                    id = 5898
                })
            })
            --log(ERR, ">>response: ".. res.status .. " " .. res.body)
            local ret = cjson.decode(res.body)
            for _, tx in pairs(ret.result.list) do
                if tx.type == 5 or tx.type == 6 then
                    RET.pledged = true
                end
            end
        end
    end

    RET.status = 0
    return RET
end


return _M
