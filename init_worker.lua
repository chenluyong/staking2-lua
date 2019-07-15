
local http = require "resty.http"
local cjson = require "cjson"
local redis = require "resty.redis"

local log = ngx.log
local ERR = ngx.ERR

log(ERR, "init staking2 worker")


