-- Wish-specific picking adapter for the existing drawer. All drawer art/layout stays in WordTrayDrawer.
local UI=require "urhox-libs/UI"
local U=require "core.StateUtil"
local Drawer=require "ui.landscape.WordTrayDrawer"
local Arrow=require "ui.landscape.EmbroideredArrow"
local Paper=require "ui.landscape.WishPaper"
local Decor=require "data.wish_decorations"
local A=require "ui.landscape.JourneyArt"
local T={}
function T.New(ctx,view,rows,index,bindSource)
    local result=ctx.session.queries.GetWordTray()
    if not result.ok then ctx.model.Notify(result);return {Update=function() end,Destroy=function() end} end
    local data=U.Copy(result.value)
    local groups={}
    for _,category in ipairs(data.categories) do category.availableCount=0;groups[category.id]=category end
    local selected=ctx.wishSelected or rows[1] and rows[1].sourceTokenId
    local category
    for _,card in ipairs(data.cards) do
        card.available=index(card.tokenId)==nil;card.selectedRole=false
        if card.available then groups[card.categoryId].availableCount=groups[card.categoryId].availableCount+1 end
        if card.tokenId==selected then category=card.categoryId end
    end
    local adapter=setmetatable({wordTray=ctx.wishDrawerState or false,panel="words",workbench=false},{__index=ctx})
    local state=Drawer.State(adapter)
    if not ctx.wishDrawerState then
        ctx.wishDrawerState=state;state.open=1;state.target=1;state.settled=true;state.category=category or false
    end
    if ctx.wishDrawerVisible==nil then ctx.wishDrawerVisible=true end
    adapter.Close=function() ctx.wishDrawerVisible=false;ctx.model.dirty=true end
    if ctx.wishDrawerVisible then
        Drawer.Render(adapter,view.root,{view=data,cardPrefix="wish_add_",allCategories=true,
            bindSource=function(widget,card)
                widget.props.disabled=not card.available
                widget.props.onClick=function() end
                if card.available then bindSource(widget,function() return {sourceTokenId=card.tokenId,x=.5,y=.5,angle=0,scale=1,canvasAspect=2} end) end
            end,
            markText=function(card) return not card.available and "已贴" or false end,
            statusText=function(card) return card.available and "可放到信纸上" or "已在信纸上" end,
            hint="拖入信纸，自由摆放",
            footerText=function(active) return active.id=="wish_decor" and "装饰 · 可重复取用" or active.title.." · 待贴 "..active.availableCount end,
            extraCategories={{id="wish_decor",title="装饰",availableCount=#Decor.list}},
            extraItems=Decor.list,
            measureExtra=function(_,width,height,compact)
                return {width=(width-10)/2,height=math.min(height,compact and 90 or 112)}
            end,
            renderExtra=function(parent,frame,metrics,x,y)
                local cellWidth,cellHeight=metrics.width,metrics.height
                local cell=UI.Panel {id="wish_decor_"..frame.id,position="absolute",left=x,top=y,
                    width=cellWidth,height=cellHeight,onClick=function() end}
                local maxHeight=cellHeight-28
                local w=math.min(cellWidth-8,maxHeight*frame.w/frame.h);local h=w*frame.h/frame.w
                cell:AddChild(Paper.Frame(frame,{position="absolute",left=(cellWidth-w)/2,top=3,width=w,height=h,pointerEvents="none"}))
                A.Label(cell,frame.label,nil,12,{position="absolute",left=0,right=0,bottom=0,height=24,
                    textAlign="center",lineHeight=1.2,fontColor={250,238,211,255}})
                bindSource(cell,function()
                    local n=1;while index("decor:"..n) do n=n+1 end
                    return {decorationId=frame.id,instanceId="decor:"..n,x=.5,y=.5,angle=0,scale=1,canvasAspect=2,freePlacement=true}
                end)
                parent:AddChild(cell)
            end})
        state.panel.props.zIndex=10
    else
        view.root:AddChild(Arrow.New {id="wishOpenTray",arrowDirection="right",position="absolute",left=((ctx.safeInsets or {}).left or 0),
            bottom=((ctx.safeInsets or {}).bottom or 0)+12,zIndex=12,onClick=function()
                if not view.Live() or view.busy then return end
                ctx.wishDrawerVisible=true;state.closing=false;Drawer.Open(adapter,true);ctx.model.dirty=true
            end})
    end
    local panel=state.panel
    return {Update=function(dt) if view.Live() then Drawer.Update(adapter,dt) end end,
        Destroy=function() if state.panel==panel then state.panel=false end end}
end
return T
