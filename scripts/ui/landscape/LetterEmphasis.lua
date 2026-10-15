-- UI-only approved wish annotations; never modify body text, cut sources or saves.
local E={Phrases={
    -- docs/文案/开场与首封来信_定稿_v01.md
    ["letter_pa_01"]="我只希望哪天能安安静静地过一晚上，让我踏踏实实睡觉，第二天起来还有力气干活。",
    -- docs/文案/普通订单/N01_去做抄写员学徒_来信定稿_v01.md
    ["letter_n01"]="明天一早，我必须把脊梁挺起来，清清楚楚地告诉老板：我已经决定走了，我要去做抄写员。",
    -- docs/文案/普通订单/N02_两个人的晚饭_来信定稿_v01.md
    ["letter_n02"]="明晚，我真想把心放宽些。把脸上的愁纹抚平，笑着迎他进门，好好陪他吃一顿安生饭。",
    -- docs/文案/普通订单/N03_一袋胡萝卜的远行_定稿_v01.md
    ["letter_n03"]="我要昂首挺胸地走到蓝围裙叔叔跟前，顺顺利利把萝卜卖掉，再也不要把自己藏在篮子后头躲人了。",
    -- docs/文案/普通订单/N04_钟声过后还有一口甜_定稿_v01.md
    ["letter_n04"]="我真想让自己再高兴一点。也不用太多，只要够我把手里的旗子好好收齐、够我跟皮特在一块儿痛痛快快大笑一场，那就足够了。",
    -- docs/文案/普通订单/N05_花圃比家徽好养_定稿_v01.md
    ["letter_n05"]="我希望明晚能像个真正的客人那样，体体面面地把那顿饭吃完。不再去算那些令人难堪的价钱，也不用在仆人端上菜肴时，强撑着得体的微笑推说自己毫无胃口。",
    -- docs/文案/普通订单/N06_椅子不该跪着迎客_定稿_v01.md
    ["letter_n06"]="今天我就盼着这双手能争点气，一凿一凿稳到底，把这几个榫口利利索索凿完。手里的老凿子啊，也得再听我一句使唤。",
    -- docs/文案/普通订单/N07_把工钱从下次里洗出来_定稿_v01.md
    ["letter_n07"]="我要把这些签了字的收条一张一张拍在他的柜台上，一笔一笔算给他听，把欠我和妹妹的嚼谷全要回来。我绝不再等他嘴里那些虚头巴脑的“下回”。",
    -- docs/文案/普通订单/N08_休假的脚步不用列队_来信定稿_v01.md
    ["letter_n08"]="今天我就想过个真正正正的休假日，把靴子补得严实，热饭吃得干净，再听媳妇坐在对面絮絮叨叨讲些街坊邻里的碎嘴闲事。",
    -- docs/文案/普通订单/N09_花是花，租是租_来信定稿_v01.md
    ["letter_n09"]="谁抄漏的，谁就堂堂正正认下这桩错。要是账房当真漏了字，我自会当面给他赔个不是。",
    -- docs/文案/普通订单/N10_汤可以喝_来信定稿_v01.md
    ["letter_n10"]="交清医药费，再把米洛赶回家歇足半个月眼不见为净，最后上门给客栈和铺子定好交付的日子，哪怕夜里点着灯赶工也绝不失信。",
}}
function E.Segments(view)
    local segments=view.segments or {}
    local phrase=E.Phrases[view.letterId]
    if not phrase then return segments end
    local text={};for _,s in ipairs(segments) do text[#text+1]=s.text end
    local first,last=table.concat(text):find(phrase,1,true)
    if not first then return segments end
    local output,offset={},0
    for _,segment in ipairs(segments) do
        local start,finish=offset+1,offset+#segment.text
        while start<=finish do
            local bold=start>=first and start<=last
            local stop=bold and math.min(finish,last) or (start<first and math.min(finish,first-1) or finish)
            local piece={};for k,v in pairs(segment) do piece[k]=v end
            piece.text=segment.text:sub(start-offset,stop-offset)
            piece.fontWeight=bold and "bold" or "normal"
            output[#output+1]=piece;start=stop+1
        end
        offset=finish
    end
    return output
end
return E
