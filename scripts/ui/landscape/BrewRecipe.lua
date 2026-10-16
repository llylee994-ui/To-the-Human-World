-- Shallow recipe strip and explicitly opened details, sharing the real draft.
local UI=require "urhox-libs/UI"
local H=require "ui.landscape.HarborStyle"
local Widget=require "urhox-libs/UI/Core/Widget"
local NotesView=require "ui.landscape.PotionNotesView"
local Petal=require "ui.landscape.PetalButton"
local R={}
local ink={65,47,32,255}
local function label(parent,id,value,size)
    local node=UI.Label {id=id,text=value,fontFamily=H.fontFamily,fontSize=size or 13,fontColor=ink,
        whiteSpace="normal",lineHeight=1.3,flexShrink=0,pointerEvents="none"}
    parent:AddChild(node);return node
end
local function action(parent,id,value,fn,allowed)
    parent:AddChild(Petal.New {id=id,text=value,width=id=="dismissIngredient" and 80 or 112,disabled=allowed==false,onClick=fn})
end
function R.Render(ctx,b,center,summary,data,editable)
    local l=b.layout;local draft=summary.draft or ctx.model.GetDraft()
    local paper=H.Paper {id="brewRecipePaper",position="absolute",left=l.summary.x,top=l.summary.y,
        width=l.summary.w,height=l.summary.h,compact=true,padding=0}
    center:AddChild(paper)
    local heading=label(paper,"brewSlotsTitle","配方与药槽",14)
    Widget.SetStyle(heading,{position="absolute",left=16,top=3,width=150,height=24})
    paper:AddChild(UI.Button {id="brewRecipeDetails",text="条件与药效 ›",position="absolute",right=10,top=0,
        width=112,height=26,minHeight=26,fontSize=12,fontFamily=H.fontFamily,padding=0,
        backgroundColor={0,0,0,0},textColor=ink,borderWidth=0,
        onClick=function() b.selected=b.selected=="recipe" and false or "recipe";b.notesNumbers=false;ctx.model.dirty=true end})
    local words=ctx.session.queries.GetWordTray();local cards={}
    if words.ok then for _,card in ipairs(words.value.cards) do cards[card.tokenId]=card end end
    local kit=false --[[@as table|false]]
    for _,item in ipairs(ctx.content.equipment) do if item.id==draft.equipmentId then kit=item end end
    local aux=kit and kit.slots.auxWord or 2
    local rows={{id="slot_main",title="主词",kind="word",value=draft.mainTokenId}}
    for i=1,aux do rows[#rows+1]={id="slot_aux_"..i,title="辅词",kind="word",value=draft.auxTokenIds[i]} end
    local ingredients={};local total=0
    for _,line in ipairs(draft.ingredients) do
        for _=1,line.quantity do ingredients[#ingredients+1]=line.ingredientId end
        total=total+line.quantity
    end
    for i=1,(kit and kit.slots.ingredient or 2) do
        rows[#rows+1]={id="slot_ingredient_"..i,title="原料",kind="ingredient",value=ingredients[i]}
    end
    local ingredientById={};for _,item in ipairs(ctx.content.ingredients) do ingredientById[item.id]=item end
    local nextWord=draft.mainTokenId and #draft.auxTokenIds+2 or 1
    for index,row in ipairs(rows) do
        local rect=l.slots[index]
        local item=row.kind=="word" and cards[row.value] or ingredientById[row.value]
        local value=item and (item.text or item.name)
        rect.available=editable and not row.value and (row.kind=="ingredient" or index==nextWord)
        local slot=UI.Panel {id=row.id,position="absolute",left=rect.x-l.summary.x,top=rect.y-l.summary.y,
            width=rect.w,height=rect.h,borderRadius=3,backgroundColor=row.value and {215,192,150,120} or {255,247,225,50},
            alignItems="center",justifyContent="center",onClick=function()
                b.selected=row.value and {kind=row.kind,id=row.value,title=value or row.title} or "recipe";ctx.model.dirty=true
            end}
        paper:AddChild(slot)
        local title=label(slot,nil,row.title,l.compact and 10 or 12);Widget.SetStyle(title,{textAlign="center",lineHeight=l.compact and 1 or 1.3})
        local name=label(slot,nil,value or "＋",l.compact and 11 or 14);Widget.SetStyle(name,{whiteSpace="nowrap",textAlign="center",lineHeight=l.compact and 1.1 or 1.3})
        -- Empty outlines use short strokes; UI still owns all labels and input.
        function slot:Render(vg)
            self:RenderFullBackground(vg)
            local r=self:GetAbsoluteLayout();nvgBeginPath(vg)
            if row.value then nvgRoundedRect(vg,r.x+1,r.y+1,r.w-2,r.h-2,3)
            else
                for x=3,r.w-3,9 do
                    nvgMoveTo(vg,r.x+x,r.y+1);nvgLineTo(vg,r.x+math.min(x+5,r.w-3),r.y+1)
                    nvgMoveTo(vg,r.x+x,r.y+r.h-1);nvgLineTo(vg,r.x+math.min(x+5,r.w-3),r.y+r.h-1)
                end
                for y=3,r.h-3,9 do
                    nvgMoveTo(vg,r.x+1,r.y+y);nvgLineTo(vg,r.x+1,r.y+math.min(y+5,r.h-3))
                    nvgMoveTo(vg,r.x+r.w-1,r.y+y);nvgLineTo(vg,r.x+r.w-1,r.y+math.min(y+5,r.h-3))
                end
            end
            nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(155,117,73,190));nvgStroke(vg)
        end
    end
    local state=not summary.orderId and "先接下委托" or not draft.mainTokenId and "请投入主词" or
        summary.requirementHint.canShip and "已满足炼制条件" or "尚未满足炼制条件"
    if summary.pending then state="结果已保存 · 待处理" end
    if ctx.importantMessage and ctx.importantMessage==ctx.model.message then state=ctx.model.message end
    local capacity=label(paper,"brewCapacity","原料 "..total.."/"..(kit and kit.slots.ingredient or 2).." · "..state,12)
    Widget.SetStyle(capacity,{position="absolute",left=16,right=12,bottom=6,whiteSpace="nowrap"})
    if not b.selected then return end
    if b.selected=="recipe" then NotesView.Render(ctx,b,center,summary,draft);return end
    local detail=H.Paper {id="brewDetail",position="absolute",left=l.center.x,top=math.max(l.wish.y+l.wish.h+4,l.summary.y-170),
        width=l.center.w,height=164,compact=true,padding=12,zIndex=7,onClick=function() end}
    center:AddChild(detail)
    local scroll=UI.ScrollView {id="brewDetailBody",width="100%",height=90,scrollY=true,showScrollbar=true}
    detail:AddChild(scroll)
    local selected=b.selected
    local remove=false --[[@as table|false]]
    do
        local id=type(selected)=="table" and selected.id or selected
        local ingredient=ingredientById[id]
        if ingredient then
            label(scroll,"brewIngredientDescription",ingredient.name.." · "..ingredient.desc)
            local used=0;for _,line in ipairs(draft.ingredients) do if line.ingredientId==id then used=line.quantity end end
            local controls=UI.Panel {flexDirection="row",gap=6,pointerEvents="box-none"};detail:AddChild(controls)
            action(controls,"add_"..id,"投入一份",function() b.Throw("ingredient",id) end,
                editable and (data.live.economy.ingredients[id] or 0)>used)
            if used>0 then remove={kind="ingredient",id=id} end
            if remove then action(controls,"minus_"..id,"取出一份",function() ctx.model.TakeOut("ingredient",id) end,editable) end
            action(controls,"dismissIngredient","收起",function() b.selected=false;ctx.model.dirty=true end)
            return
        elseif type(selected)=="table" then
            local card=cards[id]
            label(scroll,"brewWordDescription",(card and card.text or selected.title).." · 来源："..(card and card.sourceTitle or "词条栏"))
            remove=selected
        end
    end
    local controls=UI.Panel {flexDirection="row",gap=6,pointerEvents="box-none"};detail:AddChild(controls)
    if remove then action(controls,"brewRemoveSlot","撤回词卡",function() ctx.model.TakeOut(remove.kind,remove.id);b.selected=false end,editable) end
    action(controls,"dismissIngredient","收起",function() b.selected=false;ctx.model.dirty=true end)
end
return R
