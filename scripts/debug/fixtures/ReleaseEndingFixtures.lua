-- 仅验收使用的结局正文；正式data不包含这些文本。经营仍使用真实信、词、配方和存储协议。
local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local F=require "debug.fixtures.B5Fixtures"
local E={}
function E.Must(result) assert(result.ok,cjson.encode(result.error));return result.value end
function E.New(cash)
    local x=R.New(cash)
    x.content.releaseEndings={departure={title="[验收]离开",text="[验收正文]departure"},
        apprentice={title="[验收]学徒",text="[验收正文]apprentice",allThreeStarText="[验收]全部三星"},
        wish={title="[验收]愿望",text="[验收正文]wish"}}
    return x
end
function E.Clone(source)
    local x=F.New(source.content,{targetSchema=4});x.files=U.Copy(source.files)
    assert(x.Reload());return x
end
function E.Request(x,extra)
    local request={expectedRevision=x.state.GetSnapshot().revision}
    for k,v in pairs(extra or {}) do request[k]=v end
    return request
end
function E.Day14(x)
    while x.state.GetSnapshot().live.gameFlow.day<14 do E.Must(x.state.NextDay()) end
end
function E.CutOne(x)
    local id=x.content.release.requiredOrderIds[1]
    local instance=E.Must(x.state.ReceiveLetter({letterId=id})).letterInstanceId
    E.Must(x.state.ReadLetter({letterInstanceId=instance}))
    local span=E.Must(x.modules.letters.ParseDefinition(id)).spans[1]
    return E.Must(x.state.CutWord({letterInstanceId=instance,spanId=span.spanId})).tokenId
end
function E.WishSeed()
    local x=E.New();local token=E.CutOne(x);E.Day14(x)
    E.Must(x.state.BeginClosing(E.Request(x)));E.Must(x.state.BeginWish(E.Request(x)))
    E.Must(x.state.UpdateWishDraft(E.Request(x,{sourceTokenIds={token}})))
    return x,token
end
function E.Route(stars,orders)
    local x=E.New();orders=orders or 11
    local low=stars==11 and {} or {[1]="e01_result_song_faded",[2]="n01_result_stayed_for_promise",[3]="n02_candidate_care"}
    if stars==7 then low[4]="n03_candidate_hide" end
    for index=1,orders do
        local request=R.Accept(x,index)
        if low[index] then
            for _,row in ipairs(x.content.recipes) do if row.letterId==x.content.release.requiredOrderIds[index] and row.expect.facts[1]==low[index] then
                request.mainTokenId=assert(x.tokens[row.recipe.mainWordId]);request.auxTokenIds={}
                for _,wid in ipairs(row.recipe.auxWordIds) do request.auxTokenIds[#request.auxTokenIds+1]=assert(x.tokens[wid]) end
                request.ingredients=U.Copy(row.recipe.ingredients);break
            end end
        end
        local pending=R.Preview(x,request)
        E.Must(x.order.Confirm({orderId=request.orderId,transactionId=pending.transactionId}))
    end
    return x
end
function E.Homes(x)
    for _,item in ipairs(x.content.release.homeItems) do E.Must(x.state.PurchaseHomeItem(R.Quote(x,item.id,item.price))) end
end
return E
