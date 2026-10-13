# Remove the two tabletop bottles

Removed 35 exact source objects and their 7,528 triangles: DAY bottle, coin bottle, labels, coins, stones/roots and bottle-specific parts. Shared lamp/tabletop/metal groups were retained using exact face selection, not whole-group hiding. The selection recipe is preserved in `cloud-bottle-removal-recipe.json`. Remaining attributes are exact subsets of the already orientation-corrected meshes.

The original 90 mesh IDs remain; 3,201,927 triangles / 2,575,906 source vertices / 10,755 source objects. 150 resource hashes pass. Source coverage/manifest/mesh descriptors were updated together. Camera, eight interaction proxies, and all existing material/cull changes remain unchanged. HUD day/coins remain visible.

Native Linux screenshot: `bottles-removed/baseline.png`. Both bottles and loose contents are absent; the lantern, cauldron, tray, scissors, letters and shelves remain. Full load has 860 drawables and passes eight camera anchors. Lighting is deliberately unchanged for this single-variable check. This is not the final sunset-lighting capture.
