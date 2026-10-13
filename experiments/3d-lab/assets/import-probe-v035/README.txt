CustomGeometry import probe, not the full accepted room.
Entry: manifest.json → probe.json. All paths inside this archive are relative.
Unpack into experiments/3d-lab/assets/import-probe-v035/ under the Lab checkout.
Do not execute the included scripts automatically; they are source/validation references.

Visible sample: door boards, major timber posts, plaster walls, copper cauldron and brass supports, background image card and separate transparent boat card. Table, floor, net geometry and other room objects are intentionally absent. Blender preview therefore shows incomplete boundaries; it is not a new artistic checkpoint or an engine screenshot.

Six merged render meshes, 8,128 triangles. Eight separate invisible interaction proxy quads, 16 triangles. IDs and routes are pinned to main 1cd0cdbec06487a5c60f109d5fd477198cfc8846. Journal binds tentatively to green notebook; caseFile to right tied parchment; these are proposed Blender semantic mappings, not established main object names.

Mesh fields: id, materialId, positions (flat xyz), normals (flat xyz), uv0 (flat uv), indices (flat 0-based triangle indices). Modifier results and world transforms are baked into coordinates. Blender RH Z-up; requested consumer transform is (x,y,z)→(x,z,-y), also apply to normals and camera vectors. Check engine winding/culling rather than assuming it from a screenshot. UV is unchanged Blender bottom-left; use checker PNG and checker reference render to test engine texture V orientation.
Camera position, forward, up, perspective type and vertical/horizontal FOV in degrees are in probe.json. Original design aspect 1672/941.

Materials: four 1024x1024 base-color textures baked from procedural source materials. Metallic and roughness are scalar source values; procedural bump/roughness variation is NOT yet baked, and these materials are not final equivalence. Two unlit PNG materials retain original game sea-calm and merchant-ship-muted, including source alpha. BLEND boat must render after opaque backdrop, use appropriate depth-write policy, and not intercept clicks in transparent pixels. Proxy material has alpha0 and renderVisible=false; use a dedicated invisible picking layer, not visible scene rendering.

Main scene business: never ReceiveLetter merely when clicking net; preserve AppView BeginHomeZoom→Seaside and existing salvage UI. Scissors has no independent main hotspot; actual CutWord requires a selected letter and span. Keep date/currency from snapshot, end-day confirmation/action gate, HUD and modal input ordering. See main_constraints.json.

Validation: finite coordinates, array lengths, indices, unit normals and texture readability; source JSON arrays rebuilt in Blender and rendered for shape/UV inspection. This does NOT validate UrhoX. No engine performance or picking success claimed. Probe uses duplicated/exported data; accepted hybrid_scene.blend unchanged.
Source asset: Library v03.5 complete scene libfile_f0f734c339f8819184fc10b1aa8f376c v0. Sea/ship images from user's repository fengyycon ff463d874d0fb5ff7aacdb93af6309b30369d1e5, assets/image/misty-harbor-r1/. No whole-room screenshot plane is included.

128 zero-area copper-pole triangles were removed after export; they cover no visible surface, so the reference preview appearance is unchanged. Run remove_degenerates.py after exporting and adding proxies when rebuilding the package.
