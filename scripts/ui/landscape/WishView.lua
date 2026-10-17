-- Wide composition surface, direct tray drag, and tools anchored to the selected piece.
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local U=require "core.StateUtil"
local A=require "ui.landscape.JourneyArt"
local Paper=require "ui.landscape.WishPaper"
local Tray=require "ui.landscape.WishTray"
local Story=require "ui.landscape.StoryStyle"
local C=require "systems.WishCollage"
local Layout=require "ui.landscape.WishLayout"
local V={}
function V.New(ctx)
    local preview=ctx.panel=="wishPreview"
    local view=A.New(ctx,"wishEditor",false)
    local vp=ctx.viewport or {w=1280,h=720};local safe=ctx.safeInsets or {left=0,top=0,right=0,bottom=0}
    A.Image(view.root,"image/wish-collage-r1/table-background.png",{id="wishDeskBackdrop",left=0,top=0,width="100%",height="100%",backgroundFit="cover",zIndex=3})
    local result=ctx.session.queries.GetWishView()
    if not result.ok then ctx.model.Notify(result);return view end
    local wish=result.value;local revision=ctx.model.Refresh().revision
    local savedRows=U.Copy(wish.placements);local rows=C.ForCanvas(savedRows,2);local words={}
    for _,sample in ipairs(wish.samples) do words[sample.sourceTokenId]=sample.text end
    ctx.wishUndo=ctx.wishUndo or {}
    local l=Layout.Compute(vp,safe,preview,2,ctx.menuRect);local rect=l.paper
    for _,row in ipairs(rows) do
        Paper.Clamp(row,words[row.sourceTokenId],rect.w,rect.h)
        -- Migrate only the editable projection; old frozen keepsakes retain their rules.
        if row.decorationId then row.freePlacement=true end
    end
    if preview then rect=Paper.FitComposition(l.area,rows,words,2) end
    view.interactionRect=U.Copy(l.workspace)
    if ctx.wishDrawerVisible==false then
        view.interactionRect.x=safe.left+12
        view.interactionRect.w=vp.w-safe.right-12-view.interactionRect.x
    end
    local pw,ph=rect.w,rect.h
    A.Label(view.root,preview and "把愿望交给大海" or "把愿望寄往人间","wishEditorTitle",16,
        {position="absolute",left=l.title.x,top=l.title.y,width=l.title.w,height=l.title.h,lineHeight=1.2,textAlign="center",fontColor={250,238,211,255},zIndex=20})
    local paper=Paper.New(view.root,rect,{placements=rows,words=words},{editable=not preview,hitArea={x=0,y=0,w=vp.w,h=vp.h}})
    paper.root.props.zIndex=5;view.paper=paper
    local function index(id) for i,row in ipairs(rows) do if C.Id(row)==id then return i end end end
    local function click(fn) return function() if view.Live() and not view.busy and not view.committed then fn() end end end
    local function button(parent,id,text,fn,primary,props)
        props=props or {};props.id=id;props.text=text;props.onClick=click(fn)
        props.height=44;props.minHeight=44;props.minWidth=0;props.fontSize=props.fontSize or 14
        local b=Story.Button(props,primary and "primary" or "secondary");parent:AddChild(b);return b
    end
    local actions=UI.Panel {id="wishHeaderActions",position="absolute",left=l.actions.x,top=l.actions.y,width=l.actions.w,height=l.actions.h,
        flexDirection="row",gap=8,alignItems="center",justifyContent="center",zIndex=20,pointerEvents="box-none"}
    view.root:AddChild(actions)
    if wish.needsStoryCompletion then
        button(actions,"restoreBeforeClosing","回到旅程中",function() ctx.model.RestoreEndingCheckpoint() end,true)
        return view
    end
    if preview then
        button(actions,"cancelWishPreview","再摆一摆",function() ctx.Open("wish") end,false,{width="48%"})
        button(actions,"confirmWish","封瓶寄出",function()
            if ctx.model.ConfirmEnding("wish",revision,rows).ok then ctx.endingEntrance="wish" end
        end,true,{disabled=not wish.canConfirm,width="48%"})
        return view
    end
    local function commit(nextRows,undo)
        if not view.Live() or view.committed then return false end
        if U.Equal(rows,nextRows) and not undo then return true end
        if not ctx.model.UpdateWishLayout(nextRows,revision).ok then return false end
        if undo then table.remove(ctx.wishUndo)
        else
            ctx.wishUndo[#ctx.wishUndo+1]=U.Copy(savedRows)
            if #ctx.wishUndo>30 then table.remove(ctx.wishUndo,1) end
        end
        view.committed=true;return true
    end
    local inspector=UI.Panel {id="wishInspector",position="absolute",width=math.min(368,rect.w-12),height=48,
        visible=false,zIndex=30,padding={2,4},flexDirection="row",gap=4,pointerEvents="box-none"}
    view.root:AddChild(inspector)
    local controls={}
    local function edit(fn,allowLocked)
        local i=index(ctx.wishSelected)
        if not i or view.committed or rows[i].locked and not allowLocked then return end
        local nextRows=U.Copy(rows);fn(nextRows,i)
        if nextRows[i] and C.Id(nextRows[i])==C.Id(rows[i]) and not allowLocked then Paper.Clamp(nextRows[i],words[C.Id(nextRows[i])],pw,ph) end
        commit(nextRows)
    end
    local function tool(id,text,fn,allowLocked)
        local b=A.Button(inspector,id,text,click(function() edit(fn,allowLocked) end),false,
            {height=44,minHeight=44,minWidth=0,flexGrow=1,flexBasis=0,padding={4,2},pressedPadding={4,2},fontSize=13,
                backgroundImage=false,hoverBackgroundImage=false,pressedBackgroundImage=false,disabledBackgroundImage=false,
                variantBackgroundImage={},borderWidth=1,hoverBorderWidth=1,pressedBorderWidth=1,borderRadius=3,
                borderColor={137,119,93,170},backgroundColor={250,247,239,248},
                hoverBackgroundColor={255,253,246,255},pressedBackgroundColor={232,225,209,255},
                disabledBackgroundColor={246,242,232,220},textColor={88,74,55,255},disabledTextColor={88,74,55,95}})
        controls[id]=b;return b
    end
    local function layer(a,i,delta)
        local z=C.Depth(a[i],i);local adjacent
        for j,r in ipairs(a) do if j~=i then local other=C.Depth(r,j)
            if delta>0 and other>=z and (not adjacent or other<adjacent) then adjacent=other end
            if delta<0 and other<=z and (not adjacent or other>adjacent) then adjacent=other end
        end end
        a[i].z=math.max(-999999,math.min(999999,(adjacent or z)+delta*.5))
    end
    tool("wishLayerDown","下一层",function(a,i) layer(a,i,-1) end)
    tool("wishLayerUp","上一层",function(a,i) layer(a,i,1) end)
    local lock=tool("wishLock","锁定",function(a,i) a[i].locked=not a[i].locked end,true)
    tool("wishRemove","收回",function(a,i) table.remove(a,i) end)
    local gestures=false --[[@as table|false]]
    local function select(id,display)
        ctx.wishSelected=id;paper.Select(id)
        local i=index(id);local row=i and (display or paper.cards[id].display)
        inspector:SetVisible(row~=nil and row~=false)
        if row then
            local b=Paper.Bounds(row,words[id],rect)
            local r=Layout.Tools(b,view.interactionRect,368,48)
            Widget.SetStyle(inspector,{left=r.x,top=r.y,width=r.w})
        end
        for key,b in pairs(controls) do b:SetDisabled(not row or (row.locked and key~="wishLock") or false) end
        lock:SetText(row and row.locked and "解锁" or "锁定")
        if gestures then gestures.Select(id) end
    end
    gestures=require("ui.landscape.WishGestures").Bind(view,ctx,paper,rows,words,select,commit)
    view.gestures=gestures
    local function clearSelection() if not view.busy then select(false) end end
    paper.root.props.onClick=clearSelection
    view.root.props.onClick=clearSelection
    local tray=Tray.New(ctx,view,rows,index,function(widget,factory) gestures.Source(widget,factory) end) --[[@as {Update:fun(number),Destroy:fun()}]]
    button(actions,"wishUndo","撤销",function()
        local previous=ctx.wishUndo[#ctx.wishUndo];if previous then commit(U.Copy(previous),true) end
    end,false,{width="20%",disabled=#ctx.wishUndo==0})
    button(actions,"wishToTitle","暂回首页",ctx.ShowTitle,false,{width="32%"})
    button(actions,"previewWish","预览寄出",function() ctx.Open("wishPreview") end,true,{width="44%",disabled=not wish.canConfirm})
    select(index(ctx.wishSelected) and ctx.wishSelected or false)
    function view.Update(dt,focused) gestures.Update(dt,focused);tray.Update(dt) end
    function view.Destroy() gestures.Cancel();tray.Destroy();view.dead=true end
    return view
end
return V
