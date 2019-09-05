local cjson = require "cjson"
local base58 = require("resty.base58")
local bit = require("bit")
local http = require "resty.http"
local httpc = http.new()
local config = require("config")

local _M = {}

local RET = {}
local ADDRESS_LENGTH = 42

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

        --TODO check XOR https://github.com/bystack-io/bystack/blob/master/core-module/kernel/src/main/java/io/bystack/kernel/utils/AddressTool.java#L169
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

    local res, err = httpc:request_uri(config.BYSTACK_RPC..'validate-address', {
        method = "POST",
        headers = config.CAMO_UA,
        body = cjson.encode({
            address = addr,
        })
    })
    if not res or res.body then
        return nil
    end
    local ret = cjson.decode(res.body)
    if ret and ret.status == "success" then
        if ret.data.valid == true then
            return true
        end
    end

    return false

end

function _M.main()

    local args = ngx.req.get_uri_args()
    local addr = args.acc
    if not addr then
    --    log(ERR, "ERR not bystack address provided.")
    --    ngx.say(cjson.encode({status = 1, error = "missing arguments"}))
        return {status = 1, error = "missing arguments", code = debug.getinfo(1).currentline}
    end

--    log(ERR, "bystack address " .. addr .. " not found in rds")
    local res, err = httpc:request_uri(config.BYSTACK_GETACCOUNT..addr, {
        method = "GET",
        headers = config.CAMO_UA,
    })

    if not res then
        return {error = "request "..config.BYSTACK_GETACCOUNT.."failed", code = debug.getinfo(1).currentline }
    end

    --log(ERR, ">>response: ".. res.status .. " " .. res.body)

    --if res.status ~= 200 then
        --RET.exist = false
        --RET.error = "account not exist."
    --else
        --RET.exist = true
    --end

    local ret = cjson.decode(res.body)
    if ret and ret.code and ret.code == 10002 then
        if not validate_address(addr) then
            RET.exist = false
            RET.error = "account don't exist"
        else
            --the address is validated, but no tx on chain yet.
            RET.exist = true
            RET.balance = 0
            RET.balanceTotal = 0
            RET.balanceLocking = 0
            RET.balanceUsable = 0
            RET.pledged = false
        end
    else
        RET.balance = ret.data.address[1].balance / 100000000
        RET.balanceTotal = ret.data.address[1].balance / 100000000
        RET.pledged = false

        local url = string.format("%s%s%s", config.BYSTACK_GETACCOUNT, addr, config.BYSTACK_GETTXS_PREFIX)
        local res, err = httpc:request_uri(url, {
            method = "GET",
            headers = config.CAMO_UA
        })

        if not res then
            return  {error = "request ".. url .."failed", code = debug.getinfo(1).currentline }
        end

        local ret = cjson.decode(res.body)
        if ret and ret.code == 200 then
            local totaltxs = ret.data.total
            local totalvotes = 0
            for _, tx in pairs(ret.data.transactions) do
                for _, output in pairs(tx.outputs) do
                    if output.type == "vote" then
                        --totalvotes = totalvotes + output.amount
                        RET.pledged = true
                    end
                end
                if RET.pledged == true then break end
            end
        end

        --TODO find out how to calc vote.
        RET.balanceLocking = 0
        RET.balanceUsable = 0
        --RET.balanceLocking = (ret.result.consensusLock + ret.result.timeLock) / 100000000
        --RET.balanceUsable = ret.result.balance / 100000000
        --if ret.result.consensusLock > 0 then
            --RET.pledged = true
        --else
            --RET.pledged = false
        --end
    end

    RET.status = 0
    return RET
end

return _M