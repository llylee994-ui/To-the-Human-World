#!/usr/bin/env python3
"""T5 pure-content model; no game import, runtime writes, or remote build.

Run: python docs/验证/check_delivery_budget.py [--json] [--ledger]
Reads actual Lua literals for money, inventory, prices, slots, words and profiles.
Schedule, single-use word cards, future supply and rewards are proposed content.
This is arithmetic evidence, not a Potion/Order/Identity integration test.
"""
from __future__ import annotations

import argparse
import itertools
import json
import re
from collections import Counter
from dataclasses import dataclass, replace
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "scripts" / "data"


class LiteralReader:
    """Read the small declarative Lua subset; fail on unsupported syntax.

    Symbols remain tagged values: this does not execute require/functions or
    substitute defaults for unresolved references. Long strings/comments are
    consumed atomically, so braces/cut marks in letters do not corrupt tables.
    """

    def __init__(self, text):
        self.text, self.pos = text, 0

    def token(self):
        text = self.text
        while self.pos < len(text):
            match = re.match(r"\s+", text[self.pos:])
            if match:
                self.pos += match.end()
                continue
            if text.startswith("--", self.pos):
                self.pos += 2
                long = re.match(r"\[(=*)\[", text[self.pos:])
                if long:
                    ending = "]" + long[1] + "]"
                    self.pos = text.index(ending, self.pos + long.end()) + len(ending)
                else:
                    ending = text.find("\n", self.pos)
                    self.pos = len(text) if ending < 0 else ending + 1
                continue
            break
        if self.pos == len(text):
            raise ValueError("Unexpected end of Lua literal")
        start = self.pos
        long = re.match(r"\[(=*)\[", text[start:])
        if long:
            ending = "]" + long[1] + "]"
            end = text.index(ending, start + long.end())
            self.pos = end + len(ending)
            return ("string", text[start + long.end():end])
        if text[start] in "\"'":
            quote, chars = text[start], []
            self.pos += 1
            while text[self.pos] != quote:
                char = text[self.pos]
                self.pos += 1
                if char == "\\":
                    char = text[self.pos]
                    self.pos += 1
                    char = {"n": "\n", "r": "\r", "t": "\t"}.get(char, char)
                chars.append(char)
            self.pos += 1
            return ("string", "".join(chars))
        match = re.match(r"-?(?:\d+(?:\.\d*)?|\.\d+)", text[start:])
        if match:
            self.pos += match.end()
            value = float(match[0]) if "." in match[0] else int(match[0])
            return ("number", value)
        match = re.match(r"[A-Za-z_][A-Za-z_0-9]*", text[start:])
        if match:
            self.pos += match.end()
            return ("identifier", match[0])
        self.pos += 1
        return (text[start], text[start])

    def peek(self):
        pos = self.pos
        value = self.token()
        self.pos = pos
        return value

    def expect(self, value):
        actual = self.token()
        if actual[0] != value:
            raise ValueError(f"Expected {value}, got {actual}")

    def value(self):
        kind, value = self.token()
        if kind in ("string", "number"):
            return value
        if kind == "identifier":
            if value in ("true", "false"):
                return value == "true"
            return ("lua_symbol", value)
        if kind != "{":
            raise ValueError(f"Unsupported Lua literal: {kind}")
        keyed, array = {}, []
        while self.peek()[0] != "}":
            pos = self.pos
            first = self.token()
            if first[0] == "identifier" and self.peek()[0] == "=":
                self.expect("=")
                keyed[first[1]] = self.value()
            else:
                self.pos = pos
                array.append(self.value())
            if self.peek()[0] in (",", ";"):
                self.token()
            elif self.peek()[0] != "}":
                raise ValueError("Missing Lua table separator")
        self.expect("}")
        if keyed and array:
            raise ValueError("Mixed tables are outside this audit's Lua subset")
        return keyed if keyed or not array else array


def read_literal(file, anchor):
    text = (DATA / file).read_text(encoding="utf-8-sig")
    reader = LiteralReader(text)
    # Scan tokens rather than matching text in comments or letter strings.
    while True:
        token = reader.token()
        if token == ("identifier", anchor):
            if anchor != "return":
                reader.expect("=")
            return reader.value()


def by_id(rows):
    assert len({row["id"] for row in rows}) == len(rows)
    return {row["id"]: row for row in rows}


@dataclass(frozen=True)
class Order:
    id: str
    day: int
    npc: str
    main: str
    axis: str
    previous: str | None = None
    aux: tuple[str, ...] = ()
    ordinary: bool = True


ORDINARY = [
    Order("letter_pa_01", 1, "埃利亚斯", "sleep", "sleep"),
    Order("N01", 2, "卢卡", "steady_hands", "steady"),
    Order("N02", 4, "诺拉", "smile", "happy"),
    Order("N03", 2, "艾莉", "reassured", "safety"),
    Order("N04", 3, "奥托", "happy", "happy"),
    Order("N05", 4, "塞西莉亚", "rational", "reason"),
    Order("N06", 5, "莱昂", "steady_hands", "steady"),
    Order("N07", 6, "贝娅", "angry", "anger"),
    Order("N08", 7, "马丁", "relaxed", "relax"),
    Order("N09", 8, "阿涅丝", "rational", "reason"),
    Order("N10", 9, "雅各布", "rational", "reason"),
    Order("N11", 9, "艾莉", "curious", "curiosity", "N03"),
    Order("N12", 10, "奥托", "warm", "warmth", "N04"),
    Order("N13", 11, "塞西莉亚", "brave", "brave", "N05"),
    Order("N14", 12, "莱昂", "warm", "warmth", "N06"),
    Order("N15", 13, "贝娅", "rational", "reason", "N07"),
    Order("N16", 14, "马丁", "steady_hands", "steady", "N08"),
    Order("N17", 15, "阿涅丝", "relaxed", "relax", "N09"),
    Order("N18", 16, "雅各布", "trusting", "trust", "N10"),
    Order("N19", 16, "艾莉", "happy", "happy", "N11"),
    Order("N20", 17, "奥托", "sad", "sadness", "N12"),
    Order("N21", 17, "塞西莉亚", "rational", "reason", "N13"),
    Order("N22", 18, "莱昂", "happy", "happy", "N14"),
]
MAIN = [
    Order("M02", 3, "玛拉", "quiet", "calm", ordinary=False),
    Order("M03", 4, "阿德琳", "lookup", "brave", ordinary=False),
    Order("M04", 5, "伊莱拉", "wait", "calm", ordinary=False),
    Order("M05", 6, "吕西安", "brave", "brave", ordinary=False),
]
PAIRS = {
    "G01A": Order("G01A", 10, "托马斯", "brave", "brave", aux=("wait",), ordinary=False),
    "G01B": Order("G01B", 10, "吕西安", "quiet", "calm", ordinary=False),
    "G02A": Order("G02A", 12, "阿德琳", "lookup", "brave", aux=("wait",), ordinary=False),
    "G02B": Order("G02B", 12, "克莱拉", "quiet", "calm", ordinary=False),
    "G03A": Order("G03A", 13, "罗文", "quiet", "calm", ordinary=False),
    "G03B": Order("G03B", 13, "玛拉", "lookup", "brave", aux=("wait",), ordinary=False),
}
ROUTES = {
    "归案+学徒": ("G01A", "G02A", "G03A"),
    "逃脱+学徒": ("G01B", "G02B", "G03B"),
    "未解+学徒": ("G01B", "G02A", "G03A"),
}
# Future ordinary sources are content proposals, never credited before receipt.
# Initial fourteen are extracted from the actual three configured letter bodies.
NEW_SOURCES = {
    "N03": ("afraid", "curious", "reassured"),
    "N04": ("sad", "missing", "jealous", "happy"),
    "N05": ("rational", "doubt", "lookup"),
    "N06": ("aching", "steady_hands", "warm"),
    "N07": ("promise", "angry", "brave"),
    "N08": ("promise", "relaxed", "hungry", "wait"),
    "N09": ("rational", "doubt", "promise"),
    "N10": ("confused", "rational", "trusting"),
    "N11": ("curious", "afraid", "bread"),
    "N12": ("warm", "jealous", "smile"),
    "N13": ("brave", "promise", "rational"),
    "N14": ("warm", "aching", "steady_hands"),
    "N15": ("rational", "doubt", "promise"),
    "N16": ("steady_hands", "relaxed", "wait"),
    "N17": ("relaxed", "promise", "soup"),
    "N18": ("trusting", "doubt", "jealous"),
    "N19": ("happy", "smile", "jealous", "afraid"),
    "N20": ("sad", "missing", "jealous", "bread"),
    "N21": ("rational", "doubt", "curious", "promise"),
    "N22": ("happy", "smile", "missing", "aching"),
}
HOME = {"窗帘": 60, "床铺": 100, "壁炉": 140, "书架": 180}
HOME_DAYS = {9: "窗帘", 12: "床铺", 15: "壁炉", 18: "书架"}
RECIPES = {
    "standard": {"ing_night_dew": 1, "ing_sea_salt": 1},
    "nonminimal": {"ing_night_dew": 2},
}


class Audit:
    def __init__(self):
        self.ingredients = by_id(read_literal("ingredients.lua", "return"))
        self.equipment = by_id(read_literal("equipment.lua", "return"))
        self.words = by_id(read_literal("words.lua", "return"))
        self.initial = read_literal("stage1.lua", "initialEconomy")
        self.policy = read_literal("stage1.lua", "recipePolicy")
        self.synthesis = read_literal("synthesis.lua", "return")
        self.profiles = by_id(read_literal("stage1.lua", "attributeProfiles") + read_literal("word_profiles.lua", "return"))
        self.speeds = read_literal("word_profiles.lua", "SPEED_TO_DELAY_HOURS")
        assert self.speeds == read_literal("stage1.lua", "SPEED_TO_DELAY_HOURS")
        self.sleep_residuals = read_literal("stage1.lua", "SLEEP_RESIDUAL_POINTS")
        self.configured = by_id(read_literal("letters.lua", "return") + read_literal("ordinary_orders.lua", "letters"))
        display_ids = {word["displayText"]: id for id, word in self.words.items()}
        self.sources = dict(NEW_SOURCES)
        for content_id, lua_id in (("letter_pa_01", "letter_pa_01"), ("N01", "letter_n01"), ("N02", "letter_n02")):
            letter = self.configured[lua_id]
            assert letter["reward"]["currency"] == 80
            assert letter["appearCondition"]["dayMin"] == next(order.day for order in ORDINARY if order.id == content_id)
            self.sources[content_id] = tuple(display_ids[text].removeprefix("word_") for text in re.findall(r"\{\{(.*?)\}\}", letter["body"]))
        assert self.initial["currency"] == 30
        assert read_literal("stage1.lua", "initialEquipmentId") == "kit_old_cauldron"
        assert self.initial["ingredients"] == {id: 3 for id in self.ingredients}
        assert {id: row["price"] for id, row in self.ingredients.items()} == {
            "ing_sea_salt": 5, "ing_night_dew": 12, "ing_ashen_herb": 20, "ing_dried_petal": 15,
        }
        assert self.policy["repeatIngredient"] is True
        assert self.policy["repeatWordDefinition"] is False
        assert all(not row["addTags"] for row in self.ingredients.values())
        assert self.equipment["kit_old_cauldron"]["owned"] is True
        assert self.equipment["kit_old_cauldron"]["price"] == 0
        assert self.equipment["kit_copper_cauldron"]["price"] == 120
        assert self.equipment["kit_copper_cauldron"]["slots"]["ingredient"] == 2
        assert self.equipment["kit_copper_cauldron"]["slots"]["auxWord"] == 3
        assert all(word["reusable"] is True for word in self.words.values())
        assert len(self.words) == 30 and len(ORDINARY) == 23
        assert sum(HOME.values()) == 480
        # Cross-check the proposed content input against the delivered manuscript.
        manuscript = (ROOT / "docs/文案/普通订单/普通订单正文包_N03-N22_v01.md").read_text(encoding="utf-8-sig")
        manuscript_rows = {}
        for line in manuscript.splitlines():
            if re.match(r"\| `letter_n\d+` \| D\d+ \|", line):
                cells = [cell.strip() for cell in line.split("|")[1:-1]]
                id = "N" + re.search(r"letter_n(\d+)", cells[0])[1]
                manuscript_rows[id] = cells
        assert len(manuscript_rows) == 20
        for order in ORDINARY[3:]:
            cells = manuscript_rows[order.id]
            assert int(cells[1][1:]) == order.day and cells[2] == order.npc
            previous = re.search(r"letter_n(\d+)", cells[3])
            assert ("N" + previous[1] if previous else None) == order.previous
            assert "`word_" + order.main + "`" in cells[4]
            assert tuple(display_ids[word].removeprefix("word_") for word in cells[5].split("、")) == self.sources[order.id]
            assert order.main in self.sources[order.id]
        main_manuscript = (ROOT / "docs/文案/主线/主线正文与后续包_v02.md").read_text(encoding="utf-8-sig")
        headings = list(re.finditer(r"^### (M\d{2}|G\d{2}[AB])｜[^\n]+", main_manuscript, re.M))
        assert len(headings) == 14
        proposed = {order.id: order for order in MAIN + list(PAIRS.values())}
        self.main_order_defs, self.pair_order_defs = [], {}
        for index, heading in enumerate(headings):
            id = heading[1]
            section = main_manuscript[heading.end():headings[index + 1].start() if index + 1 < len(headings) else main_manuscript.index("## 4.")]
            if id not in proposed:
                assert id in {"M01", "M06", "M07", "M08"}
                assert not re.findall(r"\{\{(.*?)\}\}", section)
                continue
            body = re.search(r"^店主：\s*\n(.*?)(?=^要求)", section, re.M | re.S)
            assert body is not None, f"No bounded mainline body: {id}"
            cut_words = re.findall(r"\{\{(.*?)\}\}", body[1])
            assert cut_words and len(cut_words) == len(set(cut_words))
            source_ids = tuple(display_ids[word].removeprefix("word_") for word in cut_words)
            self.sources[id] = source_ids
            requirement_line = re.search(r"^要求[^\n]+", section, re.M)[0]
            order = proposed[id]
            declared_main = re.search(r"S\s*主([\u4e00-\u9fff]+?)(?:三星|[。；])", requirement_line)
            if declared_main:
                main_id = display_ids[declared_main[1]].removeprefix("word_")
            else:
                # Where S+ only names its calm auxiliary, the main is the
                # first own-body word which supplies the declared main axis.
                main_id = next(word for word in source_ids if self.words["word_" + word]["effects"].get(order.axis, 0) >= 0.8)
            declared_aux = re.search(r"三星S\+辅([\u4e00-\u9fff]+)", requirement_line)
            aux_text = next((word for word in cut_words if declared_aux and declared_aux[1].startswith(word)), None)
            assert declared_aux is None or aux_text is not None
            aux_ids = (display_ids[aux_text].removeprefix("word_"),) if aux_text else ()
            assert main_id == order.main and aux_ids == order.aux, f"Recipe/manuscript mismatch: {id}"
            assert main_id in source_ids and all(word in source_ids for word in aux_ids)
            actual_order = replace(order, main=main_id, aux=aux_ids)
            if id.startswith("M"):
                self.main_order_defs.append(actual_order)
            else:
                self.pair_order_defs[id] = actual_order
        assert len(self.main_order_defs) == 4 and len(self.pair_order_defs) == 6

    def recipe_check(self, order, recipe):
        slots = self.equipment["kit_old_cauldron"]["slots"]
        assert sum(recipe.values()) <= slots["ingredient"] == 2
        assert len(order.aux) <= slots["auxWord"] == 2
        main = self.words["word_" + order.main]
        effects = dict(main["effects"])
        for id in order.aux:
            for effect, weight in self.words["word_" + id]["effects"].items():
                bonus = self.synthesis["sameTagBonus"] if effect in effects else 0
                effects[effect] = effects.get(effect, 0) + weight * self.synthesis["auxWeight"] + bonus
        mods = Counter()
        for id, quantity in recipe.items():
            for key, value in self.ingredients[id]["mods"].items():
                mods[key] += value * quantity
        assert mods["intensity"] == mods["sideEffect"] == 0
        assert effects.get(order.axis, 0) >= 0.8
        profile = self.profiles[main["attributeProfileId"]]
        duration = profile["baseDurationHours"] + mods["duration"] * profile["durationHoursPerPoint"]
        onset = next(point["delayHours"] for point in self.speeds if point["speed"] == mods["speed"])
        if order.id == "letter_pa_01":
            assert 6 <= duration <= 8 and onset <= 3
            assert onset + duration + profile["recoveryAfterEndHours"] <= 12
            hours_after_end = 12 - onset - duration
            ratio = next(point["ratio"] for point in self.sleep_residuals if point["hoursAfterEnd"] == hours_after_end)
            assert effects["sleep"] * ratio <= 0.4
        else:
            assert 2 <= duration <= 4 and onset <= 1
            assert effects.get("sleep", 0) <= 0.4
        if order.aux:
            assert effects["calm"] >= 0.6 and effects.get("forget", 0) < 0.6
        return {"duration": duration, "onset": onset, "stability": mods["stability"],
                "unstable": mods["stability"] < self.synthesis["unstableThreshold"]}

    def simulate(self, route, recipe_name="standard", omitted=(), homes=False, read_omitted=False, first_three=False):
        recipe = RECIPES[recipe_name]
        orders = sorted(ORDINARY + self.main_order_defs + [self.pair_order_defs[id] for id in route], key=lambda order: (order.day, order.id))
        if first_three:
            orders = [order for order in orders if order.id in {"letter_pa_01", "N01", "N02"}]
        assert len(orders) == (3 if first_three else 30)
        # A missed first letter blocks its continuations. Missing one cannot
        # silently fabricate the previous-confirmed fact for a later order.
        blocked = set(omitted)
        for order in orders:
            if order.previous in blocked:
                blocked.add(order.id)
        currency, inventory = self.initial["currency"], dict(self.initial["ingredients"])
        received, completed, ledger, tokens, word_ledger = set(), set(), [], {}, []
        for day in range(1, 19):
            opening, purchased, rewards, delivered = currency, Counter(), 0, []
            shelf = {id: 6 for id in self.ingredients}  # New proposal: reset daily, no carry.
            for order in orders:
                if order.day != day:
                    continue
                if order.id in blocked and order.id not in omitted:
                    continue
                if order.previous is not None and order.previous not in completed:
                    continue
                if order.id in omitted and not read_omitted:
                    continue
                received.update("word_" + word for word in self.sources.get(order.id, ()))
                gained = []
                letter_id = order.id if order.id.startswith("letter_") else "letter_" + order.id.lower()
                for index, word in enumerate(self.sources.get(order.id, ()), 1):
                    token_id = f"draft:{letter_id}:body:{index}"
                    assert token_id not in tokens
                    tokens[token_id] = {"wordId": "word_" + word, "letterId": letter_id,
                                        "spanId": f"body:{index}", "available": True,
                                        "consumedByOrderId": None}
                    gained.append(token_id)
                # "Miss an order" means no confirmation/reward/material spend;
                # an already received letter can still be read and clipped.
                if order.id in omitted:
                    word_ledger.append({"orderId": order.id, "gained": gained, "used": [], "omitted": True})
                    continue
                # Explicit manuscript route: use this letter's own main/aux cards.
                # This is a published input selection, not an automatic runtime policy.
                used = []
                for role, word in [("main", order.main)] + [("aux", word) for word in order.aux]:
                    candidates = [id for id in gained if tokens[id]["wordId"] == "word_" + word and tokens[id]["available"]]
                    assert len(candidates) == 1, (order.id, role, word, "missing own-source card")
                    token_id = candidates[0]
                    assert token_id not in {row["tokenId"] for row in used}
                    used.append({"role": role, "tokenId": token_id})
                self.recipe_check(order, recipe)
                # Buy each missing unit before mixing; today's later rewards
                # cannot fund this order's materials. No free shop replenishment.
                for id, quantity in recipe.items():
                    deficit = max(0, quantity - inventory[id])
                    price = self.ingredients[id]["price"]
                    for _ in range(deficit):
                        assert shelf[id] >= 1 and currency >= price
                        shelf[id] -= 1
                        inventory[id] += 1
                        currency -= price
                        purchased[id] += 1
                    inventory[id] -= quantity
                # Each unique formal confirmation earns the fixed 80 once.
                assert order.id not in completed
                currency += 80
                rewards += 80
                completed.add(order.id)
                delivered.append(order.id)
                for selected in used:
                    token = tokens[selected["tokenId"]]
                    assert token["available"] and token["consumedByOrderId"] is None
                    token["available"], token["consumedByOrderId"] = False, "draft-order:" + letter_id
                counts = Counter(token["wordId"] for token in tokens.values() if token["available"])
                word_ledger.append({"orderId": order.id, "gained": gained, "used": used,
                                    "available_counts_after_confirm": dict(counts), "omitted": False})
            home = HOME_DAYS.get(day) if homes else None
            if home:
                assert currency >= HOME[home]
                currency -= HOME[home]
            spending = sum(self.ingredients[id]["price"] * quantity for id, quantity in purchased.items())
            assert currency == opening + rewards - spending - (HOME[home] if home else 0)
            ledger.append({"day": day, "orders": delivered, "opening": opening, "reward": rewards,
                           "purchases": dict(purchased), "materials": spending, "home": home,
                           "home_cost": HOME.get(home, 0), "closing": currency, "inventory": dict(inventory)})
        source_inventory = {}
        for id, token in tokens.items():
            if token["available"]:
                source_inventory.setdefault(token["wordId"], []).append(id)
        available_ids = set(source_inventory)
        categories = sorted({self.words[id]["category"] for id in available_ids})
        ticket = next((row["day"] for row in ledger if 6 <= row["day"] <= 11 and row["closing"] >= 300), None)
        return {"completed": sorted(completed), "blocked": sorted(blocked), "ledger": ledger,
                "day11": ledger[10]["closing"], "ending": currency, "ticket_day": ticket,
                "word_ids": sorted(available_ids), "word_count": len(available_ids), "categories": categories,
                "historical_word_ids": sorted(received), "word_inventory_sources": source_inventory,
                "word_tokens": tokens, "word_ledger": word_ledger}

    def omission_matrix(self, route, recipe, read_omitted=False):
        results = []
        for omitted in itertools.combinations([order.id for order in ORDINARY], 2):
            result = self.simulate(route, recipe, omitted, read_omitted=read_omitted)
            assert result["ticket_day"] is not None
            results.append({"omitted": omitted, "blocked": result["blocked"], "day11": result["day11"],
                            "day6": result["ledger"][5]["closing"], "ticket_day": result["ticket_day"]})
        minimum = min(row["day11"] for row in results)
        by_day = {order.id: order.day for order in ORDINARY}
        return {"combinations": len(results), "both_by_day11": sum(all(by_day[id] <= 11 for id in row["omitted"]) for row in results),
                "at_least_one_by_day11": sum(any(by_day[id] <= 11 for id in row["omitted"]) for row in results),
                "minimum_day6": min(row["day6"] for row in results), "minimum_day11": minimum,
                "worst": [row for row in results if row["day11"] == minimum], "all_results": results}

    def report(self):
        routes = {}
        for name, route in ROUTES.items():
            normal = self.simulate(route)
            apprentice = self.simulate(route, homes=True)
            stress = self.simulate(route, "nonminimal")
            stress_home = self.simulate(route, "nonminimal", homes=True)
            assert len(apprentice["completed"]) == 30
            assert apprentice["word_count"] >= 12 and len(apprentice["categories"]) >= 5
            assert len(apprentice["historical_word_ids"]) == 30
            routes[name] = {"standard": normal, "apprentice": apprentice,
                            "nonminimal": stress, "nonminimal_home": stress_home}
        matrix = {name: {recipe: self.omission_matrix(route, recipe) for recipe in RECIPES} for name, route in ROUTES.items()}
        read_matrix = {name: {recipe: self.omission_matrix(route, recipe, read_omitted=True) for recipe in RECIPES} for name, route in ROUTES.items()}
        for name in ROUTES:
            for recipe in RECIPES:
                assert matrix[name][recipe]["minimum_day11"] == read_matrix[name][recipe]["minimum_day11"]
        # Retained witness after the whole route, not historical collection.
        witness_ids = ["dream", "quiet", "happy", "forget", "tired", "bread", "promise", "lookup", "steady_hands", "homecoming", "wait", "hungry"]
        for result in routes.values():
            assert {"word_" + id for id in witness_ids} <= set(result["standard"]["word_ids"])
        witness_categories = sorted({self.words["word_" + id]["category"] for id in witness_ids})
        assert len(set(witness_ids)) == 12 and len(witness_categories) >= 5
        for result in routes.values():
            assert result["standard"]["ticket_day"] == 6
            assert result["standard"]["ending"] == 1971
            assert result["apprentice"]["ending"] == 1491
            assert result["nonminimal"]["ending"] == 1746
            assert result["nonminimal_home"]["ending"] == 1266
        # Verify every possible chosen group recipe/schedule, without claiming
        # all eight group combinations yield the same narrative outcome.
        for route in itertools.product(("G01A", "G01B"), ("G02A", "G02B"), ("G03A", "G03B")):
            for recipe in RECIPES:
                assert len(self.simulate(route, recipe)["completed"]) == 30
        minimal = self.simulate(ROUTES["归案+学徒"], first_three=True)
        assert len(minimal["completed"]) == 3 and minimal["word_count"] == 11
        assert len(minimal["historical_word_ids"]) == 14 and minimal["ending"] == 270
        assert len([token for token in minimal["word_tokens"].values() if not token["available"]]) == 3
        return {"scope": "single-use proposal; current words remain reusable; future supply/rewards/schema not runtime-verified",
                "first_three": minimal,
                "routes": routes, "omission_matrix": matrix, "omission_matrix_already_read": read_matrix,
                "mainline_source_contract": {
                    order.id: {"body_word_ids": ["word_" + word for word in self.sources[order.id]],
                               "main_word_id": "word_" + order.main,
                               "aux_word_ids": ["word_" + word for word in order.aux]}
                    for order in self.main_order_defs + list(self.pair_order_defs.values())},
                "information_word_sources": {id: [] for id in ("M01", "M06", "M07", "M08")},
                "retention_witness": {"word_ids": ["word_" + id for id in witness_ids], "categories": witness_categories},
                "recipe_flags": {name: self.recipe_check(ORDINARY[0], recipe) for name, recipe in RECIPES.items()}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Print all ledgers and all 253 combinations per route/recipe")
    parser.add_argument("--ledger", action="store_true", help="Print standard and nonminimal daily ledger")
    parser.add_argument("--export-word-ledger", type=Path, help="Write first-three and three normal-route token ledgers")
    args = parser.parse_args()
    report = Audit().report()
    if args.export_word_ledger:
        payload = {"scope": report["scope"], "first_three": report["first_three"],
                   "routes": {name: result["standard"] for name, result in report["routes"].items()}}
        args.export_word_ledger.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return
    print("PASS: pure-content arithmetic; future shop/mainline/identity are NOT runtime-verified.")
    print("Single-use draft ledger: first three use sleep / steady_hands / smile; 14 acquired definitions, 11 retained, 270 coins. Current data still reusable=true.")
    print("253 omitted pairs x 3 routes x 2 recipes x 2 receipt modes = 3036 omission inputs; 20 ordinary + 10 mainline own-body sources matched; 4 information letters grant no words.")
    for name, result in report["routes"].items():
        print(name, "orders=30", "retained words", result["standard"]["word_count"], "categories", len(result["standard"]["categories"]), "standard", result["standard"]["ending"],
              "home", result["apprentice"]["ending"], "nonminimal", result["nonminimal"]["ending"],
              "nonminimal+home", result["nonminimal_home"]["ending"], "ticket D", result["standard"]["ticket_day"])
    for recipe, matrix in report["omission_matrix"]["归案+学徒"].items():
        print(recipe, "C(23,2)=", matrix["combinations"], "both by D11=", matrix["both_by_day11"],
              "at least one by D11=", matrix["at_least_one_by_day11"],
              "worst D6=", matrix["minimum_day6"], "worst D11=", matrix["minimum_day11"])
        print("worst omitted pairs:", "; ".join("+".join(row["omitted"]) for row in matrix["worst"]))
    if args.ledger:
        for recipe in RECIPES:
            print(recipe)
            for row in report["routes"]["归案+学徒"][recipe]["ledger"]:
                print(json.dumps(row, ensure_ascii=False))


if __name__ == "__main__":
    main()
