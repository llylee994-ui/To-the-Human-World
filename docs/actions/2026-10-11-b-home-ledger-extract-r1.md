# B-HOME-LEDGER-EXTRACT-20261011 r1

## Status and situation

Status: Superseded as the active direction by B-HOME-LEDGER-TABLE-20261011 r1. The user has moved the bottles onto the table and paused further old-position extraction until that composition is approved. Existing date problem files and the generated money candidate are retained. Neither has been accepted for C integration.

- Selected source: `C:/WINDOWS/TEMP/codex-clipboard-bdfcefb4-e83a-43d2-a952-6d310f9c2f9e.png`, 1672×941, RGB (no source Alpha).
- Unlabelled homepage: the original image supplied in this chat, `C:/WINDOWS/TEMP/codex-clipboard-1e2fc068-1d91-4127-9539-eb72d458e533.png`, 1920×1080, RGB. It contains neither UI bottle. This will be copied into the task evidence directory and used for compositing, not the selected labelled source.
- Preserve upright rectangular silhouettes, corks, DAY pebble letters, the approved overlapping coin motif and bottom pebbles. No digits, placeholders, extra currency prefix, redesign, new shelf or decoration.
- The selected source has only roughly 70×160 pixels per bottle. Enlarged reconstructed output cannot be presented as recovered source detail. Original glass Alpha and refracted background cannot be uniquely recovered from one flattened image.
- Only add task assets, preview evidence and necessary records. Do not overwrite old assets, modify game code/layout, start game preview, commit or push.

## Implementation measures

1. Make lossless source crops and preserve both input images under the requested new directory; inspect the date crop.
2. Use built-in imagegen to isolate the date bottle on true Alpha, retaining the chosen shape/decorations and rebuilding glass transparency without source wood/plants. Save raw output as process evidence.
3. Measure Alpha distribution, transparent margins and interior samples; mechanically crop transparent canvas. Composite over light/dark backgrounds and the unlabelled homepage at the original relative position. Inspect images and compare shape with source.
4. The first pass stopped at the failed date gate and delivered its problem preview. The user subsequently explicitly requested money extraction too; proceed with this authorized money pass while preserving date's failed status.
5. Extract/reconstruct the selected money crop with built-in imagegen; preserve the approved overlapping coin emblem and three bottom stones, no numbers or extra currency prefix. Check real Alpha, shape and light/dark/home composites, save a separate compact PNG and report limitations. Do not redraw the date candidate or treat it as approved.

## Affected file tree

```text
docs/actions/2026-10-11-b-home-ledger-extract-r1.md  Task action record.
scripts/素材/双瓶标签_选定版提取_v01/
  问题预览_日期瓶_无标签主页_v01.png              Actual date-only composition, 1920x1080.
  问题预览_日期瓶_浅深底_v01.png                  Actual date/source comparison and light/dark test, 1000x730.
  素材清单_v01.md                                Source, sizes, coordinates, reconstruction and limits.
  检查结果_v01.json                              Machine-readable measurements.
  金钱瓶_钱币_透明_v01.png                        Planned independent RGBA money review candidate.
  检查_金钱瓶_浅深底_v01.png                      Planned money source/light/dark comparison.
  预览_金钱瓶_无标签主页_v01.png                  Planned money-only placement preview.
  金钱瓶_检查结果_v01.json                        Planned money alpha and placement measurements.
  过程记录/                                     Actual input copies, both lossless crops, raw date RGBA,
                                                date problem crop, prompt and PowerShell QA helper.
```

At the initial date gate, no formal date/money assets or final paired previews were produced. The date PNG remains a rejected/problem review asset. The following money pass is separately authorized; generated assets remain pending user/A visual approval, not integrated runtime resources. Mechanical crops and preview compositing do not redesign the art or fabricate source detail.

## Self-verification method

- Check PNG signature, pixel dimensions, RGBA/Alpha values, alpha=0 / intermediate / opaque counts, occupied bounds, edge margins and designated empty interior regions.
- Inspect large and native-size light/dark-background composites for baked wood/plants, opaque fields, rectangular blocks, halos, lost highlights and decoration damage.
- Inspect homepage composite made only from the unlabelled base; compare against that base outside the two placement rectangles (expected exact identity).
- Record source coordinates and the separate homepage mapping; keep original aspect and identify any scale mismatch.
- Inspect source-vs-extracted silhouette/decorations. A successful tool return alone never counts as passing.
- Keep output filenames and hashes; ensure no pre-existing target is overwritten.

## Self-verification results

1. Read and visually inspected the user-selected source and its lossless date crop. Confirmed selected source 1672x941 RGB; original unlabelled base 1920x1080 RGB. Preserved both input copies and SHA-256 hashes.
2. Built-in imagegen produced a date reconstruction, 860x1828 RGBA. Actual prompt is saved under the output directory. The tool redrew the entire bottle, not only local glass. No alternate shape/decorative design was requested.
3. Ran `scripts/素材/双瓶标签_选定版提取_v01/过程记录/检查日期瓶.ps1`. Initial C# helper compile failed due to an omitted System.Collections reference; corrected references, reran successfully. This was a QA helper error, separate from the artwork defects.
4. Alpha counts: zero 903344, partial 668651, 255 85, all 256 levels used. Selected central empty-region ROI has alpha 0-1 and 94.1119 percent exactly zero. The requested faint glass contribution was not restored there. Exterior alpha 1-7 scattered noise also remains in the raw candidate.
5. Alpha>=8 silhouette ratio is 626/1665=0.37598, versus selected-source approximate 67/156=0.42949; candidate is about 12 percent narrower. Shoulder highlight/rim are stronger. This is a material fidelity failure, not corrected by stretching or declared acceptable.
6. Generated actual light/dark compositions and opened them alongside the original crop. No obvious baked wood/plants, large rectangular fill or white/black contour halo was seen; the shape and glass treatment still fail the overall date gate. DAY, cork and three stones remain but were generatively repainted.
7. Trimmed problem candidate to 642x1681 using alpha>=8 bounds plus 8px; retained RGBA unchanged and documented discarded external alpha<=7 noise. The crop is explicitly a problem draft, not a formal asset.
8. Generated and opened 1920x1080 date-only preview on the original unlabelled base. Actual draw rectangle (38,30,69,181), uniform scaling, changes outside placement rectangle exactly zero. Original input hashes match the preserved copies.
9. Followed user's stop condition: no money transparency generation, no formal date/money filenames, no final paired preview, no C handoff. Provided the date problem preview, measurement JSON, source coordinates, raw result, exact prompt and limitations in `素材清单_v01.md`.
10. All actual outputs are new task files. No old image, game code, layout or source file was overwritten; no game/foreground/device test was run, no commit or push.

## Money continuation and subsequent direction change

Before the user changed direction, the explicitly authorized money pass produced `金钱瓶_钱币_透明_v01.png` (555x1380), a raw reconstruction, light/dark comparison, money-only homepage preview, and a paired review preview using the unchanged date problem draft. The actual number-area Alpha was 44-74 (mean 56.8175); edge residual Alpha reached 2; approximate silhouette ratio was 5.161 percent narrower than the selected reference. Preview changes outside the designated rectangles were zero. Coin and three bottom stones were present, but the reconstruction altered fine detail and highlights, so it remained a review candidate. Full measurements are in `金钱瓶_检查结果_v01.json`.

The next user request explicitly superseded the upper-left label arrangement with a full-scene table placement exploration. No further extraction or cleanup will continue under this old placement. Follow `2026-10-11-b-home-ledger-table-r1.md` for the new composition.
