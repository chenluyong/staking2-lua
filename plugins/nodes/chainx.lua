local cjson = require "cjson"
local redis = require "resty.iredis"
local rds = redis:new()
local http = require "resty.ihttp"
local httpc = http:new()
local util = require "util"
