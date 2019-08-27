
local cjson = require "cjson"
local redis = require "resty.redis"
local base58 = require("resty.base58")
local bit = require("bit")
local http = require "resty.http"
local httpc = http.new()

local const = require "constant"

local args = ngx.req.get_uri_args()
local rds = redis:new()
rds:set_timeout(1000)

local log = ngx.log
local ERR = ngx.ERR

local RET = {}

--http://vapor.blockmeta.com/api/v1/address/vp1qcj7dzpjlnsg7pf24nj6pduar9dc24uxe8ywc9
BYSTACK_RPC = "http://127.0.0.1:9889/"
BYSTACK_GETACCOUNT = "https://vapor.blockmeta.com/api/v1/address/"
BYSTACK_GETTXS_PREFIX = "/trx/ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff?limit=100"
ADDRESS_LENGTH = 42

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

    local res, err = httpc:request_uri(BYSTACK_RPC..'validate-address', {
        method = "POST",
        headers = const.CAMO_UA,
        body = cjson.encode({
            address = addr,
        })
    })

    local ret = cjson.decode(res.body)
    if ret and ret.status == "success" then
        if ret.data.valid == true then
            return true
        end
    end

    return false

end

local ok, err = rds:connect("127.0.0.1", 6379)
if not ok then
    log(ERR, "failed to connect rds.")
    RET.error = "internal error: rfailed."
end

local addr = args.acc
if not addr then
    log(ERR, "ERR not bystack address provided.")
    ngx.say(cjson.encode({status = 1, error = "missing arguments"}))
    return
end

ok, err = rds:get('bystack:account:'..addr)
if not ok then
    log(ERR, "get bystack from rds failed: "..err)
    RET.error = "internal error: rfailed."
elseif ok == ngx.null then
    log(ERR, "bystack address " .. addr .. " not found in rds")
    local res, err = httpc:request_uri(BYSTACK_GETACCOUNT..addr, {
        method = "GET",
        headers = const.CAMO_UA,
    })

    if not res then
        log(ERR, "request "..BYSTACK_GETACCOUNT.."failed")
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

        local url = string.format("%s%s%s", BYSTACK_GETACCOUNT, addr, BYSTACK_GETTXS_PREFIX)
        local res, err = httpc:request_uri(url, {
            method = "GET",
            headers = const.CAMO_UA
        })

        if not res then
            log(ERR, "request "..url.."failed")
            return
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

    if not RET.error then
        ok, err = rds:set('bystack:account:'..addr, cjson.encode(RET))
        if not ok then
            log(ERR, "save result to redis failed: "..err)
        end
        ok, err = rds:expire('bystack:account:'..addr, 300)
        if not ok then
            log(ERR, "set key expire failed")
        end
    end

    RET.status = 0
else
    log(ERR, "bystack address ".. addr .." found in cache")
    RET = cjson.decode(ok)
    RET.status = 0
end

local ok, err = rds:set_keepalive(30000, 100)
if not ok then
    RET.error = "internal error: rfailed."
end

ngx.say(cjson.encode(RET))

