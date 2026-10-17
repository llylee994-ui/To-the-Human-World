# Wish Collage Ending Implementation Plan

> Execute inline using executing-plans. User explicitly forbids subagents; no delegation, commits, pushes or remote builds.

**Goal:** Replace the wish ending with the approved wood desk, pale corner paper, left tray, editable mixed-media collage and a narrated return-to-title flow; deliver native background screenshots.

**Architecture:** Extend the existing saved placement list compatibly with optional scale, depth and lock fields and independent decoration instances. Keep original token identity/inventory and backend day/ending transactions. Share normalized paper rendering across editor, preview and frozen memories; background evidence uses a memory-only fixture and engine screenshots.

**Tech Stack:** Lua 5.4, UrhoX urhox-libs/UI, existing UI renderer and pointer events, existing atomic save protocol; Python/lupa headless regression runner.

## Constraints

- Use original table-background.png, approved soft-scrollwork-letter-paper.png and user-selected botanical-atlas.png. Blank slips are independent unlettered decorations; existing WordSlip art stays unchanged.
- Full rotation, uniform scaling of paper and lettering, overlap, explicit depth, lock/unlock, return and undo. One placement per actual collected token, including consumed tokens. Decorations repeat as independent instances, subject to existing 128-piece capacity.
- Old saves/memories retain their frozen data and default omitted scale/depth/lock. No concatenated source text presented as the visual wish: the actual paper is the result.
- No OS input or window activation. Local preview only as needed for the expressly requested screenshots; restore probe flags and stop the screenshot session afterward.

## Task 1: Persistence and geometry

- [x] Add failing tests in scripts/ui/landscape/tests/WishCollageTest.lua for mixed word/decor save/reload/freeze, invalid IDs/scales/duplicates, legacy rows and cancellation/locking.
- [x] Add scripts/data/wish_decorations.lua: immutable catalog of 8 botanical frames and 3 blank paper frames; fields id, label, path, source dimensions/bounds and default display size.
- [x] Extend systems/WishCollage.lua: Id(row), Depth(row,index), Order ignores decorations; Validate accepts optional scale/z/locked and either sourceTokenId or decorationId+instanceId; Freeze selects word rows only; ValidateFrozen counts only word rows.
- [x] Run new persistence tests plus EndingPresentation/ReleaseEndingSave. Preserve revision and atomic failure behavior.

## Task 2: Editor and frozen paper

- [x] Add failing UI tests for approved assets, left tray tabs, independent blank scraps, duplicate decorations, scale/rotation/layer/lock, undo and frozen preview.
- [x] Replace WishPaper using canonical normalized geometry with shared Clamp, Metrics and frame rendering. Draw original token art and live text together, no text for decorations; render actual saved depth and angle; heading centered.
- [x] Replace WishView composition: warm wood background, existing wood tray on left, word/decor tabs, scrollable items, paper right, contextual controls, drag scale/rotation handles, bottom preview/send controls. Commit once per completed gesture; cancel on focus loss, viewport change, save failure or destruction. No auto-raise on selection.
- [x] Verify pointer ownership, duplicate-source disable, stale callback guard and safe layout at compact/wide viewport sizes.

## Task 3: Intro and ending

- [x] Add narrated special-bottle entry using existing epilogue steps/transactions and salvage art. No changes to route/day requirements.
- [x] Add wish ending narration over the sea, fade to heading and elegant return button, with read-only frozen paper review. Reuse existing ending sequence/pointer/StoryStyle button materials.
- [x] Run relevant integration, save, day-gate and traveler/apprentice regressions; inspect Lua diagnostics and diff.

## Task 4: Native evidence

- [x] Add default-off WishNativeProbe using a memory-only fixture, actual UI pointer dispatch and engine TakeScreenShot; assert real player state unchanged.
- [x] Start bounded local preview expressly for requested screenshots, collect fresh logs/check, copy screenshots before stopping, inspect actual PNGs.
- [x] Restore default-off flags, stop preview, record evidence and outstanding device limits, deliver screenshots inline.

## 用户反馈修正

- [x] 移除另造托盘，直接复用 WordTrayDrawer，追加同款装饰分类；现有分类与花束/布底/箭头保持，拼贴操作位于信纸下方。
- [x] 托盘回归64断言、Wish9/9、WordSlip181断言、ReleaseUI11/11；原生全流程PASS及实际共享托盘截图保存r2，默认探针关闭，预览停止。
