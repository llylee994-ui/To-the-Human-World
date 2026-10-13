# Closed-shell / camera-facing audit

After the floor checkpoint, a welded-edge and signed-volume audit found 166 further closed inward source objects. All have positive world-transform determinant; these are source-mesh orientation errors, not mirrored transforms or legitimate vessel cavities. Their exact 30,952 triangle indices are in `cloud-closed-shell-selection.json`. `fix_closed_shells.py --audit docs/cloud-closed-shell-selection.json` is a guarded one-time repair against the preceding checkpoint.

16 mesh files changed. Only selected triangle winding and their exclusively-owned vertex normals changed. No shared boundary vertices required splitting. All positions, UVs, source names, vertex/triangle counts and unselected normals/triangles are exactly preserved. Open/uncertain components are not flipped. The main copper vessel and glass are already positive, so their geometry is unchanged.

Single-sided Blender outward geometry needs CULL_CW under the calibrated RH native camera. Explicit CW is now recorded on visible single-sided materials; two-sided glass and image cards retain their policy. This exposes the copper vessel's proper outside and restores native highlights instead of the formerly flat-looking interior faces.

Actual Linux GLES full-room evidence: `closed-shell-fixed/baseline.png`, same baseline lights as the prior HDR capture. 90 meshes / 3,209,455 triangles / 862 drawables / 10,790 source objects; eight camera anchors pass. All 150 resource hashes pass. Original positions, camera, business logic and source Blender file were not changed by this checkpoint.

Remaining: ambient is still too strong, floor dark marks need separate analysis, glass is only an alpha approximation, original area lights are not restored. Rectangle-light API availability is not proof of native contribution: official RectLightDemo brightness 500→0 had zero image difference on this build, while converting it to POINT brightness 5→0 changed pixels. A separate lighting diagnosis continues. Windows has not been retested.
