# Cloud native rendering checkpoint history

This file retains early chronological findings, not the current task status. See CLOUD-CANDIDATE-REPORT.md for the latest verified candidate and remaining acceptance limits.

Base: branch `3d`, commit `65e640cafc3330e70c0d934404077ad98932603f`.
Cloud work branch: `cloud/v035-runtime-visual`. No push.

Official Linux archive source:
https://urhox-demo-platform.spark.xd.com/runtime/linux/latest/UrhoXRuntime.zip

Received through Library after the cloud URL returned 502; original archive size
54,872,280 bytes, SHA256
`acaad89e9d480cda2e420ca833f2586bd5869de9d258af095cd9d7a052fed695`.
Nine archive entries passed CRC. ELF x86_64; all dynamic dependencies resolved.
Build: `20260924-1343-91bee56`, engine commit
`91bee56c8a7903c9e10230d0e766cfee0e07ff37`.

The supplied binary supports `-graphicssurfaceless`: real EGL/GLES rendering,
not the headless/Noop renderer. Existing Mesa software rendering is used. No
system packages were installed (apt lacked root/dpkg access). Runtime logging,
cache, and capture are isolated under the selected cloud evidence directory.

`tools/run_cloud_capture.sh` takes URHOX_RUNTIME and D3_CLOUD_OUTPUT variables.
The capture harness loads the same full scene with flipV=true, raises the cloud
loading timeout to 900 seconds, waits for READY plus 20 rendered frames, captures
using Graphics.TakeScreenShot, then exits. It performs no gameplay commands.
Original main.lua, geometry, materials, and business source are unchanged.

Initial smoke run reached full-scene loading. It was interrupted intentionally
because incorrect resolution switches selected 2040x1080 and fixed-frame capture
would precede completion. Correct second run uses -x 1170 -y 658 and READY-based
capture. At this checkpoint the second run is still loading; no successful game
image or visual acceptance is claimed. Software-rendering timing does not
represent the user's hardware performance.

## Verified native baseline

The second run completed all 90 meshes / 10,790 source objects / 3,209,455 triangles
and 862 drawables. Camera calibration passed. Load duration 855.607 seconds.
READY plus 20 rendered frames produced a 1170x658 PNG; process exited 0.
See cloud-native-baseline.json for hashes and exact calibration. The image was
actually inspected: room present, but flat lighting/material degradation remains.
This is an engine image, not Blender, and it is not visual acceptance.

## Verified shader-cache diagnosis

Official bundled Sphere/Box PBR smoke scene with HDR initially produced a dark
loading-like image and GLES link errors: vScreenPos/vTexCoord fragment inputs
without preceding vertex outputs. The same scene with the official
-recompile_shader flag produced a visible smooth sphere highlight, shaded box
faces, and cast shadows. Both screenshots were inspected. No binary or shader
source was patched. Cloud launch now disables the shipped shader-cache package
through this supported flag. Complete-room confirmation follows separately.

## Complete-room GLES pipeline confirmation

Source recompilation exposed a second official GLES issue: default BloomHDR
TONEMAP_LUT failed on texture3DLod. The cloud-only cloudNoLut option locks exposure
and selects the supported TONEMAP_MODE_NONE; cloudHdr enables HDR before rendering
starts. Runtime toggling HDR caused a failed screenshot and is not used.
The HDR-from-start complete-room run exited 0 and captured all five A/B frames
with no shader errors. Camera and all geometry remained intact. Turning off only
the two distant card shadow casters produced pixel-identical output under the
baseline light: that hypothesis was not the baseline flat-lighting cause.
Lower ambient and a doorway-aligned directional light change the image, but do
not yet achieve the requested appearance. Shadow and rectangle-light diagnostics
remain in progress. Windows was not run for these cloud options.

Publication attempt: git push had no configured HTTPS authentication. The
connected GitHub API refused blob writes with 403 Resource not accessible by
integration. No remote branch or commit was created. Publishing is paused; local
checkpoints remain available and no credentials were created.
