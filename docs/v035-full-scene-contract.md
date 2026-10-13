# Complete v03.5 package: current local consumer contract

2026-10-13. This is the active full-scene contract. All seven full-scene ZIPs are locally present and hash-verified. The complete full-scene entry is staged offline; native launch remains paused. The old six-mesh sample is preserved as history. No full-scene pixel acceptance is claimed.

Current checks: 152 offline regression checks PASS, 107 canonical Lua files compile, all 80 pinned main source hashes unchanged. Real full-package streaming validation PASS: 90 meshes, 3,209,455 triangles, 10,790 source objects, eight semantic entries and one complete ship mesh retained; exit code 0, 122.64 seconds. Staged-entry check PASS: 85 generated Lua files compile, actual Install registers Start/Update/Stop without invoking native Start, all 150 runtime resource hashes match. Evidence: `offline-v035.json`, `full-package-check.json`, `full-resource-audit.json`, `full-staged-check.json` under `docs/evidence/v035-main-interface/`. These are offline results; official managed prepare and native execution of this full package have not run. Prior native exit cause remains unresolved.

## Files

`manifest.json` stays small; `entry` points to a metadata-only JSON (suggested `scene.json`). `meshFiles` may be in manifest.json or in scene.json. Mesh payloads are individual JSON files. Paths are relative to the package, use `/`, and may not contain empty segments, `.`/`..`, drive letters, absolute paths or Windows case collisions. Include `SHA256.json`, original Blender source identity, the full reference render and export coverage statistics. Do not ship one combined mesh JSON containing all geometry.

```json
{
  "entry": "scene.json",
  "meshFiles": [
    {"path":"meshes/room-wood-000.json", "id":"room-wood-000", "materialId":"wood", "vertices":59997, "triangles":30000, "sha256":"<file SHA256>"}
  ]
}
```

Each meshFiles entry requires `path`, `id`, `materialId`, `vertices`, `triangles`. Accepted naming aliases are `file`, `vertexCount`, `triangleCount`. Entries are descriptors, not bare path strings: the importer must verify semantic mesh references and total counts before reading large payloads. A file's ID/material/counts must agree with its descriptor.

Each mesh file is one object with `id`, `materialId`, flat `positions`, `normals`, `uv0`, ZERO-based `indices`, and `sourceObjects` (source names as strings, repeated membership across split chunks is allowed). World transforms and evaluated modifiers are baked. Triangle winding must already account for negative source scales. Remove/report zero-area triangles at export rather than letting the importer silently omit them.

Source vertices per file: 3–60,000; the local backend splits expanded native batches further to 12,000 vertices, and yields during emission every 1,023 vertices. Current full-scene guard permits at most 12,000,000 expanded vertices. Latest cloud static totals are 90 files, 3,209,455 nonzero-area triangles, 2,584,246 UV/normal-split source vertices, and 10,790 source objects; 6,926 zero-area triangles were removed at export. The resulting 9,628,365 expanded vertices fit this guard. This is a data guard, **not** a performance acceptance or memory guarantee. Native retained buffers and draw calls still require measurement; nothing is culled from the authored scene to meet this guard.

Metadata entry uses the existing sample schema with `format="dot-customgeometry-scene-v1"`, `mainContractSha="1cd0cdbec06487a5c60f109d5fd477198cfc8846"`, `indexBase=0`, `primitive="TRIANGLE_LIST"`, `materials`, `camera`, `interactionProxies`, `proxyMeshes`; omit `meshes` or set it to `[]`. Keep this file below 4 MiB. Each separate mesh JSON must remain below 32 MiB. These are explicit local read guards and can be reconsidered on actual evidence; do not silently drop content.

## Materials

Same actual sample fields: `id`, `baseColorFactor` RGBA, `baseColorTexture` relative PNG, roughness/metallic scalars in [0,1], `alphaMode`, `doubleSided`, optional `unlit`.

- Implemented native route: OPAQUE or BLEND, RGB/RGBA PNG, scalar PBR roughness/metallic, unlit sea/ship cards, optional double-sided rendering.
- Unsupported: MASK/cutoff transfer, roughness/metallic texture channels, Blender node graphs, transmission/refraction, volumetrics and procedural shaders. MASK fails explicitly; it is not silently converted to BLEND.
- The 26 declared linear OpenGL +Y tangent normal maps are now wired to verified PBRDiffNormal/PBRDiffNormalAlpha techniques and TU_NORMAL. GenerateTangents is called after normals/UVs and before Commit; unavailable/failed API causes explicit load failure and cleanup. The constant-color normal material uses a verified literal-white utility PNG. Native tangent API availability, UV/TBN orientation and visual equivalence remain unverified. All 53 used source PNGs decode successfully offline.
- Bake required procedural base color into UV textures. Preserve alpha on the ship. Sea stays OPAQUE/unlit; ship stays BLEND/unlit.
- Export Blender UV coordinates without additional V flipping; retain the checker. Runtime V orientation is still unverified, and remains an explicit local setting, not a cloud-side corrective rewrite.

## Eight interactions and visual ownership

Keep exact IDs/targets: `home.drawer/letters`, `home.journal/journal`, `home.tray/words`, `home.net/seaside`, `home.caseFile/case`, `home.merchantShip/shop`, `home.letterPaper/paper`, `home.stove/brew`.

User confirmed the visible ownership: green book -> 故事记录 (story and trial/recipe history); tied paper stack -> 案件板. Every hint label and target is now read directly from the pinned main LayoutManifest. Letter paper reads existing letters; it does not create a writing flow. No separate diary feature was added.

Each interactionProxies entry retains `id`, `target`, `position`, `proxyMeshId`, `screenAnchor`, plus **`visibleMeshIds`** naming the exclusively corresponding visible batches. Split interactive object geometry from room/shared batches where needed. This removes the sample-only `group_02/03/05` assumptions and enables occlusion ownership checks. Do not map an entire room batch to an object merely because that object appears in the same material group.

Proxy meshes stay independent `renderVisible=false`, `pickable=true`, with flat positions and zero-based triangle indices. They are never submitted as visible geometry. Ship geometry alone is retained in Lua after upload for alpha-aware picking; all ordinary mesh arrays are released after their batch is committed. Picking remains locked if native camera calibration fails.

## Camera

Keep Blender Z-up positions and normalized forward/up vectors. Existing `camera` contains the Home perspective camera, reference resolution, horizontalFovDegrees and verticalFovDegrees. `screenAnchor` remains normalized top-left origin with Y down. Optional `additionalCameras` uses the same vectors and horizontal FOV, with id `Brew` or `Seaside`. Missing routes remain unavailable; an unprovided camera is not silently invented or called validated.

Extra world/view/basis matrices and precise anchor reference data are welcome diagnostics. Local conversion remains `(x,y,z) -> (x,z,-y)` exactly once. This has determinant +1; it is not proof that the renderer's camera basis matches Blender. The new diagnostic compares mapped right, native node right and screen-ray right, then checks actual rays and WorldToScreenPoint against all 8 anchors. It does not mark calibration passed by disabling a failing assertion.

## Local state and delivery

`scripts/main.lua` now installs the full `scripts/v035/lab35/FullSceneHost.lua` entry with resource prefix `v035-full`, flipV=false and a 300-second loading deadline. It shows loading/failure UI before heavy parsing, reads one mesh file at a time, hides partial geometry until completion, and creates exactly one memory-backed GameSession/PlayModel after geometry loading. Runtime counts, progress and Update frame statistics go to tagged logs. There is no automatic business QA, restart button, disk save adapter or formal project modification. Historical probe entry/manifest are preserved as `probe-main-before-full.lua` and `native-stage-before-full.json` in the evidence directory.

Host diagnostics include elapsed wall time, step duration, Lua memory (where available), Update frame samples and a default 300-second load deadline. A native/JSON call that blocks the main thread cannot be interrupted by Lua; its elapsed time can only be logged after it returns. OS working set/private bytes and liveness need external observation during a later authorized run; a frozen process is not counted as loading progress.

The complete package must be materialized into this Windows Lab, with actual path existence/readability and exact ZIP/hash verification. Previous Library Windows helper failure is not permission to bypass the supported transfer route. Do not use a cloud path as a Windows path.
