
local cjson = require "cjson"
local http = require "resty.ihttp"
local httpc = http:new()
local util = require ("staking2.util")
local config = require ("config")

local _M = {}
--local string = string
local table = table

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
--local detail = {}
_M.code = debug.getinfo(1).currentline 
    local res, err = httpc:get("https://polkascan.io/kusama-cc2/api/v1/session/validator?filter%5BlatestSession%5D=true&page%5Bsize%5D=100")
--    local ok = string.find(res,"<html>")

    if not res then
        RET.error = "request failed: ".. (err or "unanticipated response.") 
--        RET.error_teail = res
        return RET
    end

    local totalPower = 0
    local ret = cjson.decode(res)
    RET.nodes = {}
    if ret then
--detail.st = ret
        for _, node in pairs(ret.data) do
            repeat
                local inline_node = node.attributes
                inline_node.alias = "validator"-- inline_node.validator_stash
                if true then
                    local res, err = httpc:get("http://47.96.84.173:8088/getNickName/"..inline_node.validator_stash)
                    local obj = cjson.decode(res)
                    if obj.statusCode == 200 then
                        inline_node.alias = str2hex(string.sub(obj.object,3))
                    end
                end
                if true then 
                    local res, err = httpc:get(string.format("https://polkascan.io/kusama-cc2/api/v1/account/%s?include=indices",inline_node.validator_stash))
                    local obj = cjson.decode(res)
                    if not res then
                        RET.warning = "request ".. inline_node.validator_stash " error."
                    end
                    if #obj.included ~= 0 then
                        inline_node.short_address = obj.included[1].id
                    else
                        inline_node.short_address = ""
                    end
                end
                table.insert(RET.nodes, {
                    alias = inline_node.alias,
                    alias_en = inline_node.alias,
                    address = inline_node.validator_stash,
                    short_address = inline_node.short_address,
                    total_vote = inline_node.bonded_total == ngx.null and 0 or (inline_node.bonded_total / 1000000000000),
                    rank = inline_node.rank_validator + 1,
                    voters = inline_node.count_nominators,
                    commission = inline_node.commission == ngx.null and 0 or (inline_node.commission / 1000000000000),
                    node_type = node.type
                })
--                return RET
            until true
        end
    end
_M.code = 0
--    RET = convert(RET)
--RET.detail = detail
    return RET
end

return _M
