-- 同内容版本的四处字面修订。只改读取副本中的已知旧词名；原档不覆写，
-- 药效、来源、资源与回信不动，修订后仍须通过完整的存档审计。
local U=require "core.StateUtil"
local M={}
local names={
    word_candidate_n03_e1={old="比我还要快",new="不服气"},
    word_candidate_n04_e1={old="偷偷比了比",new="比了比"},
    word_candidate_n04_s1={old="没见她回来",new="失落"},
    word_candidate_n06_m1={old="手底下先实了",new="稳"},
}
function M.Normalize(data,content)
    if type(data)~="table" or type(content)~="table" or type(content.GetWord)~="function" or data.contentVersion~=content.contentVersion then return data end
    local candidate=U.Copy(data)
    local function rename(id,text)
        local alias=names[id]
        local word=alias and content.GetWord(id)
        if alias and word and word.displayText==alias.new and text==alias.old then return alias.new end
        return text
    end
    local function visit(value)
        if type(value)~="table" then return end
        -- Potion.trace中的词定义，以及journal.recipeDisplay中的词卡快照。
        if value.id and value.displayText then value.displayText=rename(value.id,value.displayText) end
        if value.wordId and value.text then value.text=rename(value.wordId,value.text) end
        for _,child in pairs(value) do if type(child)=="table" then visit(child) end end
    end
    visit(candidate)
    return candidate
end
return M
