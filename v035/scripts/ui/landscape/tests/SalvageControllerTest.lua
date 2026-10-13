local available,S=pcall(require,'ui.landscape.SalvageController')
local T={}
function T.Run()
    assert(available,'SalvageController must provide the animation lifecycle')
    local checks=0
    local function check(ok,msg) checks=checks+1;assert(ok,msg) end
    local fit={x=0,y=0,w=1920,h=1080,scale=1}
    local function fresh() local s=S.New();check(s.Begin('letter-a',fit,0),'begin');return s end
    local s=S.New()
    check(not s.Begin('',fit,0),'empty id rejected')
    check(not s.Begin('a',{scale=0},0),'zero fit rejected')
    check(s.Begin('letter-a',fit,0),'valid start')
    check(not s.Begin('letter-b',fit,0),'duplicate start rejected')
    check(not s.Acknowledge('letter-a'),'active cannot acknowledge')
    local completions=0
    for i=1,150 do if s.Update(.02,fit,true,i*.02)=='complete' then completions=completions+1 end end
    check(completions==1,'exactly one completion')
    check(s.letterInstanceId=='letter-a','completion keeps id')
    check(not s.Begin('letter-b',fit,3),'pending letter prevents replacement')
    check(not s.Acknowledge('letter-b'),'wrong id cannot acknowledge')
    check(s.Acknowledge('letter-a') and s.letterInstanceId==false,'acknowledgement clears id')
    check(s.Pose().phase=='idle','acknowledged idle')
    for _,case in ipairs({{dt=.02,focused=false,now=.02,fit=fit},{dt=.3,focused=true,now=.3,fit=fit},
        {dt=.02,focused=true,now=.3,fit=fit},{dt=-1,focused=true,now=.02,fit=fit},
        {dt=0/0,focused=true,now=.02,fit=fit},{dt=.02,focused=true,now=.02,fit={x=1,y=0,w=1920,h=1080,scale=1}},
        {dt=.02,focused=true,now=.02,fit={x=0,y=0,w=0,h=0,scale=0}}}) do
        s=fresh()
        check(s.Update(case.dt,case.fit,case.focused,case.now)=='interrupted','interruption reported')
        check(not s.active and s.letterInstanceId=='letter-a','interruption preserves id')
        check(s.Update(.02,fit,true,.04)==nil,'interruption once')
        check(s.Pose().phase=='received','interrupted received pose')
    end
    s=fresh();check(s.Skip()=='complete','skip completes');check(s.Skip()==nil,'skip once')
    check(s.letterInstanceId=='letter-a','skip preserves id')
    s=fresh();s.Cancel('leave');check(not s.active and s.letterInstanceId=='letter-a','cancel preserves id')
    s=fresh()
    local previous=s.Pose()
    for i=1,240 do
        s.Update(.01,fit,true,i*.01)
        local p=s.Pose()
        for _,key in ipairs({'netOpacity','netX','netY','netAngle','bottleX','bottleY','bottleScale','bottleOpacity','splash'}) do
            check(type(p[key])=='number' and p[key]==p[key] and math.abs(p[key])<10000,'finite '..key)
        end
        check(math.abs(p.bottleX-previous.bottleX)<20 and math.abs(p.bottleY-previous.bottleY)<20,'continuous bottle position')
        check(math.abs(p.netX-previous.netX)<30 and math.abs(p.netY-previous.netY)<30,'continuous net position')
        check(p.splash>=0 and p.splash<=1 and p.netOpacity>=0 and p.netOpacity<=1,'bounded visual values')
        previous=p
    end
    check(previous.phase=='received' and previous.netOpacity==0,'final received pose')
    print('SalvageController: '..checks..' checks passed')
    return true
end
return T
