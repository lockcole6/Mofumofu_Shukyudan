extends Node
## 開発用：初回チュートリアルを最後まで操作する／エンディングの表示（終わるとセーブは消える）


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.load_game()
	Game.save.settings.speed = "instant"
	print("fresh save: tutorial_done=", Game.save.tutorial_done, " formation=", Game.save.formation.size(), " roster=", Game.save.roster.size())
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames()
	var tut: Node = _find_tut()
	print("tutorial shown: ", tut != null)
	await _shot("t0")
	_tap(Vector2(180, 320))          # 説明 → 次へ
	await _frames()
	await _shot("t1")
	print("step=", tut.step)
	# 暗いところ（図鑑タブ）を押しても何も起きない
	_tap(main.tab_buttons["図鑑"].get_global_rect().get_center())
	await _frames()
	print("tap dimmed 図鑑: tab=", main.current, " step=", tut.step)
	_tap(main.tab_buttons["編成"].get_global_rect().get_center())
	await _frames()
	print("tap 編成: tab=", main.current, " step=", tut.step)
	await _shot("t2")
	# おまかせ編成 → バランス
	var ts = main.content.get_child(0)
	ts._auto("バランス")
	await _frames()
	print("after auto: team=", Game.save.formation.size(), " step=", tut.step)
	_tap(Vector2(180, 320))
	await _frames()
	_tap(main.tab_buttons["試合"].get_global_rect().get_center())
	await _frames()
	print("tap 試合: tab=", main.current, " step=", tut.step)
	await _shot("t5")
	var r: Rect2 = tut._kickoff_rect()
	_tap(r.get_center())
	await get_tree().create_timer(1.0).timeout
	print("after kickoff: round=", Game.save.league.round, " step=", tut.step)
	await _shot("t6")
	for i in 3:
		_tap(Vector2(180, 100))
		await _frames()
	print("finished: tutorial_done=", Game.save.tutorial_done, " tut alive=", is_instance_valid(tut))
	Nav.back()
	await _frames()

	# エンディング
	Game.save.record.titles = 1
	main.show_ending(true)
	await get_tree().create_timer(0.5).timeout
	await _shot("e0_celebrate")
	var en: Node = get_tree().root.get_children().filter(func(c): return c.has_meta("layer")).back()
	_tap(Vector2(180, 320))
	await get_tree().create_timer(6.0).timeout
	await _shot("e1_credits")
	_tap(Vector2(180, 320))
	await _frames()
	await _shot("e2_end")
	print("ending phase=", en.phase, " continue visible=", en._cont.visible)
	en._cont.pressed.emit()
	await _frames()
	print("closed: ", not is_instance_valid(en) or en.is_queued_for_deletion())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	get_tree().quit()


func _find_tut() -> Node:
	for c in get_tree().root.get_children():
		if "steps" in c:
			return c
	return null


func _shot(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/shots"))
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/shots/%s.png" % name))


func _frames() -> void:
	for i in 5:
		await get_tree().process_frame


func _tap(p: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		get_viewport().push_input(e, true)
