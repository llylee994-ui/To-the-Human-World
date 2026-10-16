local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local U=require "core.StateUtil"
local A=require "ui.landscape.JourneyArt"
local Paper=require "ui.landscape.WishPaper"
local V={}
function V.New(ctx)
    local preview=ctx.panel=="wishPreview"
    local view=A.New(ctx,"wishEditor","sea");local r=view.rect
    local result=ctx.session.queries.GetWishView()
    if not result.ok then ctx.model.Notify(result);return view end
    local wish=result.value;local revision=ctx.model.Refresh().revision
    local rows=U.Copy(wish.placements);local words,byId={},{}
    for _,sample in ipairs(wish.samples) do words[sample.sourceTokenId]=sample.text;byId[sample.sourceTokenId]=sample end
    ctx.wishUndo=ctx.wishUndo or {}
    local title=UI.Panel {position="absolute",left=r.x+12,top=r.y,width=r.w-24,height=68,gap=4,paddingLeft=12,
        backgroundColor={25,40,36,115},borderRadius=4,pointerEvents="none"}
    view.root:AddChild(title)
    A.Label(title,preview and "把愿望交给海风" or "这封信，写给自己","wishEditorTitle",24,{lineHeight=1.25,fontColor={255,246,219,255}})
    A.Label(title,preview and "纸条的位置与字句，会一起收进这只瓶子。" or "点选词条放上纸面，再拖动摆放。用过的词也留在这里。","wishEditHint",12,{lineHeight=1.3,fontColor={255,246,219,255}})
    local trayWidth=preview and 0 or math.min(290,r.w*.28)
    local availableWidth=r.w-trayWidth-(preview and 0 or 22)
    local ph=math.min(r.h-154,availableWidth/1.45);local pw=ph*1.45
    local rect={x=r.x+(availableWidth-pw)/2,y=r.y+76+(r.h-154-ph)/2,w=pw,h=ph}
    local paper=Paper.New(view.root,rect,{placements=rows,words=words},{editable=not preview})
    view.paper=paper
    local footer=UI.Panel {id="wishFooter",position="absolute",left=r.x,right=r.x,bottom=20+((ctx.safeInsets or {}).bottom or 0),
        height=48,flexDirection="row",gap=10,alignItems="center",justifyContent="center",pointerEvents="box-none"}
    view.root:AddChild(footer)
    local function click(fn) return function() if view.Live() and not view.busy then fn() end end end
    if wish.needsStoryCompletion then
        A.Button(footer,"restoreBeforeClosing","回到旅程中",click(function() ctx.model.RestoreEndingCheckpoint() end),true)
        return view
    end
    if preview then
        A.Button(footer,"cancelWishPreview","返回编辑",click(function() ctx.Open("wish") end),false)
        A.Button(footer,"confirmWish","封瓶寄出",click(function()
            if ctx.model.ConfirmEnding("wish",revision).ok then ctx.endingEntrance="wish" end
        end),true,{disabled=not wish.canConfirm,minWidth=180})
        return view
    end
    local function index(id) for i,row in ipairs(rows) do if row.sourceTokenId==id then return i end end end
    local function commit(nextRows,undo)
        if not view.Live() then return false end
        if U.Equal(rows,nextRows) then return true end
        local result=ctx.model.UpdateWishLayout(nextRows,revision)
        if not result.ok then return false end
        if undo then table.remove(ctx.wishUndo)
        else
            ctx.wishUndo[#ctx.wishUndo+1]=U.Copy(rows)
            if #ctx.wishUndo>30 then table.remove(ctx.wishUndo,1) end
        end
        -- Prevent a second callback from committing an obsolete displayed revision.
        view.committed=true
        return true
    end
    local tray=A.Paper(view.root,{id="wishWordTray",position="absolute",left=r.x+r.w-trayWidth,top=r.y+76,
        width=trayWidth,height=r.h-154,padding=25,gap=8})
    A.Label(tray,"收好的词语",nil,21)
    A.Label(tray,"点一下，放到纸上",nil,13,{fontColor=A.muted})
    local scroll=UI.ScrollView {id="wishWordsScroll",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,scrollY=true,showScrollbar=true}
    local list=UI.Panel {width="100%",gap=8,flexShrink=0,paddingRight=8,pointerEvents="box-none"};scroll:AddChild(list);tray:AddChild(scroll)
    for _,sample in ipairs(wish.samples) do
        local id=sample.sourceTokenId;local selected=index(id)~=nil
        A.Button(list,"wish_add_"..id,sample.text,click(function()
            if view.committed or index(id) then return end
            local nextRows=U.Copy(rows);local n=#nextRows
            local row={sourceTokenId=id,x=.23+(n%3)*.27,y=.30+(math.floor(n/3)%5)*.12,angle=(n%3-1)*3}
            nextRows[#nextRows+1]=Paper.Clamp(row,sample.text,pw,ph);ctx.wishSelected=id
            commit(nextRows)
        end),false,{width="100%",disabled=selected,fontSize=16,minHeight=42,whiteSpace="normal"})
    end
    local selectedLabel=A.Label(footer,"选中纸条后可调整", "wishSelection",14,{width=160,maxWidth=190,fontColor={255,246,219,255}})
    local leftButton,rightButton,removeButton
    local function select(id)
        ctx.wishSelected=id
        for key,card in pairs(paper.cards) do
            Widget.SetStyle(card.visual,{borderWidth=key==id and 1 or 0,borderColor={91,111,78,175},borderRadius=2})
            Widget.SetStyle(card.root,{zIndex=key==id and 3 or 1})
        end
        local ready=index(id)~=nil
        selectedLabel:SetText(ready and ("「"..words[id].."」") or "选中纸条后可调整")
        leftButton:SetDisabled(not ready);rightButton:SetDisabled(not ready);removeButton:SetDisabled(not ready)
    end
    local function rotate(delta)
        local i=index(ctx.wishSelected);if not i or view.committed then return end
        local nextRows=U.Copy(rows);nextRows[i].angle=math.max(-15,math.min(15,nextRows[i].angle+delta))
        Paper.Clamp(nextRows[i],words[ctx.wishSelected],pw,ph);commit(nextRows)
    end
    leftButton=A.Button(footer,"wishRotateLeft","左转",click(function() rotate(-3) end),false,{padding={8,12}})
    rightButton=A.Button(footer,"wishRotateRight","右转",click(function() rotate(3) end),false,{padding={8,12}})
    removeButton=A.Button(footer,"wishRemove","移回词盒",click(function()
        local i=index(ctx.wishSelected);if not i or view.committed then return end
        local nextRows=U.Copy(rows);table.remove(nextRows,i);commit(nextRows)
    end),false,{padding={8,12}})
    A.Button(footer,"wishUndo","撤销",click(function()
        local previous=ctx.wishUndo[#ctx.wishUndo];if previous and not view.committed then commit(U.Copy(previous),true) end
    end),false,{disabled=#ctx.wishUndo==0,padding={8,12}})
    A.Button(footer,"wishToTitle","首页",click(ctx.ShowTitle),false,{padding={8,12}})
    A.Button(footer,"previewWish","预览并寄出",click(function() ctx.Open("wishPreview") end),true,{disabled=not wish.canConfirm})
    select(ctx.wishSelected)
    local drag
    local function stop(event) if event.StopPropagation then event:StopPropagation() end end
    local function pointerXY(event,card)
        local bounds=card.root:GetAbsoluteLayout();return bounds.x+event.x,bounds.y+event.y
    end
    local function place(id,row)
        local card=paper.cards[id]
        Widget.SetStyle(card.root,{left=row.x*pw-card.width/2,top=row.y*ph-card.height/2})
    end
    local function cancel()
        if not drag then return end
        place(drag.id,rows[drag.index]);drag=nil;view.busy=false
    end
    for id,card in pairs(paper.cards) do
        card.root.props.onPointerDown=function(event)
            stop(event)
            if not view.Live() or view.committed or drag or (event.IsPrimaryAction and not event:IsPrimaryAction()) then return end
            local x,y=pointerXY(event,card);local i=index(id)
            drag={id=id,index=i,pointer=event.pointerId,x=x,y=y,row=U.Copy(rows[i])}
            view.busy=true;select(id)
        end
        card.root.props.onPointerMove=function(event)
            stop(event);if not drag or drag.pointer~=event.pointerId or drag.id~=id then return end
            local x,y=pointerXY(event,card);local row=U.Copy(rows[drag.index])
            row.x=row.x+(x-drag.x)/pw;row.y=row.y+(y-drag.y)/ph
            drag.row=Paper.Clamp(row,words[id],pw,ph);place(id,drag.row)
        end
        card.root.props.onPointerUp=function(event)
            stop(event);if not drag or drag.pointer~=event.pointerId or drag.id~=id then return end
            if not view.Live() then cancel();return end
            local row=drag.row;local before=rows[drag.index]
            if math.abs(row.x-before.x)*pw+math.abs(row.y-before.y)*ph<4 then cancel();return end
            -- Snap gently to nearby paper rows, without forcing a sentence grid.
            local snapped=math.floor(row.y/.06+.5)*.06
            if math.abs(row.y-snapped)*ph<7 then row.y=snapped end
            Paper.Clamp(row,words[id],pw,ph)
            local nextRows=U.Copy(rows);nextRows[drag.index]=row
            cancel();commit(nextRows)
        end
        card.root.props.onPointerCancel=function(event) stop(event);if drag and drag.pointer==event.pointerId then cancel() end end
        card.root.props.onClick=function() end
    end
    local initialViewport=U.Copy(ctx.viewport or {w=1280,h=720})
    function view.Update(_,focused)
        local vp=ctx.viewport or initialViewport
        if not focused or vp.w~=initialViewport.w or vp.h~=initialViewport.h then cancel() end
    end
    function view.Destroy() cancel();view.dead=true end
    return view
end
return V
