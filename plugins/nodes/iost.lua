local _M = {}

local cjson = require "cjson"
local config = require "config"


local function get_producers(args)
    local http = require 'resty.ihttp'
    local httpc = http.new()
    local request_url = string.format("%s/%s", config.IOST_NODESINFO, args)
    
    -- request 
    local res, err = httpc:get(request_url)
    if not res then
        return { error = "request "..IOST_NODESINFO.." failed: "..err }
    else
        ret = cjson.decode(res)
        ret.status = 0
    end
    return ret
end


local function convert(_obj)
    -- convert object to std node info object
    return _obj
end


function _M.main()
    -- get nodes info
    args_len = #ngx.var.request_uri - #ngx.var.uri + 1
    local args = "?page=1&size=50&sort_by=votes&order=desc&search="
    if args_len > 3 then
        args = string.sub(ngx.var.request_uri, #ngx.var.uri + 1, #ngx.var.request_uri)
    end
    local ret_table = get_producers(args)

    return convert(ret_table)
end


return _M
