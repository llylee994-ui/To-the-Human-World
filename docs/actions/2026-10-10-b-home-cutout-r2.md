# B-HOME-CUTOUT-20261010 r2 行动记录

## Status and situation

Status: Partial / blocked on source-faithful transparent extraction. Source request: B-HOME-CUTOUT-20261010 r2. The verified source is `C:/WINDOWS/TEMP/codex-clipboard-2cd8378c-acb6-4000-ad65-e6f6a2911fe9.png`, visually inspected before work. This r2 explicitly replaces r1's full-canvas transparent-layer approach with seven independently tight-cropped RGBA PNG groups, one clean full-canvas background, and a full-canvas replay preview.

The seven groups are: merchant sailboat plus local reflection/wake; door-side fishing net; word tray plus nearby scissors and nearby dry flower; handwritten central letter; cauldron with stand/fire/shadow/steam; lower-right yellow case file; and the calendar with its paper page, spiral binding, and base but no date numeral. The central intent is to retain source perspective, lighting, scale, group-internal spacing, and hand-painted treatment while making each selection box practical in the layout editor.

Latest user correction: the cauldron's final layer must contain no steam. Steam is now excluded rather than a soft-effect acceptance concern.

Latest follow-up scope: create a more refined no-steam cauldron with visible simmering herbs, then copy all r2 source/background/generated assets into the root `scripts/素材` directory using the existing `参考_` / `BG` / `Hxx_..._vNN` naming convention. The nested versioned directory remains an audit record; root copies make assets discoverable for downstream layout work.

Latest visual correction: `H09_炼药炉_草药熬制_透明_v04.png` is too broad and heavy. Create a non-destructive v05 alternative with a smaller, lower-profile vessel, slimmer legs and handles, more delicate metalwork, visible herb simmering, and no steam.

Latest omission correction: H20 letter has not yet been generated. Create a standalone transparent H20 layer with the selected source letter's oblique perspective, continuous unreadable decorative handwriting, curled paper edge, and local contact shadow only; exclude tablecloth and all other tabletop objects.

Exclusions: no code, interface, gameplay, drawer extraction/opening frames, or new drawer perspective. The opened bottle, journal, drawer, and all other unlisted objects remain in the clean background. Existing workspace changes are not this task's responsibility.

## Implementation measures

1. Save an unmodified source copy in the versioned deliverable directory and record its dimensions and hash.
2. Use the built-in image editor for one clean background and seven individual transparent-background cutouts; each prompt covers only its named group and requests tight bounds.
3. Inspect alpha channels, opaque bounding boxes, dimensions, and transparent borders; prepare a coordinate manifest with original-canvas positions, layer order, use, and actual checks.
4. Compose the seven delivered RGBA layers at recorded coordinates over the clean background; save a full-canvas replay preview and inspect it against the source for position and edge issues.

Completion criteria: source copy, seven small tight RGBA PNGs, clean full-size background, replay preview, and manifest all exist without overwriting previous assets. Every cutout must contain alpha; the full-size outputs may remain opaque.

## Affected file tree

```text
docs/actions/2026-10-10-b-home-cutout-r2.md                         Trace record.
scripts/素材/主页分层_细修版_v01/源图_主页细修_v01.png                 Unmodified local source copy.
scripts/素材/主页分层_细修版_v01/BG_主页干净背景_v01.png              Full-size clean scene background.
scripts/素材/主页分层_细修版_v01/H18_商船组合_透明_紧裁_v01.png       Tight shop-entry layer.
scripts/素材/主页分层_细修版_v01/H06_捞网_透明_紧裁_v01.png           Tight seaside-entry layer.
scripts/素材/主页分层_细修版_v01/H10_词条托盘组合_透明_紧裁_v01.png   Tight word-tray entry layer.
scripts/素材/主页分层_细修版_v01/H20_信纸_透明_紧裁_v01.png           Tight decorative letter layer.
scripts/素材/主页分层_细修版_v01/H09_炼药炉组合_透明_紧裁_v01.png     Tight brew-entry layer.
scripts/素材/主页分层_细修版_v01/H17_黄色档案袋_透明_紧裁_v01.png     Tight case-board entry layer.
scripts/素材/主页分层_细修版_v01/H14_日历底座_透明_紧裁_v01.png         Tight dynamic-date base layer.
scripts/素材/主页分层_细修版_v01/预览_主页七组素材原位复原_v01.png    Full-size replay evidence.
scripts/素材/主页分层_细修版_v01/素材清单_v01.json                    Coordinates, z-order, uses, and results.
scripts/素材/主页分层_细修版_v01/过程稿/*_自动提取_不采用.png          Rejected RGBA extraction evidence; never import.
scripts/素材/参考_横屏主页细修_原图_v01.png                              Root discovery copy of r2 source.
scripts/素材/BG06_横屏主页_清理背景_v01.png                              Root discovery copy of r2 clean-background candidate.
scripts/素材/H06_捞网_透明_自动提取_v02.png                              Root discovery copy of r2 generated net.
scripts/素材/H09_炼药炉_草药熬制_透明_v04.png                            New no-steam simmering-herb cauldron.
scripts/素材/H09_炼药炉_纤巧草药熬制_透明_v05.png                          Planned refined small-vessel cauldron alternative.
scripts/素材/H10_词条托盘组合_透明_自动提取_v04.png                      Root discovery copy of r2 generated tray composite.
scripts/素材/H14_日历底座_透明_自动提取_v04.png                          Root discovery copy of r2 generated calendar.
scripts/素材/H17_黄色档案袋_透明_自动提取_v08.png                        Root discovery copy of r2 generated case file.
scripts/素材/H18_商船组合层_透明_自动提取_v03.png                        Root discovery copy of r2 generated sailboat.
scripts/素材/H20_中央信纸_手写字迹_透明_v01.png                            Planned standalone decorative letter layer.
```

The clean background is the composition base. Seven cutouts are independently movable presentation layers and are replayed through the manifest; the preview is verification-only and not an additional game asset.

## Self-verification method

1. Visually inspect source, clean background, every layer, and replay preview.
2. Use image metadata/alpha analysis to confirm cutouts are RGBA with real transparent pixels and record the tight opaque-alpha bounding box / canvas margin.
3. Render each delivered layer at its recorded source coordinate over the clean background; inspect mismatch and generated alpha edges on white and dark checkerboard-style test backgrounds.
4. Check path-scoped Git status and hashes to confirm source preservation and no code / original-reference write.

## Self-verification results

1. Source copy saved as `源图_主页细修_v01.png`: PNG/RGB, 1672×941, SHA-256 `DD86B3AF3EF96CD6C54AC8E4B916379959D970FB68D63CD6DA6FDB878509D3BF`.
2. Built-in image editor created `BG_主页干净背景_v01.png`: PNG/RGB, 1672×941, SHA-256 `1DE5DE32C77E4E897C97A790C1ADD0B1B688D390562BE464D6932FEF12216055`. Visual check: the requested boat, net, tray group, letter, cauldron, case file, and calendar are absent; opened bottle, journal, drawer, and unlisted room elements remain. It is a generated repaint, so it is a visual candidate rather than pixel-identical restoration.
3. Four trial transparent extraction calls (sailboat, net, tray composite, calendar) were inspected. All are true `Format32bppArgb` with alpha-0 corners, but each was enlarged and materially redrawn by the image editor. Calendar is 1396×1127, net 1024×1536, tray 1534×1025, and sailboat 1319×1192; these dimensions and visual forms cannot be source-scale, tight-cropped replay layers. The RGBA drafts are retained only under `过程稿` with `不采用` names.
4. Because the first four independent tests all failed the same r2 invariant, the remaining letter, cauldron, and case-file extraction calls were not run. No false final PNGs, source coordinates, or replay preview were produced. The required layer files listed above are therefore planned-but-not-created, not missing deliveries hidden behind similarly named files.
5. `素材清单_v01.json` records the partial result and rejection reasons. No Lua, layout, interface, or original reference was changed.
6. Static delivery check: `素材清单_v01.json` parses successfully. PNG-only metadata enumeration confirms source and clean background are both 1672×941 RGB; rejected drafts are ARGB with alpha-zero corner samples. An initial enumeration incorrectly tried to parse the JSON manifest as a bitmap and failed; rerunning with a PNG filter passed, so this was a check-method error rather than an asset error.
7. Follow-up extraction executed for the previously unrun groups. `H09_炼药炉_含蒸汽_自动提取_不采用.png` was generated first, then superseded when the user rejected steam. The replacement `H09_炼药炉_无蒸汽_自动提取_不采用.png` is ARGB 1313×1198 with alpha-zero corner sample and contains no steam. `H17_黄色档案袋_自动提取_不采用.png` is ARGB 1536×1024 with alpha-zero corner sample. Both remain rejected because the editor enlarged and materially redrew their source objects. All new generated files were copied from the tool cache into `scripts/素材/主页分层_细修版_v01/过程稿`; none is left solely in the generated-image cache.
8. User requested a more refined cauldron that visibly brews herbs, while retaining no steam. Generated and saved root asset `H09_炼药炉_草药熬制_透明_v04.png`: ARGB 1313×1198 with transparent corner; visual inspection confirms dark amber-green liquid, visible leaves, small pale flowers, purple sprigs, and surface bubbles inside the open pot; no steam/smoke/fog is visible.
9. User also requested discoverable root-level asset placement. Non-destructive copies are now in `scripts/素材`: `参考_横屏主页细修_原图_v01.png`, `BG06_横屏主页_清理背景_v01.png`, `H06_捞网_透明_自动提取_v02.png`, `H10_词条托盘组合_透明_自动提取_v04.png`, `H14_日历底座_透明_自动提取_v04.png`, `H17_黄色档案袋_透明_自动提取_v08.png`, `H18_商船组合层_透明_自动提取_v03.png`, and the refined `H09_炼药炉_草药熬制_透明_v04.png`. Existing nested files remain as audit copies; no existing root asset was overwritten. Metadata check confirms the five generated object copies plus the new cauldron are ARGB with transparent corner samples; source/background copies preserve 1672×941 RGB canvas.
10. User rejected v04 as visually bulky. New `H09_炼药炉_纤巧草药熬制_透明_v05.png` was generated with a lower, narrower pot, compact handles, slender three-leg stand, small contained flame, and visible leaves/flowers/bubbles. Visual inspection confirms no steam. Metadata: PNG/ARGB, 1313×1198, alpha-zero top-left sample, SHA-256 `A09C379FE6AC0946076C2E0284AFAD32A57F60831A425560B2259830D0292898`. This is a visual alternative; its source-scale/replay limitation remains separate from the asset-design revision.
11. User noted that H20 had not been generated. `H20_中央信纸_手写字迹_透明_v01.png` is now saved in root `scripts/素材`: PNG/ARGB, 1536×1024, alpha-zero top-left sample, SHA-256 `C2E0A86826119E9967ACDA65E4C466577E357212941674186638BCF412A0EA08`. Its second generated pass replaced initially letter-like writing with lower-contrast broken gestural strokes; visual review confirms it remains decorative and does not supply readable game text. The layer includes only the paper, folds, and localized shadow on transparent background, not the desk or tablecloth.

Blocking condition: the available built-in image editor does not preserve pixel scale or identity for extraction from this source. Its output is valid RGBA but not valid source-faithful cutout material. A tool/workflow capable of source-pixel masking plus canvas-only crop is required before r2's seven-layer and exact-replay acceptance can be truthfully completed.
