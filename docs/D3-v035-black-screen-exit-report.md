# D3 v03.5 native black-screen / exit checkpoint

Captured 2026-10-13 12:43 UTC. Task `01a12c24-a725-712b-ba7d-df58430f5098`; parent `01a100a3-a73b-744f-9fcc-4080f267b036`.

## Current result

**Not accepted: visible native output is unverified, projection calibration fails, business QA is paused.** No restart after the user's crash report. Formal 2D project was not modified in this work segment.

This work imports the actual cloud v03.5 six-mesh sample into the existing UrhoX runtime and connects the pinned main interface adapter. It is not the full room. Probe integrity passed: 9,225,580 bytes; SHA256 `e782c36e3c5445847a13b1ffbb57dea04321ff40086baac4906bbbb0035a179f`; 21 internal hashes passed. Main baseline is `1cd0cdbec06487a5c60f109d5fd477198cfc8846`.

## Black-screen facts

Initial run session `78f06387-9dfa-4308-95c3-1527ad1b28ae`, PID 35888, started at 12:22:02 UTC. First game-start exception at 12:27:34 UTC: `NativeHost:72: native camera does not reproduce cloud anchor projections`. The assertion aborted Start before viewport, UI and Update registration. This is the direct black-screen trigger; the underlying projection discrepancy is not resolved.

Repair 1 explicitly sets camera aspect before projection, changes finite calibration mismatch to a recorded failure instead of terminating Start, and initializes the UI root. Business QA is disabled. Official refresh to reload 1, PID 15448 completed Start and Update. Logs record 6 constructed drawables / 8,128 triangles and passing native ship/stove semantic ray checks. These are engine execution facts, not pixel verification or human-click acceptance.

Calibration still **FAILS**, squared anchor error `1.6078143186974133`. A separate mathematical projection of all 8 original cloud anchors passes, maximum error `1.3790301234273272e-07`; reference camera and anchor data are internally consistent. Native projection/handedness still needs diagnosis.

Native screenshot requests failed: `Image:SavePNG blocked: write blocked: absolute path not allowed`. No engine permission changes were made. Read-only PrintWindow capture waited for the owned Lab title, which was unavailable during loading; it captured no frame. There is no usable new screenshot or recording.

## Authorized restart and subsequent exit

The user explicitly ordered one restart (`Sentinel_dcdff45c7ea48191b6780edd884dc7d8`). Official status showed the old session stopped. One official run was invoked, with the existing Lab Runtime, no install or binding change:

`node <installed-maker>/dist/maker.js preview run --target-dir D:\taptap\To-the-Human-World-3D-Lab --runtime D:\taptap\To-the-Human-World-3D-Lab\.runtime\UrhoXRuntime.exe --duration-ms 600000 --json`

Environment: TAPTAP_MAKER_HOME is Lab `.preview-home`; TEMP/TMP are Lab `tools/tmp`; Python is `C:\Python313\python.exe`.

New session `ad270594-696b-4446-b192-1892e2a00e6a`, supervisor PID 44556, Runtime PID 41116, started at 12:36:59 UTC. Its last game log is 12:37:56 UTC, during official resource download/extraction. No game Start or Lua exception is present in this restart log. Later the command transport reported `executor key changed during session recovery`; subsequent official status reported failed, process_alive=false, stale session retired. **Temporal association does not prove why Runtime exited.** No stop or kill command was issued by this executor in this restart segment. No exit code or crash stack was recovered.

User reported a crash at 12:40 and expressly prohibited further restart (`Sentinel_a143921aea348191b563feaf944697bd`). No further run/start/refresh was issued by this executor.

At 12:42 a read-only status check unexpectedly reported a different Lab session `20e3957e-e9b0-4e1c-82d2-88ae432a9471`, started 12:41:06 UTC, Runtime PID 3332, supervisor PID 50320. This session was not initiated by a tool call in this work segment. It was not refreshed, stopped, captured or otherwise taken over. Its logs must not be attributed to the failed PID 41116. Process-parent lookup was denied; ownership is unresolved.

Windows Application event query (local UTC+8 20:36–20:43, IDs 1000/1001/1002) returned no events matching this failure. No matching UrhoX dump was found in the Lab search; no crash stack is available. This absence does not rule out a crash.

## Files and evidence

- Code changed in the first repair: `v035/scripts/lab35/NativeGeometry.lua`, `v035/scripts/lab35/NativeHost.lua`, and generated copies under `scripts/v035/lab35/`. No code changes followed the crash-report instruction.
- Lab entry: `scripts/main.lua`; historical entry preserved at `docs/evidence/v035-main-interface/legacy-main-before-v035.lua`.
- `docs/evidence/v035-main-interface/native/initial-black-screen-game.jsonl`
- `docs/evidence/v035-main-interface/native/after-first-fix-lua.jsonl`
- `docs/evidence/v035-main-interface/native/authorized-restart-cli.log`
- `docs/evidence/v035-main-interface/native/authorized-restart-game.jsonl` (explicit 20:37 file, not whichever log is newest)
- `docs/evidence/v035-main-interface/native/after-executor-reconnect.json`
- `docs/evidence/v035-main-interface/native/after-user-crash-report.json`
- `docs/evidence/v035-main-interface/native/unattributed-later-session-game.jsonl`
- `docs/evidence/v035-main-interface/native/windows-exit-events.json`
- `docs/evidence/v035-main-interface/native/camera-math-check.json`

Offline rerun at 12:41:17 UTC passed 102 checks and compiled 99 Lua files; all 80 pinned main Lua hashes remain unchanged. Offline checks use real business code with UI/native API substitutes. They do not establish GPU rendering, native UI operation, smoothness, or cross-process save restoration. No native business QA resumed.

## Next step and decisions

First establish who owns the later PID 3332 session, without taking it over. Preserve any user-supplied crash evidence. A future explicitly authorized native diagnostic should log each projected anchor and camera screen-ray basis, establish a correctly oriented visible frame, and only then resume interface QA. Do not launch again from this checkpoint.

Full cloud room import remains outstanding. This sample lacks the room floor, table, dock route and most actual interaction objects; 8 semantic proxies are not a completed room. Existing Seaside UI remains 2D. The current sample does not satisfy the original three-camera/full-room completion criteria.

A2 may review this checkpoint, the interface map and source/hash manifests; this is not A2 approval or user aesthetic acceptance. Reusable work is the validated sample adapter, strict mesh loader, main-backed UI controller and isolated memory session. Remaining costs are native projection/UV/culling validation, actual scene integration, camera route work and native interaction evidence.
