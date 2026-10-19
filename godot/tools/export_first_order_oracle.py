"""Export the frozen real first-order trajectory from the Lua production session.

The driver uses the real GameSession/GameState/OrderTrial modules and the
existing B5 fixture's isolated save protocol. It records every production step,
the full business snapshot, the query projection, write count and event names.

Run from the repository root:
    python godot/tools/export_first_order_oracle.py
    python godot/tools/export_first_order_oracle.py --check
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = PROJECT / "tests" / "fixtures" / "first_order"
DEFAULT_PYTHON_LIBS = ROOT / ".tmp" / "b1-python"
REQUIRED_RECIPES = [f"recipe_v02_e01_{index}" for index in range(1, 9)]

sys.path.insert(0, str(PROJECT / "tools"))
import export_content  # noqa: E402


LUA_DRIVER = r"""
local D=require "data.content"
assert(D.Load())
assert(D.ValidateStage1())
local F=require "debug.fixtures.B5Fixtures"
local Cases=require "debug.fixtures.NumericV02Cases"
local U=require "core.StateUtil"
local RecipeDraft=require "systems.RecipeDraft"
local Json=require "core.SaveJson"

local function must(result)
  if not result.ok then error(Json.Encode(result.error),0) end
  return result.value
end

local function event_names(x)
  local names={}
  for _,event in ipairs(x.events) do names[#names+1]=event.name end
  return names
end

local function step(x,id,result)
  return {id=id,result=result,snapshot=x.state.GetSnapshot(),writes=x.writes,events=event_names(x)}
end

local function collect(x,letterId,steps)
  local received=must(x.state.ReceiveLetter({letterId=letterId}))
  steps[#steps+1]=step(x,"receive",received)
  local read=must(x.state.ReadLetter({letterInstanceId=received.letterInstanceId}))
  steps[#steps+1]=step(x,"read",read)
  local tokens={}
  for _,span in ipairs(must(x.modules.letters.ParseDefinition(letterId)).spans) do
    local cut=must(x.state.CutWord({letterInstanceId=received.letterInstanceId,spanId=span.spanId}))
    assert(tokens[span.wordId]==nil,"首信每个登记词应有独立位置")
    tokens[span.wordId]=cut.tokenId
    steps[#steps+1]=step(x,"cut:"..span.spanId,cut)
  end
  return received.letterInstanceId,tokens
end

local function build_draft(tokens,recipe,orderId)
  local aux={}
  for _,wordId in ipairs(recipe.auxWordIds) do aux[#aux+1]=assert(tokens[wordId],wordId) end
  return {orderId=orderId,equipmentId=recipe.equipmentId,mainTokenId=assert(tokens[recipe.mainWordId]),
    auxTokenIds=aux,ingredients=U.Copy(recipe.ingredients),specialItemIds={}}
end

local function run_recipe(case)
  local x=F.New(D,{targetSchema=4})
  local steps={}
  local instance,tokens=collect(x,case.letterId,steps)
  local accepted=must(x.order.Accept({letterInstanceId=instance}))
  local orderId=accepted.orderId
  steps[#steps+1]=step(x,"accept",accepted)
  local draft=build_draft(tokens,case.recipe,orderId)
  local updated=must(x.order.UpdateDraft({orderId=orderId,draft=RecipeDraft.Project(draft)}))
  steps[#steps+1]=step(x,"draft",updated)
  local liveBefore=x.state.GetSnapshot().live
  local preview=must(x.order.Preview(draft))
  local pending=x.state.GetSnapshot().currentOrder.pending
  assert(pending and pending.transactionId==preview.transactionId)
  assert(U.Equal(x.state.GetSnapshot().live,liveBefore),"试做不能改变正式 live")
  steps[#steps+1]=step(x,"trial",preview)
  local baseline=x.state.GetSnapshot().currentOrder.baseline.id
  local reset=must(x.order.Reset({orderId=orderId,baselineId=baseline,transactionId=preview.transactionId}))
  steps[#steps+1]=step(x,"reset",reset)
  local updatedAgain=must(x.order.UpdateDraft({orderId=orderId,draft=RecipeDraft.Project(draft)}))
  steps[#steps+1]=step(x,"draft_after_reset",updatedAgain)
  local second=must(x.order.Preview(draft))
  local secondPending=x.state.GetSnapshot().currentOrder.pending
  assert(secondPending and secondPending.transactionId==second.transactionId)
  steps[#steps+1]=step(x,"retrial",second)
  local writesBeforeConfirm=x.writes
  local confirmed=must(x.order.Confirm({orderId=orderId,transactionId=second.transactionId}))
  steps[#steps+1]=step(x,"confirm",confirmed)
  local writesAfterConfirm=x.writes
  local duplicate=must(x.order.Confirm({orderId=orderId,transactionId=second.transactionId}))
  assert(duplicate.alreadyConfirmed)
  assert(x.writes==writesAfterConfirm,"重复确认不能再保存")
  steps[#steps+1]=step(x,"duplicate_confirm",duplicate)
  local loaded=assert(x.Reload())
  steps[#steps+1]=step(x,"reload",{ok=true,value={revision=x.state.GetSnapshot().revision}})
  local final=x.state.GetSnapshot()
  return {
    case_id=case.id,
    recipe_id=case.id,
    letter_id=case.letterId,
    expected=case.expect,
    steps=steps,
    final={
      deliveredOrders=final.live.gameFlow.deliveredOrders,
      currency=final.live.economy.currency,
      orderId=orderId,
      transactionId=second.transactionId,
      rating=secondPending.rating,
      followup=secondPending.followup,
      writesBeforeConfirm=writesBeforeConfirm,
      writesAfterConfirm=writesAfterConfirm,
    },
  }
end

local function accept_first(x,steps)
  local instance,tokens=collect(x,"letter_pa_01",steps)
  local accepted=must(x.order.Accept({letterInstanceId=instance}))
  steps[#steps+1]=step(x,"accept",accepted)
  return instance,tokens,accepted.orderId
end

local function run_failure(id,build)
  local x=F.New(D,{targetSchema=4})
  local steps={}
  local instance,tokens,orderId=accept_first(x,steps)
  local result=build(x,steps,instance,tokens,orderId)
  return {case_id=id,steps=steps,result=result}
end

local failures={}
local case1=nil
for _,case in ipairs(Cases) do
  if case.id=="recipe_v02_e01_1" then case1=case end
end
assert(case1,"missing first recipe")

failures[#failures+1]=run_failure("empty_main",function(x,steps,instance,tokens,orderId)
  local draft=build_draft(tokens,case1.recipe,orderId);draft.mainTokenId=false
  local update=must(x.order.UpdateDraft({orderId=orderId,draft=RecipeDraft.Project(draft)}))
  steps[#steps+1]=step(x,"draft_empty_main",update)
  local result=x.order.Preview(draft)
  steps[#steps+1]=step(x,"trial_empty_main",result)
  return result
end)

failures[#failures+1]=run_failure("main_effect_insufficient",function(x,steps,instance,tokens,orderId)
  local draft=build_draft(tokens,case1.recipe,orderId)
  draft.auxTokenIds={};draft.ingredients={};draft.specialItemIds={}
  must(x.order.UpdateDraft({orderId=orderId,draft=RecipeDraft.Project(draft)}))
  steps[#steps+1]=step(x,"draft_main_only",{ok=true,value={}})
  local result=x.order.Preview(draft)
  steps[#steps+1]=step(x,"trial_main_only",result)
  return result
end)

failures[#failures+1]=run_failure("duplicate_cut",function(x,steps,instance,tokens,orderId)
  local span=must(x.modules.letters.ParseDefinition("letter_pa_01")).spans[1]
  local again=x.state.CutWord({letterInstanceId=instance,spanId=span.spanId})
  steps[#steps+1]=step(x,"cut_duplicate",again)
  return again
end)

failures[#failures+1]=run_failure("stale_transaction",function(x,steps,instance,tokens,orderId)
  local draft=build_draft(tokens,case1.recipe,orderId)
  must(x.order.UpdateDraft({orderId=orderId,draft=RecipeDraft.Project(draft)}))
  local preview=must(x.order.Preview(draft))
  steps[#steps+1]=step(x,"trial",preview)
  local baseline=x.state.GetSnapshot().currentOrder.baseline.id
  must(x.order.Reset({orderId=orderId,baselineId=baseline,transactionId=preview.transactionId}))
  steps[#steps+1]=step(x,"reset",{ok=true,value={}})
  local result=x.order.Confirm({orderId=orderId,transactionId=preview.transactionId})
  steps[#steps+1]=step(x,"confirm_stale",result)
  return result
end)

failures[#failures+1]=run_failure("pending_change",function(x,steps,instance,tokens,orderId)
  local draft=build_draft(tokens,case1.recipe,orderId)
  must(x.order.UpdateDraft({orderId=orderId,draft=RecipeDraft.Project(draft)}))
  local preview=must(x.order.Preview(draft))
  steps[#steps+1]=step(x,"trial",preview)
  local changed=build_draft(tokens,case1.recipe,orderId);changed.auxTokenIds={}
  local result=x.order.UpdateDraft({orderId=orderId,draft=RecipeDraft.Project(changed)})
  steps[#steps+1]=step(x,"update_pending",result)
  return result
end)

failures[#failures+1]=run_failure("pending_cut",function(x,steps,instance,tokens,orderId)
  local draft=build_draft(tokens,case1.recipe,orderId)
  must(x.order.UpdateDraft({orderId=orderId,draft=RecipeDraft.Project(draft)}))
  local preview=must(x.order.Preview(draft))
  steps[#steps+1]=step(x,"trial",preview)
  local span=must(x.modules.letters.ParseDefinition("letter_pa_01")).spans[1]
  local result=x.state.CutWord({letterInstanceId=instance,spanId=span.spanId})
  steps[#steps+1]=step(x,"cut_pending",result)
  return result
end)

local recipes={}
for _,case in ipairs(Cases) do
  if case.id:match("^recipe_v02_e01_[1-8]$") then recipes[#recipes+1]=run_recipe(case) end
end
table.sort(recipes,function(a,b) return a.case_id<b.case_id end)
RESULT={recipes=recipes,failures=failures}
"""

ARRAY_KEYS = {
    "items", "values", "keys", "ids", "specialItems", "shopPurchases", "itemPurchases",
    "bottleQueue", "delayedQueue", "attemptIds", "wishDraftSourceIds", "auxTokenIds",
    "specialItemIds", "facts", "fragmentIds", "checks", "failures", "sideEffects",
    "residuals", "trace", "sourceIds", "consumedTokenIds", "factIds", "memories",
    "placements", "sourceTokenIds", "points", "conditions", "forbiddenEffects",
    "cutWordIds", "attachments", "requiresFacts", "excludesFacts", "coversFacts",
    "overrides", "fragmentIds", "speedToDelayHours", "residualRules", "intensityTiers",
    "values", "tagsList", "rules", "consumed", "rewards",
}
OBJECT_KEYS = {
    "byId", "directArchive", "flags", "unlockedLetterIds", "resolvedEventIds",
    "acceptedById", "confirmedById", "npcs", "ownedEquipmentIds", "effects",
    "intensityByEffect", "mods", "tags", "addTags", "inputs", "outputs", "details",
    "rating", "followup", "potion", "record", "requirementResult", "epilogue",
    "ending", "onboarding", "chapter", "baseline", "pending", "draft", "recipe",
    "world", "narrative", "orders", "letters", "economy", "gameFlow", "live",
    "currentOrder", "journal", "source", "definition", "equipment", "main",
    "reward", "requirement", "consumption", "candidateLive", "recipeDisplay",
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def source_inventory() -> tuple[list[dict], str]:
    paths = []
    for folder in ("core", "systems", "data"):
        paths.extend(sorted((ROOT / "scripts" / folder).rglob("*.lua")))
    for fixture in ("B5Fixtures.lua", "NumericV02Cases.lua"):
        paths.append(ROOT / "scripts" / "debug" / "fixtures" / fixture)
    rows = []
    for path in paths:
        rows.append({
            "path": path.relative_to(ROOT).as_posix(),
            "sha256": sha256_file(path),
            "bytes": path.stat().st_size,
        })
    material = "".join(f"{row['path']}:{row['sha256']}\n" for row in rows)
    return rows, hashlib.sha256(material.encode("utf-8")).hexdigest()


def convert_oracle(value, path: str = "traces"):
    if not hasattr(value, "keys"):
        return value
    keys = list(value.keys())
    if not keys:
        key = path.split(".")[-1].replace("[]", "")
        if key == "ingredients":
            return {} if ".economy." in f".{path}." else []
        if key in ARRAY_KEYS:
            return []
        return {}
    if all(isinstance(key, int) for key in keys):
        ordered = sorted(keys)
        if ordered != list(range(1, len(ordered) + 1)):
            raise RuntimeError("non-dense Lua array at " + path)
        return [convert_oracle(value[key], f"{path}[]") for key in ordered]
    if all(isinstance(key, str) for key in keys):
        return {key: convert_oracle(value[key], f"{path}.{key}") for key in sorted(keys)}
    raise RuntimeError("mixed Lua table keys at " + path)


def load_lua(python_libs: Path):
    return export_content.load_lua(python_libs)


def _from_lua(value):
    if hasattr(value, "keys"):
        keys = list(value.keys())
        if keys and all(isinstance(key, int) for key in keys):
            return [_from_lua(value[key]) for key in sorted(keys)]
        return {str(key): _from_lua(value[key]) for key in keys}
    return value


def _to_lua(value, lua):
    if isinstance(value, dict):
        return lua.table_from({str(key): _to_lua(item, lua) for key, item in value.items()})
    if isinstance(value, list):
        return lua.table_from([_to_lua(item, lua) for item in value])
    return value


def install_cjson(lua) -> None:
    lua.globals().cjson = lua.table_from({
        "encode": lambda value: json.dumps(_from_lua(value), ensure_ascii=False, allow_nan=False),
        "decode": lambda text: _to_lua(json.loads(text), lua),
    })


def build_trace(python_libs: Path) -> tuple[dict, dict]:
    lua = load_lua(python_libs)
    install_cjson(lua)
    lua.execute(LUA_DRIVER)
    raw = export_content.unwrap(lua.globals().RESULT)
    converted = convert_oracle(raw, "traces")
    source_files, source_hash = source_inventory()
    content_version = export_content.unwrap(lua.eval('require("data.content")')).contentVersion
    traces = {
        "schema_version": 1,
        "content_version": content_version,
        "source_hash": source_hash,
        "recipes": converted["recipes"],
        "failures": converted["failures"],
    }
    manifest = {
        "schema_version": 1,
        "content_version": content_version,
        "source_hash": source_hash,
        "source_files": source_files,
        "required_recipes": REQUIRED_RECIPES,
        "case_ids": [row["case_id"] for row in traces["recipes"]]
                    + [row["case_id"] for row in traces["failures"]],
    }
    return traces, manifest


def validate_bundle(traces: dict, manifest: dict) -> list[str]:
    errors: list[str] = []
    if int(traces.get("schema_version", 0)) != 1:
        errors.append("traces schema_version must be 1")
    if int(manifest.get("schema_version", 0)) != 1:
        errors.append("manifest schema_version must be 1")
    if traces.get("content_version") != manifest.get("content_version"):
        errors.append("content version mismatch")
    if traces.get("source_hash") != manifest.get("source_hash"):
        errors.append("source hash mismatch")
    recipes = traces.get("recipes", [])
    recipe_ids = {str(row.get("recipe_id")) for row in recipes}
    missing = [recipe_id for recipe_id in REQUIRED_RECIPES if recipe_id not in recipe_ids]
    if missing:
        errors.append("missing required recipes: " + ", ".join(missing))
    for row in recipes:
        case_id = str(row.get("case_id", ""))
        steps = row.get("steps", [])
        if len(steps) < 8:
            errors.append(f"{case_id}: too few steps ({len(steps)})")
        final = row.get("final", {})
        if int(final.get("deliveredOrders", -1)) != 1:
            errors.append(f"{case_id}: deliveredOrders must be 1")
        if not row.get("expected"):
            errors.append(f"{case_id}: expected is missing")
    failures = traces.get("failures", [])
    if not failures:
        errors.append("failure cases are missing")
    if not manifest.get("source_files"):
        errors.append("source_files are missing")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--python-libs", default=str(DEFAULT_PYTHON_LIBS))
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    output = Path(args.output)
    traces, manifest = build_trace(Path(args.python_libs))
    errors = validate_bundle(traces, manifest)
    if errors:
        for error in errors:
            print("FIRST_ORDER_ORACLE " + error, file=sys.stderr)
        return 1
    traces_text = json.dumps(traces, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    manifest_text = json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    traces_path = output / "traces.json"
    manifest_path = output / "manifest.json"
    if args.check:
        for path, expected in ((traces_path, traces_text), (manifest_path, manifest_text)):
            if not path.exists():
                print(f"missing fixture: {path}", file=sys.stderr)
                return 1
            if path.read_text(encoding="utf-8") != expected:
                print(f"out of date: {path}; run export_first_order_oracle.py", file=sys.stderr)
                return 1
        print(f"first-order oracle check passed: {output.relative_to(ROOT).as_posix()}")
        return 0
    output.mkdir(parents=True, exist_ok=True)
    traces_path.write_text(traces_text, encoding="utf-8")
    manifest_path.write_text(manifest_text, encoding="utf-8")
    print(f"first-order oracle written: {output.relative_to(ROOT).as_posix()}")
    print(f"recipes={len(traces['recipes'])} failures={len(traces['failures'])} "
          f"source_hash={traces['source_hash'][:16]}...")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
