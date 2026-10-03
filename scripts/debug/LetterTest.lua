local U = require "core.StateUtil"
local F = require "debug.fixtures.B2Fixtures"
local Tests = {}
function Tests.Run(check)
    local finish
    if not check then check,finish = require("debug.fixtures.B2Check").New() end
    local Data = require "data.content"
    assert(Data.Load())
    local letter = require("systems.Letter").New(Data)
    local definition = Data.letters[1]
    local original = U.Copy(Data.letters)
    local initial = letter.InitialSnapshot().value
    local received = letter.PlanReceive(initial,definition.id)
    check("T1 receive",received.ok,true)
    assert(received.ok and letter.Restore(received.value.state).ok)
    local id = received.value.instanceId
    local view = letter.GetView(id).value
    check("T1 selfIntro",view.selfIntro,definition.selfIntro)
    check("T1 address",view.address,definition.address)
    check("T1 six spans",#view.spans,6)
    local plain = definition.body:gsub("{{(.-)}}","%1")
    local reconstructed = ""
    for _, segment in ipairs(view.segments) do reconstructed = reconstructed .. segment.text end
    check("T1 UTF8/newlines",reconstructed,plain)
    local n = 0
    for text in definition.body:gmatch("{{(.-)}}") do
        n=n+1; check("T1 stable position " .. n,view.spans[n].spanId,"body:" .. n)
        check("T1 word " .. n,view.spans[n].wordId,assert(Data.GetWordByText(text)).id)
    end
    check("T3 receive input unchanged",next(initial.byId)==nil,true)
    local repeated = letter.PlanReceive(received.value.state,definition.id)
    check("T3 repeat unchanged",not repeated.value.changed and U.Equal(repeated.value.state,received.value.state),true)
    check("T3 queue once",#repeated.value.state.bottleQueue,1)
    check("T4 view not read",letter.GetSnapshot().byId[id].read,false)
    check("T6 unread cut",letter.PlanMarkCut(received.value.state,id,"body:1").error.code,"LETTER_NOT_READ")
    local read = letter.PlanMarkRead(received.value.state,id)
    check("T4 read candidate",read.value.changed and read.value.state.byId[id].read,true)
    check("T4 read input unchanged",received.value.state.byId[id].read,false)
    check("T4 repeat read",letter.PlanMarkRead(read.value.state,id).value.changed,false)
    check("T6 missing receive",letter.PlanMarkRead(initial,id).ok,false)
    check("T6 unknown letter",letter.PlanReceive(initial,"unknown").ok,false)
    check("T6 unknown span",letter.PlanMarkCut(read.value.state,id,"body:99").ok,false)
    check("T11 direct receive",letter.PlanReceive(initial,Data.letters[2].id).ok,false)
    check("T11 parse direct",letter.ParseDefinition(Data.letters[2].id).ok,true)
    local cut = letter.PlanMarkCut(read.value.state,id,"body:1")
    check("T5 cut source",cut.value.source.wordId,view.spans[1].wordId)
    assert(letter.Restore(cut.value.state).ok)
    local again = letter.GetView(id).value
    check("T7 gap",again.spans[1].cut,true)
    check("T7 stable other span",again.spans[2].spanId,"body:2")
    check("T7 repeat cut",letter.PlanMarkCut(cut.value.state,id,"body:1").value.changed,false)
    again.spans[1].text="mutation"; again.selfIntro="mutation"
    local snap = letter.GetSnapshot(); snap.byId[id].read=false
    local restored = letter.Restore(cut.value.state); restored.value.byId[id].read=false
    check("T8 public copies",letter.GetSnapshot().byId[id].read and letter.GetView(id).value.selfIntro==definition.selfIntro,true)
    local bad = U.Copy(cut.value.state); bad.byId[id].cutSpans["body:99"]=true
    check("T9 invalid restore",letter.Restore(bad).ok,false)
    check("T9 state preserved",U.Equal(letter.GetSnapshot(),cut.value.state),true)
    check("T8 Data unchanged",U.Equal(original,Data.letters),true)
    local content = F.Content()
    local technical = U.Copy(content.letters[1]); technical.id="b2_repeat"; technical.body="中文\n{{"..content.words[1].displayText.."}}与{{"..content.words[1].displayText.."}}。"
    content.letters[#content.letters+1]=technical
    local other = require("systems.Letter").New(content)
    local r = other.PlanReceive(other.InitialSnapshot().value,technical.id)
    local rr = other.PlanMarkRead(r.value.state,r.value.instanceId)
    local cc = other.PlanMarkCut(rr.value.state,r.value.instanceId,"body:1")
    assert(other.Restore(cc.value.state).ok)
    check("T2 duplicate text independent",other.GetView(r.value.instanceId).value.spans[2].cut,false)
    for _, body in ipairs({"{{}}","{{unknown}}","{{未闭合","}}","{{{{词}}"}) do
        technical.body=body
        check("T1 malformed body " .. body,other.ParseDefinition(technical.id).ok,false)
    end
    technical.body=42
    check("T1 invalid body type",other.ParseDefinition(technical.id).ok,false)
    return finish and finish() or true
end
return Tests
