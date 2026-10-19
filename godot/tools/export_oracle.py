"""Export deterministic Lua oracle cases for the Godot domain layer.

The Lua project is executed through Lupa; inputs are built from the generated
catalog and outputs are normalized into JSON. Godot parity tests replay the
same inputs and compare the expected values.

Run from the repository root:
    python godot/tools/export_oracle.py
    python godot/tools/export_oracle.py --check
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = Path(__file__).resolve().parents[1]
DEFAULT_CATALOG = PROJECT / "content" / "generated" / "catalog.json"
DEFAULT_OUTPUT = PROJECT / "tests" / "fixtures" / "oracle_cases.json"
DEFAULT_PYTHON_LIBS = ROOT / ".tmp" / "b1-python"

sys.path.insert(0, str(Path(__file__).resolve().parent))
import export_content  # noqa: E402


def to_lua(value, runtime):
    if isinstance(value, dict):
        return runtime.table_from({str(key): to_lua(item, runtime) for key, item in value.items()})
    if isinstance(value, list):
        return runtime.table_from([to_lua(item, runtime) for item in value])
    return value


def result_error(result) -> dict:
    error = result["error"] if not bool(result["ok"]) else None
    if error is None:
        return {"code": "UNKNOWN", "path": "", "message": ""}
    return {
        "code": str(error["code"]),
        "path": str(error["path"]),
        "message": str(error["message"]),
    }


def normalize_potion(result, empty_arrays: set, empty_objects: set) -> dict:
    if not bool(result["ok"]):
        return {"ok": False, "error": result_error(result)}
    value = result["value"]
    return {
        "ok": True,
        "value": {
            "synthesisVersion": value["synthesisVersion"],
            "contentVersion": str(value["contentVersion"]),
            "effects": export_content.convert(value["effects"], "effects", empty_arrays, empty_objects),
            "intensityByEffect": export_content.convert(value["intensityByEffect"], "intensityByEffect",
                                                       empty_arrays, empty_objects),
            "mods": export_content.convert(value["mods"], "mods", empty_arrays, empty_objects),
            "durationHours": value["durationHours"],
            "onsetDelayHours": value["onsetDelayHours"],
            "recoveryAfterEndHours": value["recoveryAfterEndHours"],
            "residuals": export_content.convert(value["residuals"], "residuals", empty_arrays, empty_objects),
            "stability": value["stability"],
            "unstable": bool(value["unstable"]),
            "sideEffects": export_content.convert(value["sideEffects"], "sideEffects", empty_arrays, empty_objects),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", default=str(DEFAULT_CATALOG))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--python-libs", default=str(DEFAULT_PYTHON_LIBS))
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    catalog = json.loads(Path(args.catalog).read_text(encoding="utf-8"))
    collections = catalog["collections"]
    words = {row["id"]: row for row in collections["words"]}
    ingredients = {row["id"]: row for row in collections["ingredients"]}
    equipment = {row["id"]: row for row in collections["equipment"]}
    letters = {row["id"]: row for row in collections["letters"]}
    release = catalog["release"]
    letter_id = "letter_pa_01"
    sender_id = letters[letter_id]["senderId"]
    initial_equipment = catalog["stage1"]["initialEquipmentId"]

    lua = export_content.load_lua(Path(args.python_libs))
    data = export_content.unwrap(lua.eval('require("data.content")'))
    ok, errors = export_content.call_pair(data.Load, "data.content.Load")
    if not ok:
        raise SystemExit(f"content load failed: {errors}")
    potion = export_content.unwrap(lua.eval('require("systems.Potion")'))
    word_token = export_content.unwrap(lua.eval('require("systems.WordToken").New(require("data.content"))'))
    draft_module = export_content.unwrap(lua.eval('require("systems.RecipeDraft")'))
    state_util = export_content.unwrap(lua.eval('require("core.StateUtil")'))

    empty_arrays = {"residuals", "sideEffects", "sideEffects[].addTags", "trace", "trace[].sourceIds"}
    empty_objects = {"effects", "intensityByEffect", "mods", "sideEffects[].addTags"}

    def word_ref(word_id: str, token_id: str, span_id: str) -> dict:
        return {
            "tokenId": token_id,
            "definition": words[word_id],
            "source": {
                "wordId": word_id,
                "sourceLetterInstanceId": "letter:" + letter_id,
                "sourceSpanId": span_id,
                "sourceNpcId": sender_id,
            },
        }

    def ingredient_rows(rows: list[dict]) -> list[dict]:
        return [
            {
                "ingredientId": row["ingredientId"],
                "quantity": row["quantity"],
                "definition": ingredients[row["ingredientId"]],
            }
            for row in rows
        ]

    def resolved(main_word_id: str, aux_word_ids: list[str], ingredient_values: list[dict],
                 equipment_id: str = initial_equipment) -> dict:
        aux = [word_ref(word_id, "oracle:aux:%d" % index, "fixture:aux:%d" % index)
               for index, word_id in enumerate(aux_word_ids)]
        return {
            "orderId": "oracle",
            "baselineId": "oracle:baseline",
            "contentVersion": catalog["contentVersion"],
            "equipment": equipment[equipment_id],
            "main": word_ref(main_word_id, "oracle:main", "fixture:main"),
            "aux": aux,
            "ingredients": ingredient_rows(ingredient_values),
            "specialItems": [],
        }

    potion_cases: list[dict] = []
    seen_ids: set[str] = set()

    def add_potion(case_id: str, recipe: dict) -> None:
        if case_id in seen_ids:
            return
        seen_ids.add(case_id)
        result = potion.Calculate(to_lua(recipe, lua), data)
        potion_cases.append({
            "id": case_id,
            "recipe": {
                "mainWordId": recipe["main"]["definition"]["id"],
                "auxWordIds": [row["definition"]["id"] for row in recipe["aux"]],
                "ingredients": [{"ingredientId": row["ingredientId"], "quantity": row["quantity"]}
                                for row in recipe["ingredients"]],
                "equipmentId": recipe["equipment"]["id"],
            },
            "expected": normalize_potion(result, empty_arrays, empty_objects),
        })

    for index, case in enumerate(catalog["stage1"]["sampleCases"]):
        recipe = case["recipe"]
        add_potion("sample_%02d_%s" % (index + 1, case["id"]),
                   resolved(recipe["mainWordId"], recipe.get("auxWordIds", []),
                            recipe.get("ingredients", []), recipe["equipmentId"]))

    for word_id in words:
        add_potion("main_%s" % word_id, resolved(word_id, [], []))

    main_word = "word_candidate_elias_sleep"
    for ingredient_id in ingredients:
        add_potion("ing_%s_x1" % ingredient_id,
                   resolved(main_word, [], [{"ingredientId": ingredient_id, "quantity": 1}]))
        add_potion("ing_%s_x2" % ingredient_id,
                   resolved(main_word, [], [{"ingredientId": ingredient_id, "quantity": 2}]))
    add_potion("ing_combo_night_dew_dried_petal", resolved(main_word, [], [
        {"ingredientId": "ing_night_dew", "quantity": 1},
        {"ingredientId": "ing_dried_petal", "quantity": 1},
    ]))
    add_potion("ing_combo_ashen_herb_x2", resolved(main_word, [], [
        {"ingredientId": "ing_ashen_herb", "quantity": 2},
    ]))

    aux_candidates = [
        word_id for word_id in words
        if word_id != main_word and "attributeProfileId" in words[word_id]
        and words[word_id].get("effects")
    ][:12]
    for index, aux_word_id in enumerate(aux_candidates):
        add_potion("aux_%02d_%s" % (index + 1, aux_word_id),
                   resolved(main_word, [aux_word_id], []))
        if index + 1 < len(aux_candidates):
            add_potion("aux_%02d_pair_%s" % (index + 1, aux_candidates[index + 1]),
                       resolved(main_word, [aux_word_id, aux_candidates[index + 1]], []))

    residual_recipe = resolved(main_word, [], [])
    residual_result = potion.Calculate(to_lua(residual_recipe, lua), data)
    if not bool(residual_result["ok"]):
        raise SystemExit("residual base potion failed: " + str(result_error(residual_result)))
    residual_potion = residual_result["value"]
    sleep_points = [
        residual_potion["residuals"][index]
        for index in range(1, len(residual_potion["residuals"]) + 1)
        if residual_potion["residuals"][index]["effectId"] == "sleep"
    ]
    residual_samples: list[dict] = []

    def add_residual_sample(case_id: str, at: float) -> None:
        sampled = potion.SampleResidual(residual_potion, "sleep", at, data)
        expected = {"ok": True, "value": sampled["value"]} if bool(sampled["ok"]) else {
            "ok": False, "error": result_error(sampled)}
        residual_samples.append({"id": case_id, "at": at, "expected": expected})

    for point_index, point in enumerate(sleep_points):
        at = float(point["untilAfterDoseHours"])
        add_residual_sample("point_%d_exact" % (point_index + 1), at)
        add_residual_sample("point_%d_minus" % (point_index + 1), at - 0.000001)
        add_residual_sample("point_%d_plus" % (point_index + 1), at + 0.000001)
    if len(sleep_points) >= 2:
        add_residual_sample("between_first_second",
                            (float(sleep_points[0]["untilAfterDoseHours"])
                             + float(sleep_points[1]["untilAfterDoseHours"])) / 2.0)
    add_residual_sample("before_first", float(sleep_points[0]["untilAfterDoseHours"]) - 0.5)
    add_residual_sample("after_last", float(sleep_points[-1]["untilAfterDoseHours"]) + 0.5)
    modified_potion = state_util.Copy(residual_potion)
    first_sleep_index = next(
        index for index in range(1, len(modified_potion["residuals"]) + 1)
        if modified_potion["residuals"][index]["effectId"] == "sleep"
    )
    modified_potion["residuals"][first_sleep_index]["untilAfterDoseHours"] = (
        float(modified_potion["residuals"][first_sleep_index]["untilAfterDoseHours"]) + 0.000001
    )
    modified_result = potion.ValidateResult(modified_potion, data)
    residual_cases = {
        "recipe": {
            "mainWordId": main_word,
            "auxWordIds": [],
            "ingredients": [],
            "equipmentId": initial_equipment,
        },
        "effect_id": "sleep",
        "samples": residual_samples,
        "modified_expected": {
            "ok": bool(modified_result["ok"]),
            "error": result_error(modified_result) if not bool(modified_result["ok"]) else {},
        },
    }

    token_cases: list[dict] = []
    token_state = export_content.unwrap(lua.eval('{byId = {}}'))
    for letter in collections["letters"]:
        if letter.get("kind") != "order":
            continue
        for span in catalog["letterSpans"][letter["id"]]["spans"]:
            source = {
                "wordId": span["wordId"],
                "sourceLetterInstanceId": "letter:" + letter["id"],
                "sourceSpanId": span["spanId"],
                "sourceNpcId": letter["senderId"],
            }
            result = word_token.PlanCut(token_state, to_lua(source, lua))
            token_cases.append({
                "id": "valid_%s_%s" % (letter["id"], span["spanId"]),
                "source": source,
                "expected": {
                    "ok": bool(result["ok"]),
                    "tokenId": str(result["value"]["tokenId"]) if bool(result["ok"]) else "",
                    "error": result_error(result) if not bool(result["ok"]) else {},
                },
            })
    first_letter = letters[letter_id]
    first_span = catalog["letterSpans"][letter_id]["spans"][0]
    invalid_sources = [
        {
            "id": "wrong_word",
            "source": {
                "wordId": "word_candidate_elias_trust",
                "sourceLetterInstanceId": "letter:" + letter_id,
                "sourceSpanId": first_span["spanId"],
                "sourceNpcId": first_letter["senderId"],
            },
        },
        {
            "id": "wrong_sender",
            "source": {
                "wordId": first_span["wordId"],
                "sourceLetterInstanceId": "letter:" + letter_id,
                "sourceSpanId": first_span["spanId"],
                "sourceNpcId": "npc_unknown",
            },
        },
        {
            "id": "unknown_letter",
            "source": {
                "wordId": first_span["wordId"],
                "sourceLetterInstanceId": "letter:missing_letter",
                "sourceSpanId": first_span["spanId"],
                "sourceNpcId": first_letter["senderId"],
            },
        },
    ]
    for case in invalid_sources:
        result = word_token.PlanCut(token_state, to_lua(case["source"], lua))
        token_cases.append({
            "id": case["id"],
            "source": case["source"],
            "expected": {
                "ok": bool(result["ok"]),
                "tokenId": "",
                "error": result_error(result),
            },
        })

    initial_economy = catalog["stage1"]["initialEconomy"]
    live = {
        "economy": {
            "currency": initial_economy["currency"],
            "ingredients": initial_economy["ingredients"],
            "specialItems": [],
            "ownedEquipmentIds": {initial_equipment: True},
            "shopPurchases": [],
            "itemPurchases": [],
        },
        "wordTokens": {"byId": {}},
    }
    for span in catalog["letterSpans"][letter_id]["spans"]:
        source = {
            "wordId": span["wordId"],
            "sourceLetterInstanceId": "letter:" + letter_id,
            "sourceSpanId": span["spanId"],
            "sourceNpcId": first_letter["senderId"],
        }
        cut = word_token.PlanCut(to_lua(live["wordTokens"], lua), to_lua(source, lua))
        live["wordTokens"] = export_content.convert(cut["value"]["state"], "wordTokens", set(), set())
    token_ids = sorted(live["wordTokens"]["byId"])

    base_draft = {
        "equipmentId": initial_equipment,
        "mainTokenId": False,
        "auxTokenIds": [],
        "ingredients": [],
        "specialItemIds": [],
    }
    drafts = {
        "empty": base_draft,
        "main_only": {**base_draft, "mainTokenId": token_ids[0]},
        "main_aux": {**base_draft, "mainTokenId": token_ids[0], "auxTokenIds": [token_ids[1]]},
        "duplicate_token": {**base_draft, "mainTokenId": token_ids[0], "auxTokenIds": [token_ids[0]]},
        "unknown_token": {**base_draft, "mainTokenId": "token:missing"},
        "inventory_short": {**base_draft, "mainTokenId": token_ids[0],
                            "ingredients": [{"ingredientId": "ing_night_dew", "quantity": 99}]},
        "aux_slot_overflow": {**base_draft, "mainTokenId": token_ids[0],
                              "auxTokenIds": token_ids[1:4]},
        "duplicate_ingredient_rows": {**base_draft, "mainTokenId": token_ids[0],
                                      "ingredients": [
                                          {"ingredientId": "ing_night_dew", "quantity": 1},
                                          {"ingredientId": "ing_night_dew", "quantity": 1},
                                      ]},
    }
    draft_cases: list[dict] = []
    for case_id, draft in drafts.items():
        result = draft_module.Validate(to_lua(draft, lua), to_lua(live, lua), data)
        draft_cases.append({
            "id": case_id,
            "draft": draft,
            "expected": {
                "ok": bool(result["ok"]),
                "error": result_error(result) if not bool(result["ok"]) else {},
            },
        })

    fixture = {
        "schema_version": 1,
        "content_version": catalog["contentVersion"],
        "source_hash": catalog["source_hash"],
        "potion_cases": potion_cases,
        "residual_cases": residual_cases,
        "token_cases": token_cases,
        "draft_cases": draft_cases,
        "draft_live": live,
    }
    text = json.dumps(fixture, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    output = Path(args.output)
    if args.check:
        if not output.exists() or output.read_text(encoding="utf-8") != text:
            print(f"out of date: {output}; run export_oracle.py", file=sys.stderr)
            return 1
        print(f"oracle check passed: {output.relative_to(ROOT).as_posix()}")
        return 0
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text, encoding="utf-8")
    print(f"oracle written: {output.relative_to(ROOT).as_posix()}")
    print(f"potion_cases={len(potion_cases)} residual_samples={len(residual_samples)} "
          f"token_cases={len(token_cases)} draft_cases={len(draft_cases)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
