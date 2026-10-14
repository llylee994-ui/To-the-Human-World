# v03.5 interface adapter — independent step

Pinned source: `llylee994-ui/To-the-Human-World` main `1cd0cdbec06487a5c60f109d5fd477198cfc8846`.
Dedicated task: `01a12c24-a725-712b-ba7d-df58430f5098`.

The current runtime host seam is `scripts/v035/lab35/Integration.lua`; `scripts/main.lua` installs `v035.lab35.FullSceneHost` with resources under `assets/v035-full`. The earlier procedural World is retired. Root `v035/scripts` retains legacy tests and some different core implementations; it is not the current runtime copy. Cloud Brew/Seaside integration exists, while Windows gameplay acceptance is tracked separately in [WINDOWS-RUN.md](WINDOWS-RUN.md). The clean candidate has been displayed in a real Windows window; the user is conducting the remaining interaction acceptance.

User confirmed all eight visual mappings. Green book opens 故事记录 (story and trial/recipe history); tied paper stack opens 案件板. `Ids.lua` reads exact labels/targets from pinned `LayoutManifest`, and eight actual hint labels are covered by regression tests. Other labels are 来信抽屉、分类词条、海边捕捞、商队商店、阅读信件、炼药工作区. Letter paper reads; no writing or separate diary flow was added.

| Stable 3D ID | Existing main behavior | Adapter behavior |
|---|---|---|
| home.drawer | GetLetters / letters panel | Open unchanged panel |
| home.journal | GetJournalStories / GetJournalPage | Open unchanged journal panel |
| home.tray | GetWordTray | Open unchanged words panel |
| home.net | Navigate seaside, then button GetSalvageView / Receive | Guard navigation; preserve SeasideView and SalvageController |
| home.caseFile | GetCaseBoard | Preserve unopened case state, no fabricated clues |
| home.merchantShip | GetShopView / Buy | Pick explicit semantic triangle proxy; preserve Shop panel |
| home.letterPaper | selected/current-order letter or letter picker, Read | Preserve OpenPaper/Reader selection logic and Cut(spanId) |
| home.stove | Navigate brew | Guard navigation only, never auto Preview |

One Bootstrap creates one real GameSession and PlayModel. The adapted AppView consumes that model instead of calling Model.New again. All original pinned main Lua modules are copied verbatim and hash-checked; changes live under `lab35/`. Storage is `SaveSystem.New(MemoryStorage.New())`, slot `d3_lab_v035`. Only that slot's five memory keys are accepted, with no File/io/fileSystem fallback. No cross-process persistence claim.

The HUD continues to show `live.economy.currency` and `live.gameFlow.day`. End Day opens a confirmation panel; confirmation tokens are single-use and invalidated by closing/cancelling. Queries, navigation, panels and hint toggles never grant rewards or receive letters. Salvage saves a real Receive result before the existing presentation; Skip only changes presentation and opens the saved letter. Existing purchase, reader and cut widgets call the real model.

World input runs through UI dispatch, stable semantic picking, Controller and existing AppView methods. Controller blocks while navigating, dragging, destroyed, portrait, showing a panel or animating salvage. Stale navigation completion is ignored. The injected native driver must call completion only when the actual route finishes. Hint labels project anchors beside objects, are hidden behind the camera, outside the viewport, behind occluders or under input locks, and use pointerEvents=none. No independent scissors Home action.

## 2D presentation review

| Existing presentation | This step |
|---|---|
| HomeZoom flat-image scale transition | Replaced by injected 3D navigation completion; original main untouched |
| Home background/layers | Replaced by a transparent Home facade; no old scene or full-image-plane fallback |
| Home hotspot feedback/hint positions | Replaced by semantic proxies and projected non-interactive labels |
| Continuous drawer animation | Not introduced |
| Seaside bottle bob, net lowering/lifting, reveal, Skip | Retained in the original SeasideView and SalvageController |
| Seaside ship bob/semantic ellipse | Retained on the existing 2D salvage page; distinct from the 3D Home ship proxy |
| Reader cut gaps, notices, lists, HUD and panels | Retained; business result drives refresh |
| Brew presentation / true camera routes | Existing panel retained in scaffold; asset-specific camera route and final arrangement not yet integrated |

## Evidence and boundary

Run `python -X utf8 tools/check_v035.py` from the Lab directory. It uses the existing local Lupa dependency, compiles the new and pinned Lua files, verifies all pinned hashes, and executes actual business modules with memory-only storage. Widget and native API substitutes verify dispatch/call sequences only. The 16:9, wide and 4:3 checks are layout-state checks, not screenshots or native composition acceptance.

Native MASK/cutoff material import fails explicitly. OPAQUE and BLEND map to verified PBR techniques, including PBRDiffNormal/PBRDiffNormalAlpha for 26 declared linear tangent normal textures. Tangents must be generated before Commit; missing/failed native API triggers rollback. UVs are not silently flipped. Full cloud reconstruction and earlier probe references were viewed locally; full geometry/53 PNGs were validated offline, not natively rendered. Invisible proxyMeshes are never submitted as visible art. Complete ship source geometry is retained for alpha-aware picking; ordinary converted Lua geometry is released after upload.

Current evidence: 152 checks / 107 source Lua compile; 90 full meshes / 3,209,455 triangles / eight mappings; 85 generated Lua compile / 150 runtime resources verified. See `docs/evidence/v035-main-interface/{offline-v035,full-package-check,full-resource-audit,full-staged-check}.json`, `runtime-source-manifest.json`, and `docs/D3-v035-full-entry-ready-report.md` for limitations and the controlled native plan.
