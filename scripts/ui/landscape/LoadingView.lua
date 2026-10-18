-- 雾港启动遮罩：纯色兜底、真实进度、资源预热与首帧门禁。
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local V={}
local BACKGROUND="image/loading-r1/harbor-small-v01.jpg"
local CREAM={246,228,193,255}
local GOLD={205,162,91,255}
local MUTED={190,174,146,255}
local DARK={18,28,38,255}

function V.New(loader,onDismissed)
    local root=UI.SafeAreaView {id="loadingRoot",position="absolute",left=0,top=0,width="100%",height="100%",
        backgroundColor=DARK,backgroundImage=BACKGROUND,backgroundFit="cover",
        pointerEvents="auto",onClick=function() end,zIndex=2000}
    root:AddChild(UI.Panel {position="absolute",left=0,top=0,width="100%",height="100%",
        backgroundColor={7,13,20,138},pointerEvents="none"})
    local header=UI.Panel {position="absolute",left="8%",right="8%",top="13%",alignItems="center",
        gap=10,pointerEvents="none"}
    header:AddChild(UI.Label {id="loadingTitle",text="寄往人间",fontFamily="story-strong",fontSize=44,
        fontColor=CREAM,textAlign="center",letterSpacing=2,lineHeight=1.2,pointerEvents="none"})
    header:AddChild(UI.Label {id="loadingSubtitle",text="TO THE HUMAN WORLD",fontFamily="story",fontSize=12,
        fontColor=MUTED,textAlign="center",letterSpacing=3,lineHeight=1.2,pointerEvents="none"})
    root:AddChild(header)
    local footer=UI.Panel {position="absolute",left="12%",right="12%",bottom="12%",alignItems="center",
        gap=8,pointerEvents="box-none"}
    local status=UI.Label {id="loadingStatus",text="正在准备药铺……",fontFamily="story",fontSize=18,
        fontColor=CREAM,textAlign="center",whiteSpace="normal",lineHeight=1.4,pointerEvents="none"}
    local first=UI.Label {id="loadingFirst",text="首次抵达，需要多等一会儿。",fontFamily="story",fontSize=13,
        fontColor=MUTED,textAlign="center",visible=false,lineHeight=1.4,pointerEvents="none"}
    local slow=UI.Label {id="loadingSlow",text="准备时间比平时久，可以继续等待或重试。",fontFamily="story",fontSize=13,
        fontColor=MUTED,textAlign="center",visible=false,whiteSpace="normal",lineHeight=1.4,pointerEvents="none"}
    footer:AddChild(status);footer:AddChild(first);footer:AddChild(slow)
    local barHost=UI.Panel {id="loadingBar",width="62%",height=10,marginTop=4,pointerEvents="none"}
    footer:AddChild(barHost)
    local percent=UI.Label {id="loadingPercent",text="0%",fontFamily="story",fontSize=13,
        fontColor=MUTED,textAlign="center",lineHeight=1.2,pointerEvents="none"}
    footer:AddChild(percent)
    local retry=UI.Button {id="loadingRetry",text="重新加载",visible=false,minHeight=44,fontSize=15,
        fontFamily="story",backgroundColor={174,129,65,255},textColor={30,26,19,255},borderRadius=6,
        onClick=function() if loader.Retry() then end end}
    footer:AddChild(retry)
    root:AddChild(footer)

    local function markLayoutDirty() if UI.MarkLayoutDirty then UI.MarkLayoutDirty() end end
    local function layoutDirty() return UI.IsLayoutDirty and UI.IsLayoutDirty() or false end
    local active=false
    local activeGroup=nil
    local targetReadyCallback=nil
    local resourceReady=false
    local prepared=false
    local fading=false
    local alpha=1
    local targetRendered=0
    local targetUpdated=0
    local view={root=root}
    local lastShort=nil
    local function reflow()
        local height=720
        if UI.GetViewportSize then local _,h=UI.GetViewportSize();height=h end
        local short=height<520
        if short==lastShort then return end
        lastShort=short
        header:SetStyle({top=short and "6%" or "13%",gap=short and 4 or 10})
        header:FindById("loadingTitle"):SetStyle({fontSize=short and 28 or 44})
        footer:SetStyle({bottom=short and "6%" or "12%",gap=short and 4 or 8})
    end

    local function setAlpha(value)
        alpha=math.max(0,math.min(1,value))
        if root.SetStyle then Widget.SetStyle(root,{opacity=alpha}) end
    end
    local function finish()
        active=false;fading=false;root:SetVisible(false);setAlpha(1)
        if onDismissed then onDismissed() end
    end
    function view:Show(group,targetReady)
        active=true;activeGroup=group;targetReadyCallback=targetReady;resourceReady=false;prepared=false;fading=false;targetRendered=0;targetUpdated=0
        setAlpha(1);root:SetVisible(true)
        status:SetText("正在准备药铺……");first:SetVisible(false);slow:SetVisible(false);retry:SetVisible(false);percent:SetText("0%")
        loader.Begin(group,function() resourceReady=true end)
    end
    function view.IsActive() return active end
    function view:Update(dt)
        reflow()
        loader.Update(dt)
        if not active then return end
        local s=loader.GetStatus()
        if s.state=="failed" then
            status:SetText("有些资源没能准备好，请重试。")
            retry:SetVisible(true)
        elseif s.state=="downloading" then
            status:SetText("正在准备药铺……");retry:SetVisible(false)
        elseif s.state=="loading" or s.state=="warming" then
            status:SetText("正在整理画面……");retry:SetVisible(false)
        elseif s.state=="ready" then
            status:SetText("准备完成。");retry:SetVisible(false)
        end
        first:SetVisible(s.needsDownload and s.state~="ready")
        slow:SetVisible(s.slow and s.state~="ready")
        if s.state~="ready" and s.totalBytes==0 and (s.total or 0)>0 then percent:SetText(string.format("已准备 %d / %d 项",s.done or 0,s.total))
        else
            local pct=math.min(98,math.floor((s.progress or 0)*100+0.5))
            if s.state=="ready" and prepared and targetRendered>0 and not layoutDirty() then pct=100 end
            percent:SetText(string.format("%d%%",pct))
        end
        if resourceReady and not prepared then
            prepared=true;targetUpdated=0;markLayoutDirty()
            if targetReadyCallback then targetReadyCallback() end
        end
        if prepared and not fading then
            targetUpdated=targetUpdated+1
            if targetUpdated>=1 and targetRendered>=1 and not layoutDirty() and activeGroup and loader.IsReady(activeGroup) then
                fading=true
            end
        end
        if fading then
            setAlpha(alpha-math.max(0,dt or 0)/0.25)
            if alpha<=0 then finish() end
        end
    end
    function barHost:Render(vg)
        local r=self:GetAbsoluteLayout()
        if r.w<=0 or r.h<=0 then return end
        nvgBeginPath(vg);nvgRoundedRect(vg,r.x,r.y,r.w,r.h,r.h/2)
        nvgFillColor(vg,nvgRGBA(226,205,165,50));nvgFill(vg)
        local s=loader.GetStatus()
        local p=math.max(0,math.min(1,s.progress or 0))
        if prepared and targetRendered>0 and not layoutDirty() and s.state=="ready" then p=1 end
        local fill=r.w*p
        if fill>0 then
            nvgBeginPath(vg);nvgRoundedRect(vg,r.x,r.y,fill,r.h,r.h/2)
            nvgFillColor(vg,nvgRGBA(GOLD[1],GOLD[2],GOLD[3],235));nvgFill(vg)
        end
        for i=1,3 do
            local x=r.x+r.w*(0.28+0.22*(i-1))
            nvgSave(vg);nvgTranslate(vg,x,r.y+r.h/2);nvgRotate(vg,math.pi/4)
            nvgBeginPath(vg);nvgRect(vg,-3,-3,6,6)
            nvgFillColor(vg,nvgRGBA(GOLD[1],GOLD[2],GOLD[3],p*220+20));nvgFill(vg);nvgRestore(vg)
        end
        loader.WarmFrame(vg)
        view:MarkRendered()
    end
    function view:MarkRendered()
        if prepared and not fading and targetRendered<1 then targetRendered=targetRendered+1 end
    end
    function view.Hide()
        if not active then return end
        active=false;fading=false;root:SetVisible(false);setAlpha(1)
        loader.Cancel()
    end
    function view.Destroy()
        active=false
        loader.Cancel()
        root:Destroy()
    end
    return view
end
return V
