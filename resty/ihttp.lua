
local http = require "resty.http"
local cjson = require "cjson"

local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 155)
_M._VERSION = '0.1'

local methods = {
    "options",
    "get",
    "post"
}

local mt = { __index = _M }

local CAMO_UA = {['User-Agent'] = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36'}

function do_request(self, method, uri, opts)
    local opts = opts or {}
    opts.headers = opts.headers or self.headers
    if not opts.headers['User-Agent'] then
        for _, ua in pairs(CAMO_UA) do
            opts.headers['User-Agent'] = ua
        end
    end
    opts.timeout = (opts.timeout and opts.timeout * 1000) or self.timeout
    opts.method = string.upper(method)

    local httpc = http.new()
    httpc:set_timeout(opts.timeout)
    if not httpc then
        return nil, err
    end

    local res, err = httpc:request_uri(uri, opts)
    if not res then
        ngx.log(ngx.ERR, string.format("request %s failed: %s", uri, err))
        return nil, err
    else
        return res.body, err
    end
end

function _M.new(self, opts)
    opts = opts or {}
    local headers = opts.headers or CAMO_UA
    local timeout = (opts.timeout and opts.timeout * 1000) or 3000

    for i = 1, #methods do
        local method = methods[i]
        _M[method] = function (self, ...)
            return do_request(self, method, ...)
        end
    end

    return setmetatable({
            timeout = timeout,
            headers = headers
            }, mt)
end

return _M
