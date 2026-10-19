"""Export the frozen Maker content into the Godot content catalog.

The Lua project remains the authority. This tool loads the real runtime data
through Lupa, validates references, records source hashes and writes a stable
JSON snapshot consumed by the Godot project.

Run from the repository root:
    python godot/tools/export_content.py
    python godot/tools/export_content.py --check
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = Path(__file__).resolve().parents[1]
DEFAULT_SCHEMA = PROJECT / "content" / "content_schema.json"
DEFAULT_OUTPUT = PROJECT / "content" / "generated" / "catalog.json"
DEFAULT_FIXTURES = PROJECT / "tests" / "fixtures" / "content_checks.json"
DEFAULT_PYTHON_LIBS = ROOT / ".tmp" / "b1-python"


class ExportError(Exception):
    def __init__(self, code: str, path: str, message: str):
        super().__init__(f"{code} {path}: {message}")
        self.code = code
        self.path = path
        self.message = message


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def normalize_path(path: str) -> str:
    return ".".join("[]" if part.isdigit() else part for part in path.split("."))


def lua_value(value):
    """Lupa returns Lua tables; scalar values are already Python values."""
    return value


def convert(value, path: str, array_fields: set[str], object_fields: set[str]):
    if not hasattr(value, "keys"):
        return lua_value(value)
    keys = list(value.keys())
    if not keys:
        normalized = normalize_path(path)
        if normalized in object_fields:
            return {}
        if normalized in array_fields:
            return []
        raise ExportError(
            "EMPTY_TABLE_AMBIGUOUS",
            path,
            "empty Lua table is not declared as an array or object in content_schema.json",
        )
    if all(isinstance(key, int) for key in keys):
        ordered = sorted(keys)
        if ordered != list(range(1, len(ordered) + 1)):
            raise ExportError("ARRAY_NOT_DENSE", path, "Lua array keys must be 1..n")
        return [convert(value[key], f"{path}[]", array_fields, object_fields) for key in ordered]
    if all(isinstance(key, str) for key in keys):
        result = {}
        for key in sorted(keys):
            result[key] = convert(value[key], f"{path}.{key}", array_fields, object_fields)
        return result
    raise ExportError("TABLE_KEY_MIXED", path, "Lua table mixes array and object keys")


def call_pair(function, path: str):
    result = function()
    if isinstance(result, tuple):
        if len(result) != 2:
            raise ExportError("LUA_RESULT_INVALID", path, f"expected two values, got {len(result)}")
        return result[0], result[1]
    return result, None


def load_lua(python_libs: Path):
    sys.path.insert(0, str(python_libs))
    try:
        from lupa.lua54 import LuaRuntime  # noqa: PLC0415
    except ImportError as error:
        raise SystemExit(
            f"Lupa is required for content export. Install lupa==2.6 or pass --python-libs: {error}"
        ) from error
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        "package.path = ... .. '/scripts/?.lua;' .. package.path",
        ROOT.as_posix(),
    )
    return lua


def source_inventory() -> tuple[list[dict], str]:
    files = sorted((ROOT / "scripts" / "data").rglob("*.lua"))
    rows = []
    for path in files:
        rows.append({
            "path": path.relative_to(ROOT).as_posix(),
            "sha256": sha256_file(path),
            "bytes": path.stat().st_size,
        })
    material = "".join(f"{row['path']}:{row['sha256']}\n" for row in rows)
    return rows, sha256_bytes(material.encode("utf-8"))


def unwrap(value):
    if isinstance(value, tuple):
        return value[0] if value else None
    return value


def build_raw(lua) -> dict:
    data = unwrap(lua.eval('require("data.content")'))
    ok, errors = call_pair(data.Load, "data.content.Load")
    if not ok:
        raise ExportError("CONTENT_LOAD_FAILED", "data.content.Load", str(errors))
    ok, errors = call_pair(data.ValidateStage1, "data.content.ValidateStage1")
    if not ok:
        raise ExportError("CONTENT_VALIDATE_FAILED", "data.content.ValidateStage1", str(errors))
    wish = unwrap(lua.eval('require("data.wish_decorations")'))
    gameplay = unwrap(lua.eval('require("data.gameplay")'))
    letter_api = unwrap(lua.eval('require("systems.Letter").New(require("data.content"))'))
    letter_spans = {}
    for index in range(1, len(data.letters) + 1):
        letter = data.letters[index]
        letter_id = letter["id"]
        parsed = letter_api.ParseDefinition(letter_id)
        if not parsed["ok"]:
            raise ExportError(
                "LETTER_PARSE_FAILED",
                f"letters.{letter_id}",
                json.dumps(convert(parsed["error"], "letters.error", set(), set()), ensure_ascii=False),
            )
        spans = []
        for span_index in range(1, len(parsed["value"]["spans"]) + 1):
            span = parsed["value"]["spans"][span_index]
            spans.append({
                "spanId": span["spanId"],
                "wordId": span["wordId"],
                "text": span["text"],
                "kind": span["kind"],
                "cut": span["cut"],
            })
        letter_spans[letter_id] = {"spans": spans}
    return {
        "contentVersion": data.contentVersion,
        "saveSlotId": data.saveSlotId,
        "release": data.release,
        "releaseEndings": data.releaseEndings,
        "stage1": data.stage1,
        "synthesis": data.synthesis,
        "shop": data.shop,
        "gameplay": gameplay,
        "wishDecorations": wish.list,
        "factExclusionGroups": data.factExclusionGroups,
        "letterSpans": letter_spans,
        "effects": data.effects,
        "words": data.words,
        "ingredients": data.ingredients,
        "equipment": data.equipment,
        "furniture": data.furniture,
        "npcs": data.npcs,
        "letters": data.letters,
        "attributeProfiles": data.attributeProfiles,
        "followupTemplates": data.followupTemplates,
        "fragments": data.fragments,
        "directRules": data.directRules,
        "orderRatings": data.orderRatings,
        "recipes": data.recipes,
    }


def require(condition, code: str, path: str, message: str, errors: list[dict]) -> None:
    if not condition:
        errors.append({"code": code, "path": path, "message": message})


def as_list(value, code: str, path: str, errors: list[dict]) -> list:
    if not isinstance(value, list):
        errors.append({"code": code, "path": path, "message": "must be an array"})
        return []
    return value


def as_dict(value, code: str, path: str, errors: list[dict]) -> dict:
    if not isinstance(value, dict):
        errors.append({"code": code, "path": path, "message": "must be an object"})
        return {}
    return value


def is_int(value) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) or (
        isinstance(value, float) and value.is_integer()
    )


def id_set(rows: list, name: str, errors: list[dict]) -> set:
    result = set()
    for index, row in enumerate(rows):
        path = f"{name}[{index}]"
        if not isinstance(row, dict):
            errors.append({"code": "CONTENT_INVALID", "path": path, "message": "entry must be an object"})
            continue
        identifier = row.get("id")
        if not isinstance(identifier, str) or not identifier:
            errors.append({"code": "CONTENT_INVALID", "path": f"{path}.id", "message": "id must be a non-empty string"})
            continue
        if identifier in result:
            errors.append({"code": "DUPLICATE_ID", "path": f"{path}.id", "message": f"duplicate id {identifier}"})
        result.add(identifier)
    return result


def key_set(rows: list, field: str) -> set:
    result = set()
    for row in rows:
        if isinstance(row, dict) and isinstance(row.get(field), str):
            result.add(row[field])
    return result


def recipe_refs(recipe: dict, path: str, words: set, ingredients: set, equipment: set,
                letter_ids: set | None, errors: list[dict]) -> None:
    if not isinstance(recipe, dict):
        errors.append({"code": "CONTENT_INVALID", "path": path, "message": "recipe must be an object"})
        return
    if "mainWordId" in recipe:
        require(recipe["mainWordId"] in words, "UNKNOWN_REF", f"{path}.mainWordId",
                f"unknown word {recipe.get('mainWordId')}", errors)
    for index, word_id in enumerate(recipe.get("auxWordIds") or []):
        require(word_id in words, "UNKNOWN_REF", f"{path}.auxWordIds[{index}]", f"unknown word {word_id}", errors)
    for index, row in enumerate(recipe.get("ingredients") or []):
        if not isinstance(row, dict):
            errors.append({"code": "CONTENT_INVALID", "path": f"{path}.ingredients[{index}]",
                           "message": "ingredient row must be an object"})
            continue
        require(row.get("ingredientId") in ingredients, "UNKNOWN_REF", f"{path}.ingredients[{index}].ingredientId",
                f"unknown ingredient {row.get('ingredientId')}", errors)
        require(is_int(row.get("quantity")) and int(row["quantity"]) > 0, "CONTENT_INVALID",
                f"{path}.ingredients[{index}].quantity", "quantity must be a positive integer", errors)
    require(recipe.get("equipmentId") in equipment, "UNKNOWN_REF", f"{path}.equipmentId",
            f"unknown equipment {recipe.get('equipmentId')}", errors)
    if letter_ids is not None and "letterId" in recipe:
        require(recipe["letterId"] in letter_ids, "UNKNOWN_REF", f"{path}.letterId",
                f"unknown letter {recipe['letterId']}", errors)


def validate_catalog(catalog: dict, schema: dict) -> list[dict]:
    errors: list[dict] = []
    for field in ("contentVersion", "saveSlotId", "release", "releaseEndings", "stage1",
                  "synthesis", "shop", "gameplay", "letterSpans",
                  "factExclusionGroups"):
        require(field in catalog, "CONTENT_MISSING", field, "required top-level field", errors)
    require(catalog.get("contentVersion") == schema.get("content_version"), "CONTENT_VERSION_MISMATCH",
            "contentVersion", f"expected {schema.get('content_version')}", errors)

    collections = catalog.get("collections", {})
    expected = schema.get("expected_counts", {})
    for name in schema.get("collections", {}):
        rows = as_list(collections.get(name), "CONTENT_INVALID", name, errors)
        require(len(rows) == expected.get(name, len(rows)), "CONTENT_COUNT_MISMATCH", name,
                f"expected {expected.get(name)}, got {len(rows)}", errors)
        id_set(rows, name, errors)

    effects = id_set(as_list(collections.get("effects"), "CONTENT_INVALID", "effects", errors), "effects", errors)
    words = id_set(as_list(collections.get("words"), "CONTENT_INVALID", "words", errors), "words", errors)
    ingredients = id_set(as_list(collections.get("ingredients"), "CONTENT_INVALID", "ingredients", errors),
                         "ingredients", errors)
    equipment = id_set(as_list(collections.get("equipment"), "CONTENT_INVALID", "equipment", errors),
                       "equipment", errors)
    npcs = id_set(as_list(collections.get("npcs"), "CONTENT_INVALID", "npcs", errors), "npcs", errors)
    letters = id_set(as_list(collections.get("letters"), "CONTENT_INVALID", "letters", errors), "letters", errors)
    profiles = id_set(as_list(collections.get("attributeProfiles"), "CONTENT_INVALID", "attributeProfiles", errors),
                      "attributeProfiles", errors)
    templates = id_set(as_list(collections.get("followupTemplates"), "CONTENT_INVALID", "followupTemplates", errors),
                       "followupTemplates", errors)
    fragments = id_set(as_list(collections.get("fragments"), "CONTENT_INVALID", "fragments", errors),
                       "fragments", errors)
    rules = as_list(collections.get("directRules"), "CONTENT_INVALID", "directRules", errors)
    ratings = as_list(collections.get("orderRatings"), "CONTENT_INVALID", "orderRatings", errors)
    id_set(rules, "directRules", errors)
    id_set(ratings, "orderRatings", errors)
    recipes = as_list(collections.get("recipes"), "CONTENT_INVALID", "recipes", errors)
    id_set(recipes, "recipes", errors)
    wish = as_list(collections.get("wishDecorations"), "CONTENT_INVALID", "wishDecorations", errors)
    id_set(wish, "wishDecorations", errors)
    rule_sets = key_set(rules, "ruleSetId")
    rating_sets = key_set(ratings, "ratingSetId")
    template_ids = templates

    for index, word in enumerate(collections.get("words", [])):
        path = f"words[{index}]"
        require(isinstance(word.get("displayText"), str) and word["displayText"], "CONTENT_INVALID",
                f"{path}.displayText", "displayText must be a non-empty string", errors)
        require(isinstance(word.get("category"), str) and word["category"], "CONTENT_INVALID",
                f"{path}.category", "category must be a non-empty string", errors)
        require(isinstance(word.get("reusable"), bool), "CONTENT_INVALID", f"{path}.reusable",
                "reusable must be boolean", errors)
        for effect_id in (word.get("effects") or {}):
            require(effect_id in effects, "UNKNOWN_REF", f"{path}.effects.{effect_id}",
                    f"unknown effect {effect_id}", errors)
        if word.get("attributeProfileId") is not None:
            require(word["attributeProfileId"] in profiles, "UNKNOWN_REF", f"{path}.attributeProfileId",
                    f"unknown attribute profile {word['attributeProfileId']}", errors)

    for index, ingredient in enumerate(collections.get("ingredients", [])):
        path = f"ingredients[{index}]"
        for effect_id in (ingredient.get("addTags") or {}):
            require(effect_id in effects, "UNKNOWN_REF", f"{path}.addTags.{effect_id}",
                    f"unknown effect {effect_id}", errors)
        for mod in (ingredient.get("mods") or {}):
            require(mod in {"intensity", "duration", "speed", "stability", "sideEffect"}, "CONTENT_INVALID",
                    f"{path}.mods.{mod}", "unknown mod key", errors)
        require(is_int(ingredient.get("price")), "CONTENT_INVALID", f"{path}.price",
                "price must be an integer", errors)

    for index, kit in enumerate(collections.get("equipment", [])):
        path = f"equipment[{index}]"
        slots = as_dict(kit.get("slots"), "CONTENT_INVALID", f"{path}.slots", errors)
        for slot in ("mainWord", "auxWord", "ingredient", "specialItem"):
            require(is_int(slots.get(slot)), "CONTENT_INVALID", f"{path}.slots.{slot}",
                    "slot must be an integer", errors)
        require(isinstance(kit.get("owned"), bool), "CONTENT_INVALID", f"{path}.owned",
                "owned must be boolean", errors)

    for index, npc in enumerate(collections.get("npcs", [])):
        path = f"npcs[{index}]"
        require(isinstance(npc.get("name"), str) and npc["name"], "CONTENT_INVALID", f"{path}.name",
                "name must be a non-empty string", errors)
        as_dict(npc.get("initialState"), "CONTENT_INVALID", f"{path}.initialState", errors)
        as_dict(npc.get("initialStateSchema"), "CONTENT_INVALID", f"{path}.initialStateSchema", errors)

    for index, letter in enumerate(collections.get("letters", [])):
        path = f"letters[{index}]"
        require(letter.get("senderId") in npcs, "UNKNOWN_REF", f"{path}.senderId",
                f"unknown npc {letter.get('senderId')}", errors)
        require(isinstance(letter.get("title"), str) and letter["title"], "CONTENT_INVALID", f"{path}.title",
                "title must be non-empty", errors)
        if letter.get("kind") == "order":
            require(isinstance(letter.get("body"), str) and letter["body"], "CONTENT_INVALID", f"{path}.body",
                    "order letter body must be a non-empty string", errors)
            as_dict(letter.get("requirement"), "CONTENT_INVALID", f"{path}.requirement", errors)
        for cut_index, word_id in enumerate(letter.get("cutWordIds") or []):
            require(word_id in words, "UNKNOWN_REF", f"{path}.cutWordIds[{cut_index}]",
                    f"unknown word {word_id}", errors)
        if letter.get("directRuleSetId"):
            require(letter["directRuleSetId"] in rule_sets, "UNKNOWN_REF", f"{path}.directRuleSetId",
                    f"unknown rule set {letter['directRuleSetId']}", errors)
        if letter.get("ratingSetId"):
            require(letter["ratingSetId"] in rating_sets, "UNKNOWN_REF", f"{path}.ratingSetId",
                    f"unknown rating set {letter['ratingSetId']}", errors)
        if letter.get("followupTemplateId"):
            require(letter["followupTemplateId"] in template_ids, "UNKNOWN_REF", f"{path}.followupTemplateId",
                    f"unknown template {letter['followupTemplateId']}", errors)
        requirement = letter.get("requirement") if letter.get("kind") == "order" else {}
        if not isinstance(requirement, dict):
            requirement = {}
        for effect_id in (requirement.get("tags") or {}):
            require(effect_id in effects, "UNKNOWN_REF", f"{path}.requirement.tags.{effect_id}",
                    f"unknown effect {effect_id}", errors)
        for cond_index, cond in enumerate(requirement.get("conditions") or []):
            cond_path = f"{path}.requirement.conditions[{cond_index}]"
            require(isinstance(cond, dict), "CONTENT_INVALID", cond_path, "condition must be an object", errors)
            require(cond.get("kind") in {"duration", "onset", "workReady", "residualAt", "forbiddenEffect"},
                    "CONTENT_INVALID", f"{cond_path}.kind", "unknown condition kind", errors)

    for index, template in enumerate(collections.get("followupTemplates", [])):
        path = f"followupTemplates[{index}]"
        require(template.get("letterId") in letters, "UNKNOWN_REF", f"{path}.letterId",
                f"unknown letter {template.get('letterId')}", errors)
        for field in ("fragmentIds", "baseFragmentIds", "fallbackFragmentIds"):
            for ref_index, fragment_id in enumerate(template.get(field) or []):
                require(fragment_id in fragments, "UNKNOWN_REF", f"{path}.{field}[{ref_index}]",
                        f"unknown fragment {fragment_id}", errors)

    for index, fragment in enumerate(collections.get("fragments", [])):
        path = f"fragments[{index}]"
        require(fragment.get("templateId") in template_ids, "UNKNOWN_REF", f"{path}.templateId",
                f"unknown template {fragment.get('templateId')}", errors)
        for field in ("coversFacts", "requiresFacts", "excludesFacts", "overrides"):
            for ref_index, value in enumerate(fragment.get(field) or []):
                require(isinstance(value, str) and value, "CONTENT_INVALID", f"{path}.{field}[{ref_index}]",
                        "id must be a non-empty string", errors)
        require(isinstance(fragment.get("text"), str) and fragment["text"], "CONTENT_INVALID",
                f"{path}.text", "fragment text must be non-empty", errors)

    for index, rule in enumerate(rules):
        path = f"directRules[{index}]"
        require(isinstance(rule.get("ruleSetId"), str) and rule["ruleSetId"], "CONTENT_INVALID",
                f"{path}.ruleSetId", "ruleSetId must be non-empty", errors)
        for field in ("when", "unless"):
            for cond_index, cond in enumerate(rule.get(field) or []):
                cond_path = f"{path}.{field}[{cond_index}]"
                require(isinstance(cond, dict), "CONTENT_INVALID", cond_path, "condition must be an object", errors)
                require(cond.get("op") in {"eq", "ne", "gte", "lte"}, "CONTENT_INVALID", f"{cond_path}.op",
                        "unknown operator", errors)
                require(isinstance(cond.get("path"), str) and cond["path"], "CONTENT_INVALID",
                        f"{cond_path}.path", "path must be non-empty", errors)
        for change_index, change in enumerate(rule.get("changes") or []):
            change_path = f"{path}.changes[{change_index}]"
            require(isinstance(change, dict), "CONTENT_INVALID", change_path, "change must be an object", errors)
            require(change.get("op") in {"set", "add"}, "CONTENT_INVALID", f"{change_path}.op",
                    "unknown change operator", errors)
            require(isinstance(change.get("path"), str) and change["path"], "CONTENT_INVALID",
                    f"{change_path}.path", "path must be non-empty", errors)
        for fact_index, fact in enumerate(rule.get("facts") or []):
            fact_path = f"{path}.facts[{fact_index}]"
            require(isinstance(fact, dict), "CONTENT_INVALID", fact_path, "fact must be an object", errors)
            require(isinstance(fact.get("id"), str) and fact["id"], "CONTENT_INVALID", f"{fact_path}.id",
                    "fact id must be non-empty", errors)

    for index, rating in enumerate(ratings):
        path = f"orderRatings[{index}]"
        require(isinstance(rating.get("ratingSetId"), str) and rating["ratingSetId"], "CONTENT_INVALID",
                f"{path}.ratingSetId", "ratingSetId must be non-empty", errors)
        require(is_int(rating.get("stars")) and 1 <= int(rating["stars"]) <= 3, "CONTENT_INVALID",
                f"{path}.stars", "stars must be 1..3", errors)
        require(isinstance(rating.get("feedback"), str) and rating["feedback"], "CONTENT_INVALID",
                f"{path}.feedback", "feedback must be non-empty", errors)
        for field in ("requiresFacts", "excludesFacts"):
            for ref_index, value in enumerate(rating.get(field) or []):
                require(isinstance(value, str) and value, "CONTENT_INVALID", f"{path}.{field}[{ref_index}]",
                        "fact id must be non-empty", errors)

    for index, profile in enumerate(collections.get("attributeProfiles", [])):
        path = f"attributeProfiles[{index}]"
        for field in ("baseDurationHours", "durationHoursPerPoint", "recoveryAfterEndHours"):
            require(isinstance(profile.get(field), (int, float)), "CONTENT_INVALID", f"{path}.{field}",
                    "must be a finite number", errors)
        for ref_index, row in enumerate(profile.get("speedToDelayHours") or []):
            require(isinstance(row, dict), "CONTENT_INVALID", f"{path}.speedToDelayHours[{ref_index}]",
                    "must be an object", errors)
        for rule_index, rule in enumerate(profile.get("residualRules") or []):
            rule_path = f"{path}.residualRules[{rule_index}]"
            require(rule.get("effectId") in effects, "UNKNOWN_REF", f"{rule_path}.effectId",
                    f"unknown effect {rule.get('effectId')}", errors)
            points = as_list(rule.get("points"), "CONTENT_INVALID", f"{rule_path}.points", errors)
            require(len(points) > 0, "CONTENT_INVALID", f"{rule_path}.points", "points must not be empty", errors)

    stage1 = as_dict(catalog.get("stage1"), "CONTENT_INVALID", "stage1", errors)
    economy = as_dict(stage1.get("initialEconomy"), "CONTENT_INVALID", "stage1.initialEconomy", errors)
    require(is_int(economy.get("currency")) and int(economy["currency"]) >= 0, "CONTENT_INVALID",
            "stage1.initialEconomy.currency", "currency must be a non-negative integer", errors)
    for ingredient_id in (economy.get("ingredients") or {}):
        require(ingredient_id in ingredients, "UNKNOWN_REF", f"stage1.initialEconomy.ingredients.{ingredient_id}",
                f"unknown ingredient {ingredient_id}", errors)
    require(stage1.get("initialEquipmentId") in equipment, "UNKNOWN_REF", "stage1.initialEquipmentId",
            f"unknown equipment {stage1.get('initialEquipmentId')}", errors)
    policy = as_dict(stage1.get("recipePolicy"), "CONTENT_INVALID", "stage1.recipePolicy", errors)
    for key in ("repeatIngredient", "repeatWordDefinition"):
        require(isinstance(policy.get(key), bool), "CONTENT_INVALID", f"stage1.recipePolicy.{key}",
                "must be boolean", errors)
    for case_index, case in enumerate(as_list(stage1.get("sampleCases"), "CONTENT_INVALID",
                                             "stage1.sampleCases", errors)):
        recipe_refs(case.get("recipe") or {}, f"stage1.sampleCases[{case_index}].recipe",
                    words, ingredients, equipment, None, errors)
        expect = as_dict(case.get("expect"), "CONTENT_INVALID",
                         f"stage1.sampleCases[{case_index}].expect", errors)
        for field in ("failures", "sideEffects", "followupFragments"):
            require(isinstance(expect.get(field), list), "CONTENT_INVALID",
                    f"stage1.sampleCases[{case_index}].expect.{field}", "must be an array", errors)

    for index, recipe in enumerate(recipes):
        recipe_refs(recipe.get("recipe") or {}, f"recipes[{index}].recipe", words, ingredients, equipment,
                    None, errors)
        require(recipe.get("letterId") in letters, "UNKNOWN_REF", f"recipes[{index}].letterId",
                f"unknown letter {recipe.get('letterId')}", errors)

    release = as_dict(catalog.get("release"), "CONTENT_INVALID", "release", errors)
    required_orders = as_list(release.get("requiredOrderIds"), "CONTENT_INVALID",
                              "release.requiredOrderIds", errors)
    require(len(required_orders) == expected.get("requiredOrders", len(required_orders)),
            "CONTENT_COUNT_MISMATCH", "release.requiredOrderIds",
            f"expected {expected.get('requiredOrders')}, got {len(required_orders)}", errors)
    letter_rows = {row.get("id"): row for row in collections.get("letters", []) if isinstance(row, dict)}
    for index, letter_id in enumerate(required_orders):
        require(letter_id in letters, "UNKNOWN_REF", f"release.requiredOrderIds[{index}]",
                f"unknown letter {letter_id}", errors)
        require(letter_rows.get(letter_id, {}).get("kind") == "order", "CONTENT_INVALID",
                f"release.requiredOrderIds[{index}]", "required order must reference an order letter", errors)
    home_items = as_list(release.get("homeItems"), "CONTENT_INVALID", "release.homeItems", errors)
    require(len(home_items) == expected.get("homeItems", len(home_items)), "CONTENT_COUNT_MISMATCH",
            "release.homeItems", f"expected {expected.get('homeItems')}, got {len(home_items)}", errors)
    furniture = id_set(as_list(collections.get("furniture", []), "CONTENT_INVALID", "furniture", errors),
                       "furniture", errors)
    for index, item in enumerate(home_items):
        require(item.get("id") in furniture, "UNKNOWN_REF", f"release.homeItems[{index}].id",
                f"unknown furniture {item.get('id')}", errors)
    ticket = as_dict(release.get("ticket"), "CONTENT_INVALID", "release.ticket", errors)
    for field in ("id", "price", "offerStartDay", "lastPurchaseDay"):
        require(ticket.get(field) is not None, "CONTENT_INVALID", f"release.ticket.{field}",
                "missing ticket field", errors)
    require(is_int(release.get("minThreeStarOrders")) and 0 <= int(release["minThreeStarOrders"])
            <= len(required_orders), "CONTENT_INVALID", "release.minThreeStarOrders",
            "must be between 0 and required order count", errors)

    endings = as_dict(catalog.get("releaseEndings"), "CONTENT_INVALID", "releaseEndings", errors)
    for kind in ("departure", "apprentice", "wish"):
        row = as_dict(endings.get(kind), "CONTENT_INVALID", f"releaseEndings.{kind}", errors)
        require(isinstance(row.get("title"), str) and row["title"], "CONTENT_INVALID",
                f"releaseEndings.{kind}.title", "title must be non-empty", errors)
        require(isinstance(row.get("text"), str) and row["text"], "CONTENT_INVALID",
                f"releaseEndings.{kind}.text", "text must be non-empty", errors)

    synthesis = as_dict(catalog.get("synthesis"), "CONTENT_INVALID", "synthesis", errors)
    tiers = as_list(synthesis.get("intensityTiers"), "CONTENT_INVALID", "synthesis.intensityTiers", errors)
    previous = -1e30
    for index, tier in enumerate(tiers):
        require(isinstance(tier, dict) and isinstance(tier.get("max"), (int, float))
                and tier["max"] > previous, "CONTENT_INVALID", f"synthesis.intensityTiers[{index}]",
                "tier max must strictly increase", errors)
        previous = tier.get("max", previous)
    for index, rule in enumerate(as_list(synthesis.get("sideEffectRules"), "CONTENT_INVALID",
                                         "synthesis.sideEffectRules", errors)):
        require(isinstance(rule, dict), "CONTENT_INVALID", f"synthesis.sideEffectRules[{index}]",
                "rule must be an object", errors)
        for effect_id in (rule.get("addTags") or {}):
            require(effect_id in effects, "UNKNOWN_REF", f"synthesis.sideEffectRules[{index}].addTags.{effect_id}",
                    f"unknown effect {effect_id}", errors)

    gameplay = as_dict(catalog.get("gameplay"), "CONTENT_INVALID", "gameplay", errors)
    require(is_int(gameplay.get("salvageDailyLimit")) and int(gameplay["salvageDailyLimit"]) >= 1,
            "CONTENT_INVALID", "gameplay.salvageDailyLimit", "must be a positive integer", errors)
    shop = as_dict(catalog.get("shop"), "CONTENT_INVALID", "shop", errors)
    require(is_int(shop.get("dailyStockPerIngredient")) and int(shop["dailyStockPerIngredient"]) >= 1,
            "CONTENT_INVALID", "shop.dailyStockPerIngredient", "must be a positive integer", errors)

    for index, row in enumerate(wish):
        path = f"wishDecorations[{index}]"
        require(isinstance(row.get("path"), str) and row["path"], "CONTENT_INVALID", f"{path}.path",
                "path must be non-empty", errors)
        if isinstance(row.get("path"), str):
            require((ROOT / "assets" / row["path"]).exists(), "ASSET_MISSING", f"{path}.path",
                    f"missing asset {row['path']}", errors)

    span_map = as_dict(catalog.get("letterSpans"), "CONTENT_INVALID", "letterSpans", errors)
    for letter in collections.get("letters", []):
        if not isinstance(letter, dict) or letter.get("kind") != "order":
            continue
        letter_id = letter.get("id")
        require(letter_id in span_map, "CONTENT_MISSING", f"letterSpans.{letter_id}",
                "order letter has no parsed spans", errors)
        span_words = {
            span.get("wordId") for span in (span_map.get(letter_id, {}).get("spans", [])
                                            if isinstance(span_map.get(letter_id), dict) else [])
            if isinstance(span, dict)
        }
        for index, word_id in enumerate(letter.get("cutWordIds") or []):
            require(word_id in span_words, "SPAN_MISSING", f"letterSpans.{letter_id}.spans",
                    f"cut word {word_id} is not present in parsed spans", errors)
    for letter_id, parsed in span_map.items():
        require(letter_id in letters, "UNKNOWN_REF", f"letterSpans.{letter_id}",
                f"unknown letter {letter_id}", errors)
        spans = as_list(as_dict(parsed, "CONTENT_INVALID", f"letterSpans.{letter_id}", errors).get("spans"),
                        "CONTENT_INVALID", f"letterSpans.{letter_id}.spans", errors)
        for index, span in enumerate(spans):
            path = f"letterSpans.{letter_id}.spans[{index}]"
            require(isinstance(span, dict), "CONTENT_INVALID", path, "span must be an object", errors)
            require(isinstance(span.get("spanId"), str) and span["spanId"], "CONTENT_INVALID",
                    f"{path}.spanId", "spanId must be non-empty", errors)
            require(span.get("wordId") in words, "UNKNOWN_REF", f"{path}.wordId",
                    f"unknown word {span.get('wordId')}", errors)
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--schema", default=str(DEFAULT_SCHEMA))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--fixtures", default=str(DEFAULT_FIXTURES))
    parser.add_argument("--python-libs", default=str(DEFAULT_PYTHON_LIBS))
    parser.add_argument("--check", action="store_true", help="verify the committed catalog is current")
    args = parser.parse_args()

    schema = json.loads(Path(args.schema).read_text(encoding="utf-8"))
    array_fields = set(schema.get("empty_array_fields", []))
    object_fields = set(schema.get("empty_object_fields", []))
    lua = load_lua(Path(args.python_libs))
    raw = build_raw(lua)

    converted = {}
    for key, value in raw.items():
        converted[key] = convert(value, key, array_fields, object_fields)
    collections = {
        name: converted.pop(name)
        for name in schema.get("collections", {})
    }
    counts = {name: len(rows) for name, rows in collections.items()}
    counts["wishDecorations"] = len(collections["wishDecorations"])
    counts["requiredOrders"] = len(converted["release"]["requiredOrderIds"])
    counts["homeItems"] = len(converted["release"]["homeItems"])
    counts["sampleCases"] = len(converted["stage1"]["sampleCases"])
    converted["counts"] = counts
    converted["collections"] = collections
    converted["schema_version"] = 1
    source_files, source_hash = source_inventory()
    converted["source_files"] = source_files
    converted["source_hash"] = source_hash

    errors = validate_catalog(converted, schema)
    if errors:
        for error in errors[:50]:
            print(f"{error['code']} {error['path']}: {error['message']}", file=sys.stderr)
        if len(errors) > 50:
            print(f"... {len(errors) - 50} more", file=sys.stderr)
        return 1

    text = json.dumps(converted, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    text_hashes = {}
    span_counts = {}
    for letter in converted["collections"]["letters"]:
        if letter.get("kind") != "order":
            continue
        letter_id = letter["id"]
        text_hashes[letter_id] = {
            "title_sha256": sha256_bytes(str(letter.get("title", "")).encode("utf-8")),
            "body_sha256": sha256_bytes(str(letter.get("body", "")).encode("utf-8")),
        }
        span_counts[letter_id] = len(converted["letterSpans"].get(letter_id, {}).get("spans", []))
    fixture = {
        "schema_version": 1,
        "content_version": converted["contentVersion"],
        "source_hash": source_hash,
        "counts": {name: converted["counts"][name] for name in schema.get("expected_counts", {})},
        "text_hashes": text_hashes,
        "span_counts": span_counts,
    }
    fixture_text = json.dumps(fixture, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    output = Path(args.output)
    fixture_path = Path(args.fixtures)
    if args.check:
        for path, expected in ((output, text), (fixture_path, fixture_text)):
            if not path.exists():
                print(f"missing generated file: {path}", file=sys.stderr)
                return 1
            if path.read_text(encoding="utf-8") != expected:
                print(f"out of date: {path}; run export_content.py", file=sys.stderr)
                return 1
        print(f"catalog check passed: {output.relative_to(ROOT).as_posix()}")
        return 0
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text, encoding="utf-8")
    fixture_path.parent.mkdir(parents=True, exist_ok=True)
    fixture_path.write_text(fixture_text, encoding="utf-8")
    print(f"catalog written: {output.relative_to(ROOT).as_posix()}")
    print(f"content_version={converted['contentVersion']} source_hash={source_hash[:16]}...")
    for name in ("effects", "words", "ingredients", "equipment", "npcs", "letters",
                 "attributeProfiles", "followupTemplates", "fragments", "directRules",
                 "orderRatings", "recipes", "wishDecorations"):
        print(f"{name}: {counts[name]}")
    print(f"requiredOrders: {counts['requiredOrders']} homeItems: {counts['homeItems']} "
          f"sampleCases: {counts['sampleCases']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
