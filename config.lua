local _M = {}

_M.ROOT_PATH = "/usr/local/openresty/nginx/conf/staking2"


-- get git commit count
function _M.git_commit_count()
    local sh = "git --git-dir=" .. _M.ROOT_PATH .. "/.git --work-tree=" .. _M.ROOT_PATH .. " rev-list --all --count"
    local t = io.popen(sh)
    local count = t:read("*all")
    return tonumber(count) or 0
end

--
local MAJOR_VERSION = 1
local MINOR_VERSION = 1
local PATCH_VERSION = _M.git_commit_count()
_M.VERSION = MAJOR_VERSION .. "." .. MINOR_VERSION .. "." .. PATCH_VERSION


_M.CAMO_UA = {['User-Agent'] = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36'}


_M.CHAINX_GETACCOUNT = "https://api.chainx.org.cn/account"
_M.CHAINX_ACCOUNT_PY = "/usr/local/openresty/nginx/conf/staking2/libraries/scripts/chainx.py"

_M.IOST_NODESINFO = "https://www.iostabc.com/api/producers"

_M.WANCHAIN_RPC = "http://47.99.50.243:80"
_M.WANCHAIN_NODESINFO = "http://47.99.50.243:80/nodes/wanchain"

_M.REDIS = {
    ip = "127.0.0.1",
    port = 6379,
    timeout = 1000,
    default_time = 1200,
    accounts = {
        wanchain = 0, -- no cache, real-time
        default  = 1200 -- default 20 minutes timeout
    },
    nodes = {
        wanchain = 3600, -- no cache, real-time
        default = 86400
    }
}

local DEBUG = false

-- check local
local t = io.popen("/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d 'addr:'")
local a = t:read("*all")
a = string.gsub(a, "^%s*(.-)%s*$", "%1")
if a == "172.17.0.6" then
    -- open dev
    DEBUG = true
end

-- check DEBUG
if DEBUG then
    _M.WANCHAIN_RPC = "http://192.168.1.93:18545"
    _M.REDIS.ip = "192.168.1.93"
    _M.WANCHAIN_NODESINFO = "http://192.168.1.93:80/nodes/wanchain"
end


-- DEBUG
--print(_M.VERSION)
--print(_M.REDIS['account_list']['wanchain'])

return _M

