extends SceneTree

## P2 process 1: commit start_journey into an isolated P2 slot, then exit.

const P2FixtureScript = preload("res://tests/support/p2_fixture.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ctx := P2FixtureScript.open("process-replay")
	if not ctx.get("ok", false):
		print("[P2ReplaySeed] FAIL open: " + str(ctx))
		quit(1)
		return
	var session: SessionService = ctx.session
	var result := session.execute(P2FixtureScript.request(session, "process-start",
		"start_journey", {}))
	if not result.get("ok", false) or int(result.get("revision", -1)) != 1:
		print("[P2ReplaySeed] FAIL start: " + str(result))
		quit(1)
		return
	print("[P2ReplaySeed] PASS revision=1 request=process-start")
	quit(0)
