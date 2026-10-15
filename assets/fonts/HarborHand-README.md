Harbor Hand Regular is a modified, subsetted version of LXGW WenKai Regular.

Source: https://github.com/lxgw/LxgwWenKai/blob/main/fonts/TTF/LXGWWenKai-Regular.ttf
Source SHA-256: bf73f995c05f3f7baf7840b9d76d8d9678c8b150a020946a394ca63c67ed1350
Copyright 2021-2026 LXGW; Copyright 2020 The Klee Project Authors.
License: SIL Open Font License 1.1; see LXGWWenKai-OFL.txt alongside this file.

Modification: fontTools 4.66.1 subset, internal family renamed to Harbor Hand and
PostScript name to HarborHand-Regular to respect the original Reserved Font Names.
This font remains under SIL OFL 1.1. It is bundled for the game's UI, not installed
as a system font.

Coverage: every printable character in scripts/**/*.lua and scripts/**/*.json at
the time of generation, printable ASCII, GB2312 simplified Chinese characters,
and supported CJK punctuation. The subset contains 6,944 requested Unicode values
and is 3,433,320 bytes, compared with the 25,928,940-byte original.
Four optional added marks absent from the source (U+302E, U+302F, U+3031, U+3032)
are not used by current project text. All current project characters are covered.

New text outside this coverage requires regenerating the subset or using the
full original font under its original name. The game registers this font as
`story`; `sans` continues to point to the engine's MiSans font. Regular and bold
both use this Regular file for consistent readable handwriting.

Harbor Hand Medium (2026-10-15) is a separate subset of upstream
LXGWWenKai-Medium.ttf, used only as `story-strong` for approved wish sentences.
It has the same 6,945 Unicode mappings as the existing Regular subset and retains
the upstream Medium outlines, with no synthetic multi-pass text drawing. Internal
names are renamed to Harbor Hand Medium; the same SIL OFL 1.1 license applies.
Source URL, source/subset SHA-256 and coverage are in
`HarborHand-Medium-source.json`. Existing `story` and other UI weights are unchanged.
