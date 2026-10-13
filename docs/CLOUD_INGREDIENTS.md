# Four shelf ingredients

Added sea salt (small bowl and irregular crystals), night dew (corked bottle and separate liquid), ash herb (rooted dry gray-green leaf cluster), and dried petals (shallow dish). Ten native meshes add 6,681 triangles; no whole-room image substitute or masked rectangular leaf cards were introduced.

Current totals: 100 meshes, 3,208,608 triangles, 2,592,846 source vertices, 10,847 source labels, 870 native drawables. All 164 resource hashes pass. Eight semantic anchors and the camera are unchanged and pass native projection. Independent geometry tests verify four shelf contacts, zero new/container or new/old-object triangle intersections, and no blocked interaction rays.

Actual native screenshot: `ingredients-retry/baseline.png`. The four additions appear on the middle-right shelf. The first capture attempt returned false; a fresh identical run succeeded with a 1170×658 readback. Capture success is separately checked rather than inferred from engine readiness. The glass/liquid is an alpha approximation and appearance remains dependent on the forthcoming sunset lighting.

Single-sided new containers use explicit CW under the RH camera; double-sided plant/petal/glass surfaces retain NONE. Earlier floor and closed-shell fixes, bottle removal and all old material metadata remain intact.

Licenses and source notices are included in `assets/v035-full/ingredients/licenses/`: Saatou author's potion-bottle terms (not claimed CC0), TinyWeeds CC0, and original project/newly authored salt/container/petal provenance. No unverified paid or copyleft model was added.

An editable packed Blender geometry checkpoint is separately preserved as `updated_scene.blend` (113,360,072 bytes; SHA256 b7f762312a85005c415a2a79e76461ff342db64b5bcb2439d5f45fb0b5821136). It contains the bottle removal, four ingredients and 271 corrected original closed shells. Runtime-specific lighting is a separate native implementation, not silently represented as identical Blender illumination.

## Later native refinements

Commit 97a048f adjusts four-ingredient shelf layout B for visibility, dabc126 repairs dried-petal normals and triangle winding without altering positions or UVs, and 5996b62 adds a modest localized shelf fill. The original screenshot and Blender hash above describe an earlier checkpoint; the separately delivered v3 source audit is authoritative for the new packed Blender file. The four raw ingredients are visible scene objects, not four newly added independent Home UI entry points. Their original shop/brewing business data remains unchanged.
