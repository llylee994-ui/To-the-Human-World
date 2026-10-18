-- The commission slip and its fixed action belong to the reader, outside the prose.
local UI=require "urhox-libs/UI"
local H=require "ui.landscape.HarborStyle"
local Style=require "ui.landscape.StoryStyle"
local R={}
local function label(parent,value,size,id,color,props)
    local p={id=id,text=value,fontFamily=H.fontFamily,fontSize=size,lineHeight=1.35,
        whiteSpace="normal",flexShrink=0,fontColor=color or {87,68,46,255},pointerEvents="none"}
    for k,v in pairs(props or {}) do p[k]=v end
    local l=UI.Label(p)
    parent:AddChild(l);return l
end
function R.Summary(body,view,definition)
    local slip=UI.Panel {id="readerOrderSummary",width="100%",marginTop=16,marginBottom=8,padding={16,22},gap=8,
        borderTopWidth=1,borderBottomWidth=1,borderColor={161,128,79,130},backgroundColor={205,188,151,52},pointerEvents="none"}
    body:AddChild(slip)
    label(slip,"委 托 笺",12,"readerSummaryTitle",{145,106,58,255})
    local row=UI.Panel {width="100%",minHeight=32,flexDirection="row",gap=22,pointerEvents="none"};slip:AddChild(row)
    label(row,"寄往："..(view.address or ""),15,"readerAddress",nil,{flexGrow=1,flexShrink=1,flexBasis=0,minWidth=0})
    if definition.reward then
        label(row,"报酬  ·  "..definition.reward.currency.." 金币",15,"readerReward",{141,98,43,255},
            {width=208,height=32,whiteSpace="nowrap",textAlign="right",verticalAlign="middle"})
    end
    if definition.requirement then label(slip,"委托要求："..definition.requirement.desc,16,"readerRequirement") end
    if #(view.spans or {})>0 then label(slip,"点信中发光的词语剪下收取。",13,"readerCutHint",{126,111,87,255}) end
end
function R.Action(body,id,title,callback,allowed,reason)
    local footer=UI.Panel {id="readerActions",position="absolute",left=0,right=0,bottom=12,
        zIndex=30,gap=6,alignItems="center",pointerEvents="box-none"}
    body.parent.parent:AddChild(footer)
    if allowed==false and reason and reason~="" then label(footer,reason,12,"readerActionReason") end
    footer:AddChild(Style.Button {id=id,text=title,width=340,maxWidth="88%",minWidth=0,height=52,minHeight=52,
        alignSelf="center",fontSize=17,disabled=allowed==false,onClick=callback})
end
return R
