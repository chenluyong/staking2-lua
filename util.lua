
local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 155)
_M._VERSION = '0.1'

local mt = { __index = _M }

local function log(...)
    local log = ngx.log
    log(ngx.ERR, ...)
    return
end
_M.log = log

local function expand(s, rpl)
    return string.gsub(s, "$(%w+)", rpl)
end
_M.expand = expand

return _M
