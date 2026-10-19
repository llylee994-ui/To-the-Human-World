extends SceneTree

## P2 process 2: replay the committed request id after a fresh process start.

const P2FixtureScript = preload("res://tests/support/p2_fixture.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ctx := P2FixtureScript.resume("process-replay")
	if not ctx.get("ok", false):
		print("[P2ReplayVerify] FAIL resume: " + str(ctx))
		quit(1)
		return
	var session: SessionService = ctx.session
	var before: Dictionary = session.snapshot()
	var result := session.execute(P2FixtureScript.request(session, "process-start",
		"start_journey", {}))
	if not result.get("ok", false) or int(result.get("revision", -1)) != 1:
		print("[P2ReplayVerify] FAIL replay: " + str(result))
		quit(1)
		return
	if not DomainResult.equal(session.snapshot(), before):
		print("[P2ReplayVerify] FAIL replay changed the state")
		quit(1)
		return
	if int(ctx.store.load_latest().get("generation", -1)) != 1:
		print("[P2ReplayVerify] FAIL replay added a generation")
		quit(1)
		return
	if session.snapshot().get("chapter", {}).get("started") != true:
		print("[P2ReplayVerify] FAIL journey is not started")
		quit(1)
		return
	ctx.store.delete_slot()
	print("[P2ReplayVerify] PASS cross-process replay revision=1 without a new generation")
	quit(0)
