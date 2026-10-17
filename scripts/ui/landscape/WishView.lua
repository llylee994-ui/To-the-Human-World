local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local U=require "core.StateUtil"
local A=require "ui.landscape.JourneyArt"
local Paper=require "ui.landscape.WishPaper"
local Drawer=require "ui.landscape.WordTrayDrawer"
local Tray=require "ui.landscape.WishTray"
local Story=require "ui.landscape.StoryStyle"
local C=require "systems.WishCollage"
local Decor=require "data.wish_decorations"
local V={}
local cream={250,238,211,255}
function V.New(ctx)
    local preview=ctx.panel=="wishPreview"
    local view=A.New(ctx,"wishEditor",false)
    local vp=ctx.viewport or {w=1280,h=720};local safe=ctx.safeInsets or {left=0,top=0,right=0,bottom=0}
    local sw,sh=vp.w-safe.left-safe.right,vp.h-safe.top-safe.bottom
    A.Image(view.root,"image/wish-collage-r1/table-background.png",{id="wishDeskBackdrop",left=0,top=0,width="100%",height="100%",backgroundFit="cover",zIndex=3})
    view.root:AddChild(UI.Panel {position="absolute",left=0,top=0,width="100%",height=100,pointerEvents="none",zIndex=3.5,
        backgroundGradient={type="linear",direction="to-bottom",from={29,18,10,165},to={29,18,10,0}}})
    local result=ctx.session.queries.GetWishView()
    if not result.ok then ctx.model.Notify(result);return view end
    local wish=result.value;local revision=ctx.model.Refresh().revision
    local rows=U.Copy(wish.placements);local words={}
    for _,sample in ipairs(wish.samples) do words[sample.sourceTokenId]=sample.text end
    ctx.wishUndo=ctx.wishUndo or {}
    local compact=sh<570
    local top=safe.top+18
    local trayWidth=preview and 0 or math.floor(sw*Drawer.WidthRatio)
    local startX=preview and safe.left+20 or safe.left+trayWidth+24
    A.Label(view.root,preview and "把愿望交给大海" or "把愿望寄往人间","wishEditorTitle",compact and 22 or 27,
        {position="absolute",left=startX+12,top=top,width=vp.w-startX-safe.right-28,height=42,lineHeight=1.2,fontColor=cream})
    A.Label(view.root,preview and "这是你亲手拼好的愿望。" or "点取素材，拖动摆放。小圆柄可自由旋转、缩放。","wishEditHint",13,
        {position="absolute",left=startX+12,top=top+40,width=vp.w-startX-safe.right-28,height=25,lineHeight=1.2,fontColor={242,220,182,255}})
    local available=vp.w-safe.right-startX-20
    local workHeight=preview and sh-160 or sh-240
    local ph=math.min(workHeight,available*.75);local pw=ph/ .75
    local rect={x=startX+(available-pw)/2,y=top+74+(workHeight-ph)/2,w=pw,h=ph}
    local paper=Paper.New(view.root,rect,{placements=rows,words=words},{editable=not preview})
    view.paper=paper
    local function index(id) for i,row in ipairs(rows) do if C.Id(row)==id then return i end end end
    local function click(fn) return function() if view.Live() and not view.busy and not view.committed then fn() end end end
    local function button(parent,id,text,fn,primary,props)
        props=props or {};props.id=id;props.text=text;props.onClick=click(fn)
        props.minHeight=props.minHeight or 40;props.fontSize=props.fontSize or 14
        local b=Story.Button(props,primary and "primary" or "secondary");parent:AddChild(b);return b
    end
    local footer=UI.Panel {id="wishFooter",position="absolute",left=startX,right=safe.right+20,bottom=safe.bottom+22,
        height=52,flexDirection="row",gap=12,alignItems="center",justifyContent="center",zIndex=20,pointerEvents="box-none"}
    view.root:AddChild(footer)
    if wish.needsStoryCompletion then
        button(footer,"restoreBeforeClosing","回到旅程中",function() ctx.model.RestoreEndingCheckpoint() end,true)
        return view
    end
    if preview then
        button(footer,"cancelWishPreview","再摆一摆",function() ctx.Open("wish") end,false,{width=170})
        button(footer,"confirmWish","封瓶寄出",function()
            if ctx.model.ConfirmEnding("wish",revision).ok then ctx.endingEntrance="wish" end
        end,true,{disabled=not wish.canConfirm,width=190})
        return view
    end
    local function commit(nextRows,undo)
        if not view.Live() or view.committed then return false end
        if U.Equal(rows,nextRows) then return true end
        if not ctx.model.UpdateWishLayout(nextRows,revision).ok then return false end
        if undo then table.remove(ctx.wishUndo)
        else
            ctx.wishUndo[#ctx.wishUndo+1]=U.Copy(rows)
            if #ctx.wishUndo>30 then table.remove(ctx.wishUndo,1) end
        end
        view.committed=true;return true
    end
    local maxZ=#rows
    for i,row in ipairs(rows) do maxZ=math.max(maxZ,C.Depth(row,i)) end
    local function add(row)
        if #rows>=128 then return end
        row.x=.45+(#rows%3)*.05;row.y=.43+(#rows%4)*.06;row.angle=0;row.scale=1;row.z=maxZ+1
        local nextRows=U.Copy(rows);nextRows[#nextRows+1]=Paper.Clamp(row,words[row.sourceTokenId],pw,ph)
        ctx.wishSelected=C.Id(row);commit(nextRows)
    end
    local tray=Tray.New(ctx,view,rows,index,function(id)
        if view.Live() and not view.busy and not view.committed and not index(id) then add({sourceTokenId=id}) end
    end,function(id)
        if not view.Live() or view.busy or view.committed then return end
        local n=1;while index("decor:"..n) do n=n+1 end
        add({decorationId=id,instanceId="decor:"..n})
    end)
    local inspector=UI.Panel {id="wishInspector",position="absolute",left=startX+10,right=safe.right+30,bottom=safe.bottom+84,height=78,
        zIndex=12,backgroundColor={34,23,14,165},borderWidth=1,borderColor={182,138,77,95},borderRadius=4,padding={6,10},gap=2}
    view.root:AddChild(inspector)
    local selection=A.Label(inspector,"选中一张纸条或装饰","wishSelection",13,{height=24,lineHeight=1.25,fontColor=cream})
    local controls={}
    local function edit(fn,lockedAllowed)
        local i=index(ctx.wishSelected);if not i or view.committed or rows[i].locked and not lockedAllowed then return end
        local nextRows=U.Copy(rows);fn(nextRows,i)
        if nextRows[i] and C.Id(nextRows[i])==C.Id(rows[i]) and not lockedAllowed then
            Paper.Clamp(nextRows[i],words[C.Id(nextRows[i])],pw,ph)
        end
        commit(nextRows)
    end
    local actions=UI.Panel {flexDirection="row",gap=4,height=37};inspector:AddChild(actions)
    local row1,row2=actions,actions
    local function tool(parent,id,text,fn,allowLocked)
        local b=button(parent,id,text,function() edit(fn,allowLocked) end,false,{minWidth=0,flexGrow=1,fontSize=12,padding={4,2},minHeight=36})
        controls[id]=b;return b
    end
    tool(row1,"wishRotateLeft","左转",function(a,i) a[i].angle=((a[i].angle-3+180)%360)-180 end)
    tool(row1,"wishRotateRight","右转",function(a,i) a[i].angle=((a[i].angle+3+180)%360)-180 end)
    tool(row1,"wishShrink","缩小",function(a,i) a[i].scale=math.max(.25,(a[i].scale or 1)-.1) end)
    tool(row1,"wishGrow","放大",function(a,i) a[i].scale=math.min(3,(a[i].scale or 1)+.1) end)
    local function layer(a,i,delta)
        local z=C.Depth(a[i],i);local adjacent
        for j,r in ipairs(a) do if j~=i then
            local other=C.Depth(r,j)
            if delta>0 and other>=z and (not adjacent or other<adjacent) then adjacent=other end
            if delta<0 and other<=z and (not adjacent or other>adjacent) then adjacent=other end
        end end
        a[i].z=math.max(-999999,math.min(999999,(adjacent or z)+delta*.5))
    end
    tool(row2,"wishLayerDown","下一层",function(a,i) layer(a,i,-1) end)
    tool(row2,"wishLayerUp","上一层",function(a,i) layer(a,i,1) end)
    local lock=tool(row2,"wishLock","锁定",function(a,i) a[i].locked=not a[i].locked end,true)
    tool(row2,"wishRemove","收回",function(a,i) table.remove(a,i) end)
    local gestures=false --[[@as table|false]]
    local function select(id)
        ctx.wishSelected=id;paper.Select(id)
        local i=index(id);local row=i and rows[i]
        selection:SetText(row and ((row.locked and "已锁定 · " or "")..(row.sourceTokenId and words[id] or Decor.byId[row.decorationId].label)) or "选中一张纸条或装饰")
        for key,b in pairs(controls) do b:SetDisabled(not row or (row.locked and key~="wishLock") or false) end
        lock:SetText(row and row.locked and "解锁" or "锁定")
        if gestures then gestures.Select(id) end
    end
    gestures=require("ui.landscape.WishGestures").Bind(view,ctx,paper,rows,words,select,commit)
    button(footer,"wishUndo","撤销",function()
        local previous=ctx.wishUndo[#ctx.wishUndo];if previous then commit(U.Copy(previous),true) end
    end,false,{width=100,disabled=#ctx.wishUndo==0})
    button(footer,"wishToTitle","暂回首页",ctx.ShowTitle,false,{width=140})
    button(footer,"previewWish","预览并寄出",function() ctx.Open("wishPreview") end,true,{width=190,disabled=not wish.canConfirm})
    select(index(ctx.wishSelected) and ctx.wishSelected or rows[1] and C.Id(rows[1]) or false)
    function view.Update(dt,focused) gestures.Update(dt,focused);tray.Update(dt) end
    function view.Destroy() gestures.Cancel();tray.Destroy();view.dead=true end
    return view
end
return V
