local redis = require("resty.redis")

local _M = {}
_M.namespace = "default"
_M.rds = redis:new()
_M.rds:set_timeout(1000)



function _M.set_namespace(_self, _space)
    _self.namespace = _space
    return true
end

function _M.connect(_self, _ip, _port)
    _self.rds:set_keepalive(10000,100)
    local ok, err = _self.rds:connect(_ip, _port)
    if not ok then
        RET.warning = "internal error: " .. err .. ". " .. debug.getinfo(1).name
        RET.code = debug.getinfo(1).currentline
        return false
    end
    return true
end

function _M.disconnect()
    rds:set_keepalive(10000,100)
    return true 
end

function _M.get(_k)
    if not rds_connect() then
        return nil
    end

    _k = "accounts:".._k
    local ok, err = rds:get(_k)

    if not ok then
        return nil
    end
    return ok
end

function _M.set(_k, _v)
    return rds_set(_k, _v, 1800)
end

function _M.set(_k, _v, _time)
    if not _k or not rds_connect() then
        return false
    end

    _k = "accounts:" .. _k
    local ok, err = rds:set(_k, _v)

    if ok then
        rds:expire(_k, _time)
    else
        RET.warning = "internal error:" .. err .. ". " .. debug.getinfo(1).name
        RET.code = debug.getinfo(1).currentline
        return false
    end
    return true
end

