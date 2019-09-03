local _M = {}


-- get git commit count
function git_commit_count()
    local sh = "git rev-list --all --count"
    local t = io.popen(sh)
    local count = t:read("*all")
    return tonumber(count)
end

--
local MAJOR_VERSION = 1
local MINOR_VERSION = 0
local PATCH_VERSION = git_commit_count() 

_M.VERSION = MAJOR_VERSION .. "." .. MINOR_VERSION .. "." .. PATCH_VERSION


return _M

