local cjson = require "cjson"
local base58 = require("resty.base58")
local bit = require("bit")
local http = require "resty.http"
local httpc = http.new()
local ihttp = require "resty.ihttp"
local ihttpc = ihttp.new()
local config = require ("config")

local log = ngx.log
local ERR = ngx.ERR

local _M = {}

local RET = {}


function str2hex(str)
	if (type(str)~="string") then
	    return nil,"str2hex invalid input type"
	end
	str=str:gsub("[%s%p]",""):upper()
	if(str:find("[^0-9A-Fa-f]")~=nil) then
	    return nil,"str2hex invalid input content"
	end
	if(str:len()%2~=0) then
	    return nil,"str2hex invalid input lenth"
	end
	local index=1
	local ret=""
	for index=1,str:len(),2 do
	    ret=ret..string.char(tonumber(str:sub(index,index+1),16))
	end
 
	return ret
end


function _M.main()
_M.code = debug.getinfo(1).currentline 
RET = {}
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
    local lock_balance = 0
    if false then
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
        lock_balance = ret.object
        -- temporarily not implemented
        lock_balance = 0
    end


_M.code = debug.getinfo(1).currentline
    if ret and ret.error then
    else
_M.code = debug.getinfo(1).currentline
        RET.balance = (free_balance + lock_balance) / 1000000000000 
        RET.balanceTotal = (free_balance + lock_balance) / 1000000000000
        RET.balanceLocking = lock_balance / 1000000000000
        RET.balanceUsable = free_balance / 1000000000000
        RET.pledged = false 
    end

    if true then
        local res, err = httpc:request_uri(string.format("https://polkascan.io/kusama-cc2/api/v1/extrinsic?&filter[address]=%s&page[size]=25",addr), {
            method = "GET",
            headers = config.CAMO_UA
        })
        if not res then
            return {error = "internal error."}
        end
        local ret = cjson.decode(res.body)
        for _, item in pairs(ret.data) do
            if item.attributes.call_id == "nominate" then
                local param = item.attributes.params[1]
                RET.nominated = {}
                for _, obj in pairs(param.value) do
                    node = {short_address = "", alias = ""}
                    if true then
                        local res, err = ihttpc:get("http://47.96.84.173:8088/getNickName/"..obj.value)
                        node.alias = res
                        local result_obj = cjson.decode(res)
                        if result_obj.statusCode == 200 then
                            node.alias = str2hex(string.sub(result_obj.object,3))
                        end
                    end
                    if true then 
                        local res, err = ihttpc:get(string.format("https://polkascan.io/kusama-cc2/api/v1/account/%s?include=indices",obj.value))
                        local result_obj = cjson.decode(res)
                        if not res then
                            RET.warning = "request ".. obj.value .. " error."
                        end
                        if #result_obj.included ~= 0 then
                            node.short_address = result_obj.included[1].id
                        else
                            node.short_address = ""
                        end
                    end
                    node.address = obj.value
                    table.insert(RET.nominated, node)
                end
            end
        end
--        RET.transfer = ret
    end

    RET.recentFunding = 0--get_24_hour(addr)
    RET.status = 0
_M.code = 0
    return RET
end


return _M
