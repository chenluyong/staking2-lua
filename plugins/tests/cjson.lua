local _M = {}

local p = require("tests.path_requere")

function _M.main()
--    local cjson = require "cjson" 
--    cjson.encode_empty_table_as_object(false) 
    return { b = {dogs={a="a"},dog_name = {"a","b"}}, path_requere = p.nodes}
--    return {a="a"}
end

return _M
