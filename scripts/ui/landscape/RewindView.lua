-- 标题页的逐日回溯：只展示本轮真实日开头，恢复动作交给 PlayModel/GameState。
local UI=require "urhox-libs/UI"
local A=require "ui.landscape.JourneyArt"
local V={}
local ink=A.ink
local muted=A.muted

local function statRow(parent,stats,compact)
    local row=UI.Panel {id="rewindStats",width="100%",flexDirection="row",alignItems="stretch",
        justifyContent="space-between",gap=6,padding={compact and 7 or 10,compact and 8 or 12},
        backgroundColor={245,236,211,190},borderRadius=6,pointerEvents="none"}
    parent:AddChild(row)
    local function cell(label,value)
        local box=UI.Panel {flexGrow=1,flexShrink=1,flexBasis=0,flexDirection="column",alignItems="center",gap=2,pointerEvents="none"}
        A.Label(box,label,nil,compact and 10 or 11,{fontColor=muted,textAlign="center",lineHeight=1.2})
        A.Label(box,tostring(value),nil,compact and 15 or 17,{fontColor=ink,textAlign="center",lineHeight=1.2})
        row:AddChild(box)
    end
    cell("来信",tostring(stats.letters).." 封")
    cell("金币",stats.currency)
    cell("词条",tostring(stats.tokens).." 条")
    cell("采购记录",tostring(stats.purchases).." 条")
end

local function backToTitle(ctx)
    ctx.panel="title";ctx.rewindSelected=false;ctx.rewindPage=1;ctx.model.dirty=true
end

local function finishRestore(ctx,pointId)
    ctx.rewindSelected=false;ctx.rewindPage=1
    ctx.wishUndo={};ctx.wishSelected=false;ctx.reviewEnding=false;ctx.endingEntrance=false
    local ok=ctx.ContinueJourney()
    if not ok then ctx.model.dirty=true end
end

function V.New(ctx)
    local view=A.New(ctx,"rewindView",false)
    local vp=ctx.viewport or {w=1280,h=720}
    local rect=view.rect
    local modalW=math.min(920,rect.w)
    local compact=rect.h<560 or modalW<700
    local modalH=math.min(560,rect.h)
    local left=rect.x+(rect.w-modalW)/2
    local top=rect.y+math.max(0,(rect.h-modalH)/2)

    -- 参考标题页保留室内背景；压暗层由 JourneyArt 提供。
    local artScale=math.max(vp.w/1672,vp.h/941)
    A.Image(view.root,"image/title-screen-r1/shop-doorway-soft.png",{id="rewindBackdrop",left=0,
        top=(vp.h-941*artScale)/2,width=1672*artScale,height=941*artScale,backgroundFit="fill",zIndex=0})

    local paper=A.Paper(view.root,{id="rewindPaper",position="absolute",left=left,top=top,width=modalW,height=modalH,
        padding=compact and 16 or 24,gap=compact and 8 or 12,flexDirection="column",overflow="hidden"})

    local query=rawget(ctx.session.queries,"GetRewindView")
    local result=query and query()
    if not result or not result.ok then
        if result then ctx.model.Notify(result) end
        A.Label(paper,"暂时无法读取回溯记录。",nil,18,{textAlign="center",fontColor=ink})
        A.Button(paper,"rewindCancel","返回首页",function() if view.Live() then backToTitle(ctx) end end,false,
            {alignSelf="center",minWidth=160})
        return view
    end
    local data=result.value
    local points=data.points or {}

    local header=UI.Panel {id="rewindHeader",width="100%",flexDirection="row",alignItems="center",
        justifyContent="center",pointerEvents="box-none",minHeight=compact and 44 or 52}
    local titleBox=UI.Panel {flexGrow=1,flexShrink=1,flexBasis=0,flexDirection="column",alignItems="center",gap=2,pointerEvents="none"}
    A.Label(titleBox,"进度回溯",nil,compact and 22 or 27,{textAlign="center",fontColor=ink,lineHeight=1.2})
    A.Label(titleBox,string.format("本轮旅程 · 当前第 %d 天",data.currentDay),nil,compact and 11 or 13,
        {textAlign="center",fontColor=muted,lineHeight=1.2})
    header:AddChild(titleBox)
    A.Button(header,"rewindClose","×",function() if view.Live() then backToTitle(ctx) end end,false,
        {position="absolute",right=0,top=0,width=46,minWidth=46,minHeight=44,padding=0,fontSize=22})
    paper:AddChild(header)

    local scroll=UI.ScrollView {id="rewindScroll",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,
        scrollY=true,showScrollbar=compact}
    local body=UI.Panel {width="100%",flexDirection="column",gap=compact and 8 or 12,pointerEvents="box-none"}
    scroll:AddChild(body);paper:AddChild(scroll)

    local perPage=modalW>=760 and 7 or modalW>=560 and 5 or 4
    local pageCount=math.max(1,math.ceil(#points/perPage))
    local selected
    local selectedIndex=false
    for i,point in ipairs(points) do
        if point.id==ctx.rewindSelected then selected=point;selectedIndex=i;break end
    end
    if not selected and #points>0 then
        -- 默认选中最近一个"昨天"；只有今天时选中今天清晨。
        selectedIndex=#points
        for i=#points,1,-1 do if points[i].day<data.currentDay then selectedIndex=i;break end end
        selected=points[selectedIndex]
        ctx.rewindSelected=selected.id
        ctx.rewindPage=math.ceil(selectedIndex/perPage)
    end
    local page=math.max(1,math.min(pageCount,ctx.rewindPage or 1))
    ctx.rewindPage=page

    if #points==0 then
        A.Label(body,"还没有可回溯的日开头记录。","rewindEmpty",compact and 17 or 20,{textAlign="center",fontColor=ink})
        A.Label(body,data.reason~="" and data.reason or "从下一次跨天开始，会自动保存当天清晨的完整进度。",nil,
            compact and 12 or 14,{textAlign="center",fontColor=muted,whiteSpace="normal",width="100%"})
    else
        local timeline=UI.Panel {id="rewindTimeline",width="100%",flexDirection="row",alignItems="flex-start",
            justifyContent="space-between",gap=3,pointerEvents="box-none"}
        body:AddChild(timeline)
        local cellWidth=math.max(46,math.floor((modalW-(compact and 34 or 50))/perPage)-4)
        local first=(page-1)*perPage+1
        local last=math.min(#points,first+perPage-1)
        for i=first,last do
            local point=points[i]
            local chosen=selected and point.id==selected.id
            local cell=UI.Panel {id="rewindDay_"..point.day,width=cellWidth,minHeight=compact and 66 or 78,
                flexDirection="column",alignItems="center",gap=3,padding={5,1},borderRadius=6,
                backgroundColor=chosen and {238,216,170,235} or {0,0,0,0},
                pointerEvents="box-only",onClick=function()
                    if not view.Live() then return end
                    ctx.rewindSelected=point.id;ctx.model.dirty=true
                end}
            timeline:AddChild(cell)
            local diamond=UI.Panel {width=9,height=9,rotate=45,
                backgroundColor=point.available and {166,126,60,255} or {166,160,145,170},
                borderWidth=1,borderColor={120,90,45,180},pointerEvents="none"}
            cell:AddChild(diamond)
            A.Label(cell,string.format("第 %d 天",point.day),nil,compact and 11 or 13,
                {textAlign="center",fontColor=point.available and ink or {150,145,130,255},whiteSpace="nowrap",lineHeight=1.2})
            if not point.available and point.reason:find("旧版本",1,true) then
                A.Label(cell,"不可恢复","rewindStory_"..point.day,compact and 9 or 10,
                    {textAlign="center",fontColor={150,60,40,255},whiteSpace="nowrap",lineHeight=1.2})
            elseif point.storyTitle then
                A.Label(cell,point.storyTitle,"rewindStory_"..point.day,compact and 9 or 10,
                    {textAlign="center",fontColor=muted,whiteSpace="normal",lineHeight=1.2,width="100%"})
            end
            if point.day==data.currentDay then
                local tag=UI.Panel {padding={1,5},borderRadius=3,backgroundColor={238,222,185,255},pointerEvents="none"}
                A.Label(tag,"当前",nil,compact and 9 or 10,{textAlign="center",fontColor={122,96,47,255},lineHeight=1.2})
                cell:AddChild(tag)
            end
        end
        if pageCount>1 then
            local nav=UI.Panel {id="rewindPager",width="100%",flexDirection="row",alignItems="center",
                justifyContent="center",gap=12,pointerEvents="box-none"}
            body:AddChild(nav)
            A.Button(nav,"rewindPrev","上一页",function()
                if view.Live() and page>1 then ctx.rewindPage=page-1;ctx.model.dirty=true end
            end,false,{minWidth=84,disabled=page<=1})
            A.Label(nav,string.format("第 %d / %d 页",page,pageCount),nil,compact and 11 or 13,
                {textAlign="center",fontColor=muted})
            A.Button(nav,"rewindNext","下一页",function()
                if view.Live() and page<pageCount then ctx.rewindPage=page+1;ctx.model.dirty=true end
            end,false,{minWidth=84,disabled=page>=pageCount})
        end
    end

    local detail=UI.Panel {id="rewindDetail",width="100%",flexDirection="column",alignItems="center",
        gap=compact and 4 or 6,padding={compact and 4 or 6,0},pointerEvents="box-none"}
    body:AddChild(detail)
    if selected then
        local currentPoint=selected.at=="current"
        local oldVersion=not selected.available and selected.reason:find("旧版本",1,true)
        local detailTitle
        if oldVersion or selected.storyTitle then
            detailTitle=selected.label
        elseif currentPoint then
            detailTitle=string.format("第 %d 天 · 启用回溯时的进度",selected.day)
        else
            detailTitle=string.format("第 %d 天",selected.day)
        end
        A.Label(detail,detailTitle,"rewindDetailTitle",compact and 19 or 23,
            {textAlign="center",fontColor=ink,lineHeight=1.3})
        A.Label(detail,currentPoint and "恢复启用回溯时保存的完整进度" or "回到这一天开始的时候",nil,compact and 11 or 13,
            {textAlign="center",fontColor=muted})
        A.Label(detail,currentPoint and "当时金币、来信、词条与采购记录都会恢复" or "来信、金币、词条与采购记录随当天进度恢复",
            nil,compact and 10 or 12,{textAlign="center",fontColor=muted})
        statRow(detail,selected.stats,compact)
        if not selected.available then
            A.Label(detail,selected.reason~="" and selected.reason or "该日期不可恢复",nil,compact and 11 or 13,
                {textAlign="center",fontColor={150,60,40,255},whiteSpace="normal",width="100%"})
        end
    elseif data.reason~="" then
        A.Label(detail,data.reason,nil,compact and 12 or 14,{textAlign="center",fontColor={150,60,40,255}})
    end

    local backup=data.backup
    if backup then
        local row=UI.Panel {id="rewindBackupRow",width="100%",flexDirection="row",alignItems="center",
            justifyContent="center",gap=10,flexWrap="wrap",pointerEvents="box-none"}
        body:AddChild(row)
        A.Label(row,backup.label,nil,compact and 10 or 12,{fontColor=muted,textAlign="center"})
        A.Button(row,"rewindBackupRestore","恢复回溯前进度",function()
            if not view.Live() or not backup.available then return end
            local restored=ctx.model.RestoreBeforeRewind()
            if restored and restored.ok then finishRestore(ctx) end
        end,false,{minWidth=150,disabled=not backup.available})
        if not backup.available then
            A.Label(detail,backup.reason~="" and backup.reason or "回溯前进度不可恢复",nil,compact and 10 or 12,
                {textAlign="center",fontColor={150,60,40,255}})
        end
    end

    local actions=UI.Panel {id="rewindActions",width="100%",flexDirection="row",alignItems="center",
        justifyContent="center",gap=12,flexShrink=0,pointerEvents="box-none"}
    paper:AddChild(actions)
    A.Button(actions,"rewindCancel","取消",function()
        if view.Live() then backToTitle(ctx) end
    end,false,{minWidth=compact and 110 or 150})
    A.Button(actions,"rewindRestore",selected and string.format("回到第 %d 天",selected.day) or "回到这一天",
        function()
            if not view.Live() or not selected or not selected.available then return end
            local restored=ctx.model.RestoreDay(selected.id)
            if restored and restored.ok then finishRestore(ctx) end
        end,true,{minWidth=compact and 170 or 210,disabled=not (selected and selected.available)})

    local warning="仅可回到本轮已到达的日期"
    if selected then
        if selected.at=="current" then
            warning="这份“当前进度”保存于启用回溯时；之后的天数会从这里重新走，回溯前的进度会保留为可恢复备份。"
        else
            warning=string.format("之后的天数记录会被截断，进度将从第 %d 天重新走。当前进度会保留为可恢复备份。",selected.day)
        end
    end
    A.Label(paper,warning,nil,compact and 9 or 11,
        {textAlign="center",fontColor=muted,whiteSpace="normal",width="100%",flexShrink=0})
    return view
end
return V
