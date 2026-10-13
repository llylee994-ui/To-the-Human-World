local T = {}
function T.Run()
    local ok, P = pcall(require, "ui.landscape.MessagePresenter")
    assert(ok, "missing MessagePresenter presentation behavior")
    local L = require "ui.landscape.HudLayout"
    local checks = 0
    local function check(value, why) checks = checks + 1; assert(value, why) end
    local raw = "迁移诊断 schema=3 salvage_count=0"
    local p = P.New(raw)
    p:Observe(raw, 10)
    check(p:Current(10).text == "进度已更新。今天先休息吧，明天再去海边。", "migration becomes player wording")
    check(raw == "迁移诊断 schema=3 salvage_count=0", "diagnostic input remains intact")
    p:Observe("已收好", 20)
    p:Observe("已收好", 24)
    check(p:Current(24.99).visible, "ordinary feedback lasts five seconds")
    check(not p:Current(25).visible, "reobserving does not renew feedback")
    p:Observe("已收好", 26, false, true)
    check(p:Current(30.99).visible, "new notification event renews identical feedback")
    p:Observe("已收好", 30, false)
    check(not p:Current(31).visible, "frame observations still do not renew event feedback")
    local eventMessage = P.New(nil)
    eventMessage:Observe("保存失败，请重试。",0,true)
    eventMessage:Observe("保存失败，请重试。",10,false,true)
    check(not eventMessage:Current(10).persistent and eventMessage:Current(10).visible, "new event applies current importance")
    check(not eventMessage:Current(15).visible, "renewed ordinary event expires normally")
    local promotion = P.New(nil)
    promotion:Observe("保存失败，请重试。",0)
    promotion:Observe("保存失败，请重试。",6,true)
    check(promotion:Current(6).visible and promotion:Current(6).persistent, "same message can become important after expiry")
    promotion:Observe("保存失败，请重试。",7,false)
    check(promotion:Current(100).persistent, "ordinary reobserve cannot demote important message")
    local diagnostic = P.New(nil)
    diagnostic:Observe("save_failed",0)
    diagnostic:Observe("save_failed",6,true)
    check(not diagnostic:Current(6).text:find("save_failed",1,true), "importance promotion also sanitizes projection")
    p:Observe("保存失败，请重试。", 30, true)
    check(p:Current(1000).visible and p:Current(1000).persistent, "important feedback persists")
    check(p:Current(1000).text == "保存失败，请重试。", "player-friendly important wording survives")
    p:Observe("ERR_SAVE_IO: transaction_id=123", 1001, true)
    check(not p:Current(1002).text:find("ERR_SAVE_IO", 1, true), "technical errors are not exposed")
    check(p:Current(2000).persistent, "sanitized error stays persistent")
    p:Observe("save_failed", 2000, true)
    check(not p:Current(2000).text:find("save_failed",1,true), "lowercase technical codes are hidden")
    p:Observe("", 2001, true)
    check(not p:Current(2001).visible, "empty message hides")
    p:Observe("新的提示", 2002)
    check(not p:Current(2002).persistent, "changed ordinary message clears persistence")
    p:Observe(nil, 0/0)
    check(not p:Current(math.huge).visible, "malformed message and clock stay safe")
    local b, v = {x=0,y=0,w=1000,h=500}, {w=1000,h=500}
    local capsule = {left=.86,top=0,right=1,bottom=.12}
    local a = L.Compute(b,v,capsule,800)
    check(a.top==0 and a.right==152, "wide HUD reserves capsule width")
    a = L.Compute(b,v,capsule,900)
    check(a.top==68 and a.right==12, "narrow HUD moves below capsule")
    a = L.Compute({x=100,y=30,w=800,h=400},v,capsule,700)
    check(a.top==0 and a.right==52, "offset safe bounds reserve local overlap")
    local cases = {
        false, {left=.86,top=.2,right=1,bottom=.3},
        {left=1.1,top=0,right=1.2,bottom=.1},
        {left=.9,top=0,right=.8,bottom=.1},
        {left=0/0,top=0,right=1,bottom=.1},
        {left=.8,top=0,right=math.huge,bottom=.1},
        {left="bad",top=0,right=1,bottom=.1},
    }
    for _, c in ipairs(cases) do
        a=L.Compute(b,v,c,800)
        check(a.top==0 and a.right==12, "invalid or nonintersecting capsule ignored")
    end
    a=L.Compute(nil,v,capsule,800)
    check(a.top==0 and a.right==12, "malformed bounds are safe")
    a=L.Compute(b,{w=0,h=500},capsule,800)
    check(a.top==0 and a.right==12, "zero viewport ignored")
    a=L.Compute(b,v,nil,800)
    check(a.top==0 and a.right==12, "absent native menu does not reserve space")
    print("HomePresentationTest: " .. checks .. " checks passed")
    return true
end
return T
