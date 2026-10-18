local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local Harbor=require "ui.landscape.HarborStyle"
local V={}
local ink={65,46,28,255}
local function label(text,id,size)
    return UI.Label {id=id,text=text,fontFamily=Harbor.fontFamily,fontSize=size or 18,
        fontColor=ink,whiteSpace="normal",flexShrink=0,pointerEvents="none"}
end
local function musicIcon()
    local icon=UI.Panel {id="musicSettingsIcon",width=36,height=40,flexShrink=0,pointerEvents="none"}
    -- Draw the note directly; it remains visible even if the story font lacks ♫.
    function icon:Render(vg)
        local r=self:GetAbsoluteLayout()
        nvgSave(vg);nvgTranslate(vg,r.x,r.y);nvgScale(vg,r.w/36,r.h/40)
        nvgBeginPath(vg);nvgEllipse(vg,9,31,6,4);nvgEllipse(vg,26,27,6,4)
        nvgFillColor(vg,nvgRGBA(91,66,39,255));nvgFill(vg)
        nvgBeginPath(vg);nvgRect(vg,12,10,3,21);nvgRect(vg,29,5,3,22);nvgFill(vg)
        nvgBeginPath(vg);nvgMoveTo(vg,12,10);nvgLineTo(vg,32,4)
        nvgLineTo(vg,32,10);nvgLineTo(vg,12,16);nvgClosePath(vg);nvgFill(vg)
        nvgRestore(vg)
    end
    return icon
end

local function soundIcon()
    local icon=UI.Panel {id="soundSettingsIcon",width=28,height=28,flexShrink=0,pointerEvents="none"}
    function icon:Render(vg)
        local r=self:GetAbsoluteLayout()
        nvgSave(vg);nvgTranslate(vg,r.x,r.y);nvgScale(vg,r.w/28,r.h/28)
        nvgFillColor(vg,nvgRGBA(91,66,39,255))
        nvgBeginPath(vg);nvgRect(vg,1,10,6,8)
        nvgMoveTo(vg,7,10);nvgLineTo(vg,14,4);nvgLineTo(vg,14,24);nvgLineTo(vg,7,18)
        nvgClosePath(vg);nvgFill(vg)
        for _,x in ipairs({17,23}) do
            nvgBeginPath(vg);nvgMoveTo(vg,x,7);nvgLineTo(vg,x+4,14);nvgLineTo(vg,x,21)
            nvgLineTo(vg,x-1,18);nvgLineTo(vg,x+1,14);nvgLineTo(vg,x-1,10)
            nvgClosePath(vg);nvgFill(vg)
        end
        nvgRestore(vg)
    end
    return icon
end

function V.New(preferences,onChange,soundPreferences,onSoundChange)
    local view={}
    local closing=false
    local initial=preferences.Get()
    local root=UI.Panel {id="musicSettingsOverlay",position="absolute",left=0,top=0,width="100%",height="100%",
        visible=false,zIndex=200,backgroundColor={18,24,20,190},alignItems="center",justifyContent="center",
        padding=20,onClick=function() end}
    view.root=root
    local paper=Harbor.Paper {id="musicSettingsPanel",width="100%",maxWidth=520,maxHeight="100%",
        padding=32,gap=18,overflow="hidden",onClick=function() end}
    root:AddChild(paper)
    local header=UI.Panel {width="100%",flexDirection="row",alignItems="center",gap=12,flexShrink=0,pointerEvents="box-none"}
    header:AddChild(musicIcon())
    local title=label("声音设置","musicSettingsTitle",24);Widget.SetStyle(title,{flexGrow=1,minWidth=0,whiteSpace="nowrap"})
    header:AddChild(title)
    header:AddChild(Harbor.Button {id="closeMusicSettings",text="关闭",width=76,minHeight=44,onClick=function() closing=true end})
    paper:AddChild(header)
    local scroll=UI.ScrollView {width="100%",flexShrink=1,minHeight=0,scrollY=true,showScrollbar=true}
    local body=UI.Panel {width="100%",gap=12,paddingRight=8,flexShrink=0,pointerEvents="box-none"}
    scroll:AddChild(body);paper:AddChild(scroll)
    local musicRow=UI.Panel {width="100%",minHeight=44,flexDirection="row",alignItems="center",gap=12,pointerEvents="box-none"}
    local enabledLabel=label("背景音乐","musicEnabledLabel")
    Widget.SetStyle(enabledLabel,{flexGrow=1,minWidth=0,whiteSpace="nowrap"})
    musicRow:AddChild(enabledLabel);body:AddChild(musicRow)
    local hint=label("调整即时生效，下次打开时保留。","musicSettingsHint",14)
    local percent=label(initial.volume.."%","musicVolumeValue")
    Widget.SetStyle(percent,{width=72,whiteSpace="nowrap",textAlign="right"})
    local function save()
        local ok=preferences.Save()
        -- Attempt both saves even if one fails; neither preference replaces the other.
        if soundPreferences then local soundOk=soundPreferences.Save();ok=ok and soundOk end
        hint:SetText(ok and "调整即时生效，下次打开时保留。" or "本次调整已生效，但未能保存，请稍后再试。")
        return ok
    end
    musicRow:AddChild(UI.Toggle {id="musicEnabled",value=initial.enabled,label=initial.enabled and "开启" or "关闭",
        width=124,height=44,trackWidth=52,trackHeight=28,thumbSize=22,fontFamily=Harbor.fontFamily,fontSize=16,
        trackBg={177,161,135,255},trackHoverBgColor={190,174,148,255},trackBorderColor={133,111,80,255},
        trackCheckedBgColor={91,104,77,255},trackCheckedHoverBgColor={108,122,92,255},
        thumbColor={255,244,218,255},thumbCheckedColor={255,244,218,255},
        onChange=function(control,value)
            preferences.SetEnabled(value);control:SetLabel(value and "开启" or "关闭")
            onChange(preferences.Get());save()
        end})
    local volumeRow=UI.Panel {width="100%",minHeight=32,flexDirection="row",alignItems="center",gap=12,pointerEvents="box-none"}
    local volumeLabel=label("音乐音量","musicVolumeLabel")
    Widget.SetStyle(volumeLabel,{flexGrow=1,minWidth=0,whiteSpace="nowrap"})
    volumeRow:AddChild(volumeLabel);volumeRow:AddChild(percent);body:AddChild(volumeRow)
    body:AddChild(UI.Slider {id="musicVolume",width="100%",height=44,min=0,max=100,step=1,value=initial.volume,
        trackHeight=6,thumbSize=24,trackBgColor={190,171,140,255},trackFillColor={111,86,54,255},
        thumbColor={255,244,218,255},thumbBorderColor={126,96,61,255},thumbBoxShadow=false,
        onChange=function(_,value)
            preferences.SetVolume(value)
            local state=preferences.Get();percent:SetText(state.volume.."%");onChange(state)
        end,onChangeEnd=function() save() end})
    if soundPreferences then
        local soundInitial=soundPreferences.Get()
        body:AddChild(UI.Panel {width="100%",height=1,flexShrink=0,backgroundColor={165,141,105,120},pointerEvents="none"})
        local soundRow=UI.Panel {width="100%",minHeight=44,flexDirection="row",alignItems="center",gap=12,pointerEvents="box-none"}
        soundRow:AddChild(soundIcon())
        local soundLabel=label("物件音效","soundEnabledLabel")
        Widget.SetStyle(soundLabel,{flexGrow=1,minWidth=0,whiteSpace="nowrap"})
        soundRow:AddChild(soundLabel);body:AddChild(soundRow)
        soundRow:AddChild(UI.Toggle {id="soundEnabled",value=soundInitial.enabled,label=soundInitial.enabled and "开启" or "关闭",
            width=124,height=44,trackWidth=52,trackHeight=28,thumbSize=22,fontFamily=Harbor.fontFamily,fontSize=16,
            trackBg={177,161,135,255},trackHoverBgColor={190,174,148,255},trackBorderColor={133,111,80,255},
            trackCheckedBgColor={91,104,77,255},trackCheckedHoverBgColor={108,122,92,255},
            thumbColor={255,244,218,255},thumbCheckedColor={255,244,218,255},
            onChange=function(control,value)
                soundPreferences.SetEnabled(value);control:SetLabel(value and "开启" or "关闭")
                onSoundChange(soundPreferences.Get());save()
            end})
        local soundVolumeRow=UI.Panel {width="100%",minHeight=32,flexDirection="row",alignItems="center",gap=12,pointerEvents="box-none"}
        local soundVolumeLabel=label("音效音量","soundVolumeLabel")
        Widget.SetStyle(soundVolumeLabel,{flexGrow=1,minWidth=0,whiteSpace="nowrap"})
        local soundPercent=label(soundInitial.volume.."%","soundVolumeValue")
        Widget.SetStyle(soundPercent,{width=72,whiteSpace="nowrap",textAlign="right"})
        soundVolumeRow:AddChild(soundVolumeLabel);soundVolumeRow:AddChild(soundPercent);body:AddChild(soundVolumeRow)
        body:AddChild(UI.Slider {id="soundVolume",width="100%",height=44,min=0,max=100,step=1,value=soundInitial.volume,
            trackHeight=6,thumbSize=24,trackBgColor={190,171,140,255},trackFillColor={111,86,54,255},
            thumbColor={255,244,218,255},thumbBorderColor={126,96,61,255},thumbBoxShadow=false,
            onChange=function(_,value)
                soundPreferences.SetVolume(value)
                local state=soundPreferences.Get();soundPercent:SetText(state.volume.."%");onSoundChange(state)
            end,onChangeEnd=function() save() end})
    end
    body:AddChild(hint)

    local helpButton=nil
    function view.SetHelp(callback)
        if helpButton or type(callback)~="function" then return end
        helpButton=Harbor.Button {id="openOnboardingNote",text="回顾新手便签",width="100%",minHeight=44,fontSize=16,
            onClick=callback}
        body:AddChild(helpButton)
    end
    function view.Open() closing=false;root:SetVisible(true) end
    function view.IsOpen() return root.props.visible==true end
    function view.Update()
        -- Keep the blocker alive through pointer-up, like the existing panels.
        if closing then save();closing=false;root:SetVisible(false) end
    end
    function view.SetInsets(safe,viewport,menu)
        -- Place the whole dialog below a host menu if necessary, including close.
        local top=safe.top+20
        if menu then top=math.max(top,menu.bottom*viewport.h+12) end
        local values={paddingTop=top,paddingLeft=safe.left+20,paddingRight=safe.right+20,paddingBottom=safe.bottom+20}
        for key,value in pairs(values) do
            if root.props[key]~=value then Widget.SetStyle(root,values);break end
        end
    end
    function view.Save() return save() end
    return view
end
return V
