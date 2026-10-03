local Check = {}
function Check.New()
    local count, failed = 0, 0
    local function check(name, actual, expected)
        count = count + 1
        local ok = actual == expected
        if not ok then failed = failed+1 end
        print(string.format("[B2] %s %s actual=%s expected=%s",ok and "PASS" or "FAIL",name,tostring(actual),tostring(expected)))
    end
    return check, function() print(string.format("[B2] checks=%d failed=%d",count,failed)); return failed == 0 end
end
return Check
