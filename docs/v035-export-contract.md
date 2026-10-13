# v03.5 cloud export contract — local implementation route

**Current full-scene update (2026-10-13):** use [v035-full-scene-contract.md](v035-full-scene-contract.md) for the operative streaming contract. The six-mesh sample was delivered and constructed in native Runtime; its projection/pixel acceptance remains failed/unverified. Full export is now required, split through `manifest.meshFiles`; no native restart is authorized. The original proposal and transfer history below are preserved as history, not current acceptance.

Status: proposed engineering interchange, 2026-10-13. Native loading and visual acceptance are NOT verified. Dedicated task: `01a12c24-a725-712b-ba7d-df58430f5098`.

## Supported local route

Local UrhoX documentation and bindings expose native `.mdl` loading and `CustomGeometry.BeginGeometry/DefineVertex/DefineNormal/DefineTexCoord/Commit/SetMaterial`. No documented `.blend`, `.glb`, FBX importer or callable Blender/AssetImporter conversion tool was found. Do not export GLB alone and treat it as loadable.

Export the actual evaluated v03.5 Blender geometry into the neutral mesh package below. The Lab can convert it to Lua mesh data and load it using documented CustomGeometry. This preserves the cloud scene's geometry, unlike rebuilding the old procedural scene. This is a feasible API route, not an already-tested import.

## Small sample first

Supply a representative opaque textured room/door mesh, a stove piece, the independently textured sea card and merchant-ship card, one camera and all interaction anchors. Include a UV checker image/material for orientation validation. First confirm material transfer, axes, face winding, UVs and transparency; then export the full scene. Do not create 10,801 runtime nodes.

## Package format (version 1)

- `scene.json`: `format="d3-v035-mesh-v1"`, source Blender filename/version/hash, `axis="BLENDER_Z_UP"`, `unitScale`, `meshes`, `materials`, `cameras`, `anchors`, export statistics.
- `meshes`: each entry has unique `id`, `materialId`, `positions` (flat xyz array), `normals` (flat xyz array), `uv0` (flat uv array), and `indices` (flat ZERO-based triangle indices). World transforms are baked; no unapplied transform matrices. Vertices split at UV seams and hard normals. Apply modifiers through evaluated meshes; triangulate; include visible render instances. Normals use the inverse-transpose transform. Correct face winding for mirrored objects before exporting. `sourceObjects` preserves original membership.
- Export Blender world coordinates unchanged. Local conversion is exactly `(x,y,z) -> (x,z,-y)` once, applied to positions, normals, camera vectors and anchors. This transform has positive determinant; it does not itself reverse triangle winding. Keep UVs unchanged in the export and state the image origin; verify the final image orientation with the checker rather than silently flipping twice.
- Merge opaque static geometry by material and sensible spatial groups (room, table, door, near dock). Keep door openings/occlusion intact. Chunk large batches; report vertex/triangle counts. Exact budgets will be measured, not claimed in advance.
- Keep the sea card, merchant ship, transparent surfaces, animated items and interaction proxies separate. Do not merge all transparent cards or put the complete room on a plane.
- `materials`: unique `id`, `baseColor` RGBA, optional relative `baseColorTexture`, numeric roughness/metallic, `alphaMode` (`OPAQUE`, `BLEND`, or `MASK`), optional `alphaCutoff`, `doubleSided`. All images included as PNG (retain alpha); no external absolute paths. Bake Blender procedural node appearance into UV base-color textures where needed. Lighting appearance and node graphs do not transfer automatically; unsupported channels must be listed, never silently claimed as preserved.
- `cameras`: named Home, optional Brew/Seaside, with world `position`, normalized `forward`, `up`, projection type and horizontal/vertical FOV with explicit units; include orthographic scale if relevant. Do not send Euler rotation alone. Near/far settings and frame aspect ratio are useful.
- `anchors`: stable business `id`, Blender world `position`, source object names, optional explicit proxy bounds/shape. Keep proxies independent from merged visual meshes. A point alone is sufficient for a label, not a complete pick volume.
- `statistics`: evaluated visible source objects, exported meshes/materials/textures, triangles, vertices, total texture bytes, source and output SHA256 manifest; include actual Home render and a bounds/wireframe reference.

## Main semantic IDs and supplied anchor positions

Pinned main: `1cd0cdbec06487a5c60f109d5fd477198cfc8846`.

| Stable ID | Target | Blender world anchor | Binding status |
|---|---|---|---|
| home.drawer | letters | (1.186,-0.102,1.370) | supplied |
| home.journal | journal | (3.579,0.229,1.877) | proposed green notebook binding |
| home.tray | words | (1.126,1.165,1.879) | supplied |
| home.net | seaside | (-3.920,2.110,2.280) | supplied |
| home.caseFile | case | (4.163,-0.216,1.866) | proposed tied paper-stack binding |
| home.merchantShip | shop | (-34.831,57.009,-1.114) | supplied; distant camera-facing card |
| home.letterPaper | paper | (2.380,0.655,1.852) | supplied |
| home.stove | brew | (2.087,1.929,2.357) | supplied |

Scissors has no independent Home business target. Cut remains Reader `model.Cut(spanId)`. Journal/case visual assignments are implementation proposals from the parent, not original named mesh contracts or final aesthetic approval.

## Local blockers

Official Library preparation succeeded for complete ZIP `libfile_f0f734c339f8819184fc10b1aa8f376c`, expected 39,841,319 bytes. First helper transfer failed to download under restricted networking. One authorized retry reached metadata application and failed with `AttributeError: module 'os' has no attribute 'setxattr'`. The destination ZIP does not exist. No metadata was removed, helper patched, temporary download reused, or unofficial download route attempted.

Thus the v03.5 ZIP, scene and reference pixels have not been locally inspected. A Windows-supported official materialization route (or user-provided local file in Lab) is still required. Cloud export can be prepared independently using this contract, but the same transfer issue must be resolved for delivery. Native preview also needs explicit renewed permission; no preview was started in this task.
