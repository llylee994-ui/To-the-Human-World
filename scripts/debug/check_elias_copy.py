"""Approved Elias prose versus real Lua parsing/rendering; no engine/UI claim."""
from pathlib import Path
import json
import re
import sys
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp' / 'b1-python'))
from lupa.lua54 import LuaRuntime, lua_type


class EliasCopy(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        def plain(value):
            if lua_type(value) != 'table':
                return value
            keys = list(value.keys())
            if keys and set(keys) == set(range(1, len(keys) + 1)):
                return [plain(value[i]) for i in range(1, len(keys) + 1)]
            return {str(k): plain(value[k]) for k in keys}
        self.lua.globals().cjson = self.lua.table_from({
            'encode': lambda value: json.dumps(plain(value), ensure_ascii=False),
            'decode': lambda text: self.lua.table_from(json.loads(text), recursive=True),
        })
        self.lua.execute("package.path = ... .. '/scripts/?.lua;' .. package.path", ROOT.as_posix())
        self.lua.execute('assert(require("data.content").Load()); assert(require("data.content").ValidateStage1())')

    def test_letter_matches_approved_document_and_six_original_sources(self):
        doc = (ROOT / 'docs/文案/开场与首封来信_定稿_v01.md').read_text(encoding='utf-8')
        text = doc.split('## 首封来信正文\n\n', 1)[1].split('\n## 定稿与交接边界', 1)[0].strip()
        self.assertEqual(re.findall(r'\*\*(.*?)\*\*', text), [
            '我只希望哪天能安安静静地过一晚上，让我踏踏实实睡觉，第二天起来还有力气干活。'
        ])
        actual, spans = self.lua.execute('''
            local d=require "data.content"
            local parsed=require("systems.Letter").New(d).ParseDefinition("letter_pa_01")
            assert(parsed.ok)
            local v=parsed.value
            local text={}
            for _, segment in ipairs(v.segments) do text[#text+1]=segment.text end
            return v.selfIntro .. "\\n\\n" .. table.concat(text) .. "\\n\\n" .. v.address,v.spans
        ''')
        self.assertEqual(actual, text.replace('**', ''))
        words = ['word_tired', 'word_smile', 'word_forget', 'word_dream', 'word_quiet', 'word_sleep']
        self.assertEqual(len(spans), 6)
        for i, word_id in enumerate(words, 1):
            self.assertEqual(spans[i].spanId, f'body:{i}')
            self.assertEqual(spans[i].wordId, word_id)
        self.assertIn('安安静静地过一晚上', actual)
        self.assertIsNone(self.lua.eval('require("data.content").GetWordByText("忘掉")'))
        self.assertIsNone(self.lua.eval('require("data.content").GetWordByText("困")'))

    def test_seven_full_letters_use_real_rules_and_renderer(self):
        doc = (ROOT / 'docs/文案/普通订单/首单_埃利亚斯_后续定稿_v01.md').read_text(encoding='utf-8')
        body = doc.split('## 作者区：', 1)[0]
        sections = [s.strip() for s in re.split(r'^## [一二三四五六七]｜[^\n]+\n', body, flags=re.M)[1:]]
        self.assertEqual(len(sections), 7)
        inputs = [{}, {'dream': .6}, {'forget': .6}, {'dream': .6, 'forget': .6},
                  {'dream': .6, 'happy': .6}, {'dream': .6, 'reason': .6}, {'dream': .4}]
        ids = ['sleep_only', 'dream_mother', 'forget_song', 'dream_unclear',
               'fish_choir', 'dream_ledger', 'restless_dreams']
        for i, effects in enumerate(inputs):
            with self.subTest(branch=i + 1):
                result = self.lua.execute('''
                    local effects=...
                    local F=require "debug.fixtures.B4Fixtures"
                    local c=F.Content()
                    -- Isolated effect vectors exercise narrative, not inventory reachability.
                    effects.sleep=1
                    F.ById(c.words,"word_sleep").effects=effects
                    return F.Setup(c).Joint("A")
                ''', self.lua.table_from(effects))[0]
                self.assertEqual(result.followup.renderedText, sections[i])
                self.assertEqual(list(result.followup.fragmentIds.values()), ['frag_pa_' + ids[i]])
                self.assertEqual(result.rating.stars, [3, 3, 2, 1, 3, 3, 3][i])
                self.assertNotIn('店主', result.followup.renderedText)
                self.assertNotIn('{{', result.followup.renderedText)
        self.assertIn('帮我把最小的那只箱子', sections[5])
        for section in sections:
            for paragraph in section.split('\n\n'):
                self.assertEqual(paragraph[-1], '。')
        self.assertFalse(self.lua.eval('require("data.content").GetLetter("letter_pa_01_followup").cuttable'))

    def test_old_pending_and_confirmed_letters_survive_reload_without_rewriting(self):
        for sample in ['A', 'B', 'C', 'D', 'G2']:
            for confirmed in [False, True]:
                with self.subTest(sample=sample, confirmed=confirmed):
                    self.lua.execute('''
                        local sample,confirmed=...
                        local U=require "core.StateUtil"
                        local F=require "debug.fixtures.B4Fixtures"
                        local c=F.Content()
                        local template=F.ById(c.followupTemplates,"tpl_pa_01")
                        local currentTemplate=U.Copy(template)
                        local currentFragments=U.Copy(c.fragments)
                        local history=template.legacy
                        template.opening=history.opening; template.closing=history.closing
                        template.baseFragmentIds=U.Copy(history.baseFragmentIds)
                        template.fallbackFragmentIds={"frag_pa_generic"}
                        for id,old in pairs(history.fragments) do
                            local frag=F.ById(c.fragments,id)
                            frag.text=old.text; frag.bindings=U.Copy(old.bindings)
                        end
                        local x=require("debug.fixtures.B5Fixtures").New(c)
                        x.Prepare(); x.Pending(sample)
                        if confirmed then F.Must(x.Confirm()) end
                        local saved=x.state.GetSnapshot()
                        local record=confirmed and saved.live.orders.confirmedById[x.orderId] or saved.currentOrder.pending
                        local oldText=record.followup.renderedText
                        assert(oldText:find("店主",1,true))
                        -- Switch only the content definitions; the isolated saved bytes stay intact.
                        for k in pairs(template) do template[k]=nil end
                        for k,v in pairs(currentTemplate) do template[k]=v end
                        c.fragments=currentFragments
                        assert(x.Reload())
                        assert(U.Equal(saved,x.state.GetSnapshot()),"legacy snapshot was rewritten or lost")
                        local bad=U.Copy(saved)
                        local target=confirmed and bad.live.orders.confirmedById[x.orderId] or bad.currentOrder.pending
                        target.followup.renderedText=oldText .. "伪造"
                        if confirmed then
                            bad.live.letters.directArchive[x.orderId].renderedText=target.followup.renderedText
                        else
                            target.candidateLive.orders.confirmedById[x.orderId].followup.renderedText=target.followup.renderedText
                            target.candidateLive.letters.directArchive[x.orderId].renderedText=target.followup.renderedText
                        end
                        local rejected=x.order.ValidateEnvelope(bad)
                        assert(not rejected.ok and rejected.error.code=="STATE_INVALID"
                            and (rejected.error.path=="followup.renderedText" or rejected.error.path=="followup.bindings"),
                            "legacy audit failed to reject tampered text/bindings")
                    ''', sample, confirmed)


if __name__ == '__main__':
    unittest.main()
