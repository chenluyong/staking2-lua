local _M = {}

function _M.test()
    ngx.say("hello")
end


function _M.main()
    return { error = "unconsummated."}
end

return _M
