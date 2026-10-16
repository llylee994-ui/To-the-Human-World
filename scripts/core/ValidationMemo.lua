-- A bounded, value-based proof cache. No revision-only trust and no save flags.
-- The complete input and content are compared; only successful pure snapshots
-- are retained. Every caller receives an independent copy of the result.
local U=require "core.StateUtil"
local M={}
function M.New(content)
    local input,definitions,result
    local api={}
    function api.Run(value,validate)
        local pure=U.Validate(value);if not pure.ok then return pure end
        if input and U.Equal(value,input) and U.Equal(content,definitions) then return U.Copy(result) end
        local checked=validate()
        if checked.ok then input=U.Copy(value);definitions=U.Copy(content);result=U.Copy(checked) end
        return checked
    end
    return api
end
return M
