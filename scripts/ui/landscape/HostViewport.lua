-- APK-only layout metadata via the official command-line argument API.
-- The host reserves extra margins if system insets grow after launch.
-- No filesystem, HTTP, player save, or gameplay API is used.
local H={}
local cached=nil --[[@as table?]]
local initialized=false
function H.Read(viewport)
    if not initialized then
        initialized=true
        if GetPlatform and GetPlatform()=="Web" and GetArguments then
            local args={}
            for _,arg in ipairs(GetArguments()) do
                local key,value=arg:gsub("^%-+", ""):match("^([%w_]+)=(.*)$")
                if key then args[key]=value end
            end
            local session=args.human_world_layout_session
            if args.human_world_layout=="1" and type(session)=="string"
                and #session<=64 and session:match("^[%w%-]+$") then
                local safe={};local valid=true
                for _,key in ipairs({"left","top","right","bottom"}) do
                    local n=tonumber(args["human_world_safe_"..key])
                    if not n or n~=n or n<0 or n>512 then valid=false else safe[key]=n end
                end
                if valid and safe.left+safe.right<viewport.w and safe.top+safe.bottom<viewport.h then
                    cached=safe
                    print("[HumanWorldResponsiveReady]"..session)
                end
            end
        end
    end
    return cached
end
return H
