local _M = {}

function _M.main()
    local cjson = require "cjson" 
    cjson.encode_empty_table_as_object(false) 
    return { b = {dogs={a="a"},dog_name = {"a","b"}}}
--    return {a="a"}
end

return _M
