# Locked native harbor lighting checkpoint

The real entry (`scripts/main.lua`) and cloud capture now use the same `HarborLighting` preset. No whole-room background image is used: all furniture, plants, floor, lamp, tabletop and near dock remain native geometry. Only the authorized distant sea/landscape and separate boat are unlit cards.

- HDR enabled from startup; fixed exposure and TONEMAP_MODE_NONE avoid this Linux GLES build's unsupported 3D-LUT shader path. Official `-recompile_shader` is required by the cloud launcher to avoid incompatible shipped cache variants.
- Ambient warm-neutral linear RGB (.22,.205,.18); sunset direction (.4682927,-.4682927,.7492687), brightness 1.25, RGB (1,.76,.49), shadows enabled.
- Official existing Dusk low-quality reflection cube at intensity .6; it is a lighting approximation, not the original Blender sky environment.
- Lantern uses the existing detailed geometry, explicit flame emission (4,.8,.032), and local warm point light at engine (-.2,3.6,-3), brightness 1.3, range 2.8, with shadows. A low-intensity cool-neutral room point approximates reflected fill. Blender watts/disks are not copied numerically as native lights.
- No experimental rectangular light or ineffectual extra spotlight is left in the final preset. Their historical source/logs/images remain separately preserved.
- Distant cards do not cast interior shadows. Original image pixels remain unlit: the sky/boat comparison ROI x270..389,y80..249 was pixel-identical before/after lighting (max channel delta 0).

Actual native evidence: `final-1170/baseline.png` (1170×658), 100 meshes, 3,208,608 triangles, 870 drawables; eight projection anchors pass, 75.52 s software load in this run, successful screen readback at frame 20. This software-rendering timing is not a user-device benchmark. The larger final screenshot and interaction run are subsequent checks.

The floor's small dark marks match 210 original modeled square nails; sampled projected nail centers coincide with the visible marks. They were not deleted as shader faults.

A screenshot readback may transiently fail. Capture now retries at bounded ten-frame intervals through frame 120, reports actual dimensions/success, and the shell exits nonzero if the final PNG is absent. Engine READY alone is not treated as visual acceptance.

Remaining limits: stylized geometry and alpha glass, simplified environmental/bounce illumination versus Blender, heavy mesh count, and no Windows visual/performance retest. The scene remains an isolated in-memory Lab; original player saves are not touched.
