local _M = {
    ROOT_PATH = "/usr/local/openresty/nginx/conf/new_staking2",

    -- https://api.bystack.com/supernode/v1/sn-table
    BYSTACK_NODESINFO = "https://api.bystack.com/supernode/v1/sn-table",
    BYSTACK_NODESDETAIL = "https://vapor.blockmeta.com/api/v1/nodes?page=1&limit=200",

    CHAINX_RPC = "http://127.0.0.1:8081/chainx/",
    CHAINX_DECIMAL = 100000000,
    CHAINXTOOLS_API = "https://api.chainxtools.com/price?t=",

    --curl -H "Content-Type: application/json" -X POST -d '{"code":"eosio","json":true,"limit":1000,"scope":"eosio","table":"bps"}' 'https://w3.eosforce.cn/v1/chain/get_table_rows' | jq
     EOSC_NODESINFO = "https://w3.eosforce.cn/v1/chain/get_table_rows",

    --curl -H "Content-Type: application/json" -X POST -d '{"account_name":"bepal.eosc"}' 'https://explorer.eosforce.io/web/get_account_info' | jq
     EOSC_SEARCHACCOUNT = "http://18.179.202.20:9990/web/search",
--ngx.say(config.EOSC_SEARCHACCOUNT)
     EOSC_GETACCOUNT = "http://18.179.202.20:9990/web/get_account_info",

    --http://vapor.blockmeta.com/api/v1/address/vp1qcj7dzpjlnsg7pf24nj6pduar9dc24uxe8ywc9
     BYSTACK_RPC = "http://127.0.0.1:9889/",
     BYSTACK_GETACCOUNT = "https://vapor.blockmeta.com/api/v1/address/",
     BYSTACK_GETTXS_PREFIX = "/trx/ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff?limit=100",
     VAPOR_NODESINFO = "https://vapor.blockmeta.com/api/v1/nodes",
     VAPOR_NODEINFO = "https://vapor.blockmeta.com/api/v1/node/",
     -- https://api.bystack.com/supernode/v1/sn-table
     BYSTACK_NODESINFO = "https://api.bystack.com/supernode/v1/sn-table",

    -- https://www.iostabc.com/endpoint/getAccount/hibarui/0
     IOSTABC_GETACCOUNT = "https://www.iostabc.com/endpoint/getAccount/",
     IOSTABC_GETTOTALVOTE = "https://www.iostabc.com/api/vote/votes",

     NULSCAN_GETACCOUNT = "https://nulscan.io/api/"

}



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
_M.CHAINX_ACCOUNT_PY = _M.ROOT_PATH .. "/libraries/scripts/chainx.py"

_M.IOST_NODESINFO = "https://www.iostabc.com/api/producers"

_M.WANCHAIN_RPC = "http://47.99.50.243:80"
_M.WANCHAIN_NODESINFO = "http://47.99.50.243:80/nodes/wanchain"

-- https://api.bystack.com/supernode/v1/sn-table
_M.BYSTACK_NODESINFO = "https://api.bystack.com/supernode/v1/sn-table"
_M.BYSTACK_NODESDETAIL = "https://vapor.blockmeta.com/api/v1/nodes?page=1&limit=200"


_M.REDIS = {
    ip = "127.0.0.1",
    port = 6379,
    timeout = 1000,
    default_time = 1200,
    accounts = {
        wanchain = 0, -- no cache, real-time
        default  = 60 -- default 20 minutes timeout
    },
    nodes = {
        vapor = 86400, -- one day
        bystack = 86400,
        wanchain = 600,
        iost = 3600,
        default = 86400
    }
}
_M.STD_HEADERS = {
    ['User-Agent'] = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36',
    ['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3',
    ['Accept-Encoding'] = 'gzip, deflate',
    ['Cookie'] = '_ga=GA1.1.1939310461.1565671653',
    ['Accept-Language'] = 'zh-CN,zh;q=0.9,en;q=0.8',
    ['Upgrade-Insecure-Requests'] = '1',
    ['Connection'] = 'keep-alive',
    ['Host'] = 'api.binance.com',
    ['Cache-Control'] = 'no-cache'
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
    _M.CHAINX_RPC = "http://121.196.208.250:8081/chainx/" -- for local test
end


-- DEBUG
--print(_M.VERSION)
--print(_M.REDIS['account_list']['wanchain'])

return _M

