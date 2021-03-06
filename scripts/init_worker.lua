
local os = os

local routine = require "routine_job"

local log = ngx.log
local ERR = ngx.ERR

local delay = 30 -- wake up every half minute

log(ERR, "init staking2 worker")

local check

check = function(premature)
    if not premature then
        log(ERR, "routine_job weakup: "..os.time())
        for _, job in pairs(routine.jobs) do
            job()
        end
    end
end

if 0 == ngx.worker.id() then -- only create timer on no.1 process
    local ok, err = ngx.timer.every(delay, check)
    --local ok, err = ngx.timer.at(delay, check)
    if not ok then
        log(ERR, "create timer faield: ", err)
        return
    end
end
