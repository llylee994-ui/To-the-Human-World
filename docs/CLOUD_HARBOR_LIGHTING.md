# Native harbor lighting candidate and remaining limits

The real entry (`scripts/main.lua`) and cloud capture now use the same `HarborLighting` preset. No whole-room background image is used: all furniture, plants, floor, lamp, tabletop and near dock remain native geometry. Only the authorized distant sea/landscape and separate boat are unlit cards.

- HDR enabled from startup; fixed exposure and TONEMAP_MODE_NONE avoid this Linux GLES build's unsupported 3D-LUT shader path. Official `-recompile_shader` is required by the cloud launcher to avoid incompatible shipped cache variants.
- Ambient warm-neutral linear RGB (.035,.03,.025); sunset direction (.4682927,-.4682927,.7492687), brightness 1.25, RGB (1,.76,.49), shadows enabled.
- Official existing Dusk low-quality reflection cube at intensity .6; it is a lighting approximation, not the original Blender sky environment.
- Lantern uses the existing detailed geometry, explicit flame emission (4,.8,.032), and local warm point light at engine (-.2,3.6,-3), brightness 1.3, range 2.8, with shadows. A localized warm-neutral tabletop point at (1.3,4.2,2), brightness 40 and range 8, approximates reflected fill. Its numeric brightness is calibrated for this engine and is not Blender wattage. Blender watts/disks are not copied numerically as native lights.
- No experimental rectangular light or ineffectual extra spotlight is left in the candidate preset. Their historical source/logs/images remain separately preserved.
- Distant cards do not cast interior shadows. Original image pixels remain unlit: the sky/boat comparison ROI x270..389,y80..249 was pixel-identical before/after lighting (max channel delta 0).

Actual native evidence: `final-1170/baseline.png` (1170×658), 100 meshes, 3,208,608 triangles, 870 drawables; eight projection anchors pass, 75.52 s software load in this run, successful screen readback at frame 20. This software-rendering timing is not a user-device benchmark. The larger final screenshot and interaction run are subsequent checks.

The floor's small dark marks match 210 original modeled square nails; sampled projected nail centers coincide with the visible marks. They were not deleted as shader faults.

A screenshot readback may transiently fail. Capture now retries at bounded ten-frame intervals through frame 120, reports actual dimensions/success, and the shell exits nonzero if the final PNG is absent. Engine READY alone is not treated as visual acceptance.

Remaining limits: stylized geometry and alpha glass, simplified environmental/bounce illumination versus Blender, heavy mesh count, and no Windows visual/performance retest. The scene remains an isolated in-memory Lab; original player saves are not touched.

## Color-space correction

Base-color textures must receive their sRGB flag before GPU upload. The former post-upload assignment caused a reproducible double-gamma washout: the native reference gray patch was 187 instead of 128. The corrected upload order restores 128 and preserves background image colors. This is an observed project defect, not evidence that all Maker scenes have an engine-wide defect.

## Acceptance scope

The user has not accepted the visual match to the Blender reference. Current work improves the native scene; stronger contact shading, glass/night-dew readability and real device performance remain separate checks. Full-scene native UI testing uses synthetic mouse events in isolated memory, not a human operating an OS mouse.

## Shelf fill candidate

Only a local point at (2.65,4.05,-1.7), range 2.2, RGB (1,.95,.88), brightness 2 is added. Native same-camera tests of brightness 0, 2 and 6 are recorded in cloud-shelf-light-candidate.json. Brightness 6 is rejected because it lifts the upper shelf underside too much. Brightness 2 makes a modest improvement only; the remaining dark petals and missing local cast shadows are not declared fixed.
