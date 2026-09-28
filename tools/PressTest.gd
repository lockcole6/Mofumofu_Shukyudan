extends Node
## 開発用：長押しで詳細・スカウトの選択→確定の動作確認（終わるとセーブは消える）


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.load_game()
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames()

	# ガチャ結果：短いタップでは開かず、長押しで詳細が開く
	Game.save.stones = 1000
	main.show_screen("ガチャ")
	await _frames()
	main.content.get_child(0)._pull(10)
	await _frames()
	var ov: Node = _top()
	# 演出中：出てきたキャラを長押し → 詳細、タップ → 次へ
	await get_tree().create_timer(1.8).timeout
	var c0 := Vector2(180, 300)
	_mouse(c0, true)
	await get_tree().create_timer(0.6).timeout
	_mouse(c0, false)
	await _frames()
	print("reveal long press -> layers: ", _layers(), " idx=", ov.idx)
	Nav.back()
	await _frames()
	_mouse(c0, true)
	_mouse(c0, false)
	await _frames()
	print("reveal tap -> idx=", ov.idx)
	ov._show_summary()
	await _frames()
	var card: Control = ov.find_children("*", "MarginContainer", true, false)[0]
	var p := card.get_global_rect().get_center()
	var mm := InputEventMouseMotion.new()
	mm.position = p
	mm.global_position = p
	get_viewport().push_input(mm, true)
	await _frames()
	print("card=", card, " rect=", card.get_global_rect(), " hovered=", get_viewport().gui_get_hovered_control(), " filter=", card.mouse_filter)
	_mouse(p, true)
	await get_tree().create_timer(0.1).timeout
	_mouse(p, false)
	await _frames()
	print("short tap on gacha card -> layers: ", _layers())
	_mouse(p, true)
	await get_tree().create_timer(0.6).timeout
	_mouse(p, false)
	await _frames()
	print("long press on gacha card -> layers: ", _layers(), " (detail on top: ", _top() != ov, ")")
	Nav.back()
	Nav.back()
	await _frames()

	# 試合に勝つまで回して、スカウトを 選択→確定
	Game.save.settings.speed = "instant"
	for id in Game.chars:
		Game.add_character(id)
	Game.new_season(5)
	Game.auto_formation()
	main.show_screen("試合")
	await _frames()
	var ms = main.content.get_child(0)
	for n in 20:
		ms._kickoff()
		await _frames()
		if ms.result.outcome == "win":
			break
		Nav.back()
		await _frames()
		if Game.season_over():
			Game.new_season(5)
	var grid: GridContainer = ms.find_children("*", "GridContainer", true, false)[0]
	var btn: Button = null
	for b in ms.find_children("*", "Button", true, false):
		if b.text.begins_with("スカウトする"):
			btn = b
	print("before pick: button disabled=", btn.disabled, " text=", btn.text)
	var target: Control = grid.get_child(0)
	for c in grid.get_children():
		if not c.dim:
			target = c
			break
	var tp := target.get_global_rect().get_center()
	_mouse(tp, true)
	_mouse(tp, false)
	await _frames()
	print("after pick: disabled=", btn.disabled, " text=", btn.text, " selected=", target.selected, " scouted=", ms.scouted)
	btn.pressed.emit()
	await _frames()
	print("after confirm: scouted=", ms.scouted, " button gone=", not is_instance_valid(btn) or btn.is_queued_for_deletion())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	get_tree().quit()


func _top() -> Node:
	var r := get_tree().root
	for i in range(r.get_child_count() - 1, -1, -1):
		if r.get_child(i).has_meta("layer"):
			return r.get_child(i)
	return null


func _layers() -> int:
	return get_tree().root.get_children().filter(func(c): return c.has_meta("layer")).size()


func _frames() -> void:
	for i in 3:
		await get_tree().process_frame


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	get_viewport().push_input(e, true)
