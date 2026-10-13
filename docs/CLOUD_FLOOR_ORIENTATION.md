# Native floor orientation checkpoint

The floor's 105 closed planks were inward-facing: top Z=0 had normals −Z, bottom Z=−0.16 had +Z. Matching normals to triangle cross products did not detect this because both were inward. Welded edge audit (1e-6 units): 29,610 edges, all with exactly two incident faces; all 105 connected components had negative volume.

Only `full_group_018_000` has been corrected: reverse triangle winding and negate normals. Positions, UVs, object coverage, triangle counts, camera and eight anchors are unchanged. All 150 resource hashes verify. `tools/fix_floor_orientation.py` is guarded against the original mesh SHA and refuses a second application.

The existing RH Home camera needs explicit CW culling for this now-outward surface in the tested Linux renderer. The new optional material `cullMode` field is validated as CW/CCW/NONE and carried through the adapter and native material. Existing materials retain their defaults. Floor metadata sets CW. This setting has not been retested on Windows.

Native evidence (kept outside Git to avoid duplicate large binaries): `floor-directional/fixed-CW.png` versus `floor-directional/sphere-CCW.png`, and full-room `floor-full-corrected/floor-corrected.png` versus `normal-point-study/00-point-normal-on.png`. Same white point light, no shadows, low ambient: corrected floor receives illumination instead of showing a dark top with bright seams. Full room retained 90 meshes, 3,209,455 triangles, 862 drawables and passed all eight camera anchors. Native metadata-to-material check passes in `cloud_floor_contract_check.lua`.

This is a floor correctness checkpoint, not finished lighting. Remaining objects need independently verified outwardness; open leaves, cloth and transparent shells must not be globally flipped. The visible wood texture dark flecks and final warm illumination still need separate review.
