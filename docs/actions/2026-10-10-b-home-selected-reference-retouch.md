# B 选定横屏主页细修行动记录

## Status and situation

Status: Completed. Source request: 2026-10-10 B-window handoff. Scope was limited to a non-destructive visual candidate based on the user-selected `docs/设计/原型/home-indoor-dock-threshold-v01.png` (1672×941): remove the fixed calendar number, add continuous but unreadable decorative handwriting to the tabletop letter, and place one naturally opened message bottle with its cork nearby. The selected room, left open door, single threshold, dock, sea, distant small European sailboat, right table, net, shelf, and all existing scale/perspective were invariants.

Confirmed exclusions: no frontend/Lua/business changes, no drawer opening frames or animation, no new gameplay, no production asset extraction in this pass, no replacement of the selected overall composition, and no baking dynamic date, balances, readable letter text, or stars into the image. The project is at `e4d2862`; pre-existing uncommitted workspace changes are out of scope.

## Implementation measures

1. Inspect the selected reference and current landscape/interface documents; use the reference as the only edit target.
2. Create one versioned full-scene retouch using the built-in image editor, preserving the 1672×941 canvas if the tool permits.
3. Visually inspect composition invariants and the three requested edits; check saved artifact format, dimensions, and source/output hashes.
4. Record actual output, verification results, limitations, and the recommended handoff boundary.

Completion criteria: one new versioned opaque PNG under `scripts/素材`, no change to the selected source or code, all three requested visual changes present, and no readable narrative/text or calendar numeral.

## Affected file tree

```text
docs/actions/2026-10-10-b-home-selected-reference-retouch.md  This trace record; records scope and actual evidence.
scripts/素材/主页效果_横屏室内门槛_细修_v01.png             New full-scene review candidate; opaque and not a runtime layer.
```

The scene candidate remains an opaque composition review artifact. It is upstream of later clean-background and independently anchored RGBA layer work; no implementation module consumes it in this action.

## Self-verification method

1. Open the source and final image for visual comparison: preserve 16:9 framing, door/dock relation, right-side table, net visibility, and distant sailboat.
2. Check the calendar face has no static numeral; letter marks look like continuous, perspective-following handwriting but cannot be read; opened bottle and cork are clear without covering the letter, tray, journal, calendar, or jars.
3. Inspect final PNG existence, dimensions, color mode, and hash. Review Git path status to confirm no code or source-reference mutation.

## Self-verification results

1. Built-in image editor used with `home-indoor-dock-threshold-v01.png` as the only edit target. The complete edited candidate was saved non-destructively as `scripts/素材/主页效果_横屏室内门槛_细修_v01.png`.
2. Visual inspection of the output: the calendar face has no fixed numeral; the tabletop letter has multiple low-contrast, continuous perspective-following lines without intended readable story text; one horizontal opened green-blue glass message bottle and a separate cork sit immediately right of the letter, above the green journal, without covering the letter, tray, journal, calendar, jars, or cauldron. The door, one-step threshold, dock, net, right-side table, and distant sailboat remain in the same composition.
3. Output inspection: PNG, 1672×941, RGB / opaque, 2,767,011 bytes, SHA-256 `6E0D85D4CCFCC02416B3721F788E4779D2B99C8933D782479FB53D8BE89D9BB8`. Source remains present and separate, SHA-256 `2114563326777C57D2F1A60C8CE64B988653A22B0073274EF91CFABAB95D6D23`; the output canvas therefore matches the selected reference without stretching.
4. Scope check: Git reports only this new candidate and this action document on the paths touched in this action; no Lua, layout, interface, or selected-reference file was changed.

Limitations: image editing lightly re-rendered scene brush detail outside the three edits, so this candidate is for visual approval only. It is intentionally an opaque RGB scene rather than a clean-background or transparent-layer delivery. It has not been tested in the game, editor, or on a phone.
