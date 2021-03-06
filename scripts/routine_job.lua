
local cjson = require "cjson"
local http = require "resty.ihttp"
local httpc = http:new()
local redis = require "resty.iredis"
local rds = redis:new()
local util = require "util"

local _M = {}
_M._VERSION = '0.1'

_M.jobs = {}

--TODO: this ACCOUNTLIST do NOT support pagination yet, argument "page_size" actually NOT working!
local CHAINX_ACCOUNTLIST = "https://api.chainxtools.com/accounts?page_size=2000"
local CHAINX_NOMINATIONS = "https://api.chainx.org.cn/intention/$pub/nominations?page=0&page_size=1"
local BYSTACK_NODEINFO = "http://vapor.blockmeta.com/api/v1/node/$pub"
--local CHAINX_RPC = "http://127.0.0.1:8081/chainx/"
--if jit and jit.os and jit.os == "OSX" then
    --CHAINX_RPC = "http://121.196.208.250:8081/chainx/" -- for local test
--end

local function chainxGetNominationRecords(pub)
    --TODO: crawl full account from RPC too slow, maybe replace with ws://
    --local res, err = httpc:post(CHAINX_RPC, {
        --headers = {['Content-Type'] = 'application/json'},
        --timeout = 60,
        --body = cjson.encode({
            --id = 1,
            --jsonrpc = "2.0",
            --method = "chainx_getNominationRecords",
            --params = {pub}
        --})
    --})
end

local function chainxGetNominationCount(pub)
    local url = util.expand(CHAINX_NOMINATIONS, pub)
    local res, err = httpc:get(url)
    if not res then
        util.log("[ROUTINE] query chainx node ", pub, " info failed: ", err)
    else
        local voteinfo = cjson.decode(res)
        --util.log(">> chainx node: ", pub, ", voter: ", voteinfo.total)
        return #voteinfo.total
    end
    return 0
end

local function BystackGetVoterCount(pub)
    local url = util.expand(BYSTACK_NODEINFO, pub)
    local res, err = httpc:get(url)
    if not res then
        util.log("[ROUTINE] query bystack node ", pub, " info failed: ", err)
    else
        local voteinfo = cjson.decode(res)
        --util.log(">> bystack node: ", pub, ", nominator: ", #voteinfo.vote_list)
        return #voteinfo.vote_list
    end
    return 0
end

local function check_interval(rdskey, interval)
    local ok, err = rds:get(rdskey)
    if not ok then
        util.log("[ROUTINE] no routine job update flag, create one: ", rdskey)
        local ok, err = rds:set('chainx:crawler:update', os.time())
        if not ok then
            util.log('[ROUTINE] update chainx crawler timer failed: ', err)
        end
        return true -- initial run
    else
        if os.time() - tonumber(ok) > interval then
            return true
        end
    end
    return false
end

local function job_chainx_crawler()
    if check_interval('chainx:crawler:update', 3000) then
        util.log("[ROUTINE] chainx crawler start")
        local ok, err = rds:get('chainx:nodes')
        if ok then
            local nodeNominator = {}
            local cnt = 0
            for _, info in pairs(cjson.decode(ok)) do
                local nominator = chainxGetNominationCount((string.format("0x%s", info.accountId)))
                table.insert(nodeNominator, string.format("%s:%d", info.accountId, nominator))
                cnt = cnt + 1
            end
            if tonumber(#nodeNominator) == tonumber(cnt) then
                local ok, err = rds:sadd('chainx:nodeNominator', table.unpack(nodeNominator))
                if not ok then
                    util.log("save chainx nominator data err: ", err)
                end
            else
                util.log("get ", #nodeNominator, " chainx nominator data from api but not match to ", cnt, " in total.")
            end
            local ok, err = rds:set('chainx:crawler:update', os.time())
            if not ok then
                util.log('update chainx crawler timer failed: ', err)
            end
        else
            util.log('[ROUTINE] chainx nodes info not found in redis.')
        end
        util.log('[ROUTINE] chainx crawler finished.')
    end
end
table.insert(_M.jobs, job_chainx_crawler)

local function job_bystack_crawler()
    if check_interval('bystack:crawler:update', 3000) then
        util.log("[ROUTINE] bystack crawler start")
        local ok, err = rds:get('bystack:nodes')
        if ok then
            local nodeVoter = {}
            local cnt = 0
            for _, info in pairs(cjson.decode(ok)) do
                local nominator = BystackGetVoterCount(info.nodePubKey)
                table.insert(nodeVoter, string.format("%s:%d", info.nodePubKey, nominator))
                cnt = cnt + 1
            end
            if tonumber(#nodeVoter) == tonumber(cnt) then
                local ok, err = rds:sadd('bystack:voter', table.unpack(nodeVoter))
                if not ok then
                    util.log("save bystack voter data err: ", err)
                end
            else
                util.log("get ", #nodeVoter, " bystack voter data from api but not match to ", cnt, " in total.")
            end
            local ok, err = rds:set('bystack:crawler:update', os.time())
            if not ok then
                util.log('update bystack crawler timer failed: ', err)
            end
        else
            util.log('[ROUTINE] bystack nodes info not found in redis.')
        end
        util.log('[ROUTINE] bystack crawler finished.')
    end
end
--table.insert(_M.jobs, job_bystack_crawler)


return _M
