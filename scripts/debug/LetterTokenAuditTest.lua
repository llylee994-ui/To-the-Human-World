local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local S=require "core.SaveSchema"
local T={}
function T.Run()
    local check,done=R.Checks("LetterTokenAudit")
    local x=R.New();R.Accept(x,1)
    local live=x.state.GetSnapshot().live
    local letters=require("systems.Letter").New(x.content)
    local tokens=require("systems.WordToken").New(x.content)
    local options={letters=letters,wordTokens=tokens}
    check("one whole-letter validation per joined audit, independent of token count",function()
        local count=0;local original=letters.ValidateSnapshot
        letters.ValidateSnapshot=function(value) count=count+1;return original(value) end
        local r=S.ValidateLetterTokens(live.letters,live.wordTokens,options)
        letters.ValidateSnapshot=original
        assert(r.ok and count==1,"whole-letter validations="..count.."; expected one")
    end)
    for _,kind in ipairs({"word","npc","missing-letter","missing-cut","missing-token","unread","span","extra"}) do
        check("still rejects forged "..kind,function()
            local l,w=U.Copy(live.letters),U.Copy(live.wordTokens)
            local id,token=next(w.byId);local item=l.byId[token.sourceLetterInstanceId]
            if kind=="word" then token.wordId="word-forged"
            elseif kind=="npc" then token.sourceNpcId="npc-forged"
            elseif kind=="missing-letter" then l.byId[token.sourceLetterInstanceId]=nil;l.bottleQueue={}
            elseif kind=="missing-cut" then item.cutSpans[token.sourceSpanId]=nil
            elseif kind=="missing-token" then w.byId[id]=nil
            elseif kind=="unread" then item.read=false
            elseif kind=="span" then token.sourceSpanId="body:999"
            elseif kind=="extra" then w.byId["another-token"]=U.Copy(token) end
            assert(not S.ValidateLetterTokens(l,w,options).ok)
        end)
    end
    check("valid consumed sources and returned copies are preserved",function()
        local request=R.Accept(x,1);local pending=R.Preview(x,request)
        R.Must(x.order.Confirm({orderId=request.orderId,transactionId=pending.transactionId}))
        local after=x.state.GetSnapshot().live
        local joined=R.Must(S.ValidateLetterTokens(after.letters,after.wordTokens,options))
        local id,token=next(joined.wordTokens.byId);token.wordId="changed"
        assert(after.wordTokens.byId[id].wordId~="changed")
    end)
    return done()
end
return T
