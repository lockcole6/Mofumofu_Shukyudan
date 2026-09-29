extends Node
## 開発用：ガチャ演出の SKIP を、扉が閉じている／開いている途中／キャラが出た後 に押して、
## その後の結果一覧が正しく動くか調べる（タッチ入力）

var main: Control


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.load_game()
	main = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames()
	Game.save.debug.rates = [50.0, 0.0, 40.0, 10.0]
	for when in ["closed", "opening", "revealed", "detail"]:
		Game.save.stones = 1000
		main.show_screen("ガチャ")
		await _frames()
		main.content.get_child(0)._pull(10)
		await _frames()
		var ov: Node = _top()
		await _wait_phase(ov, "revealed" if when == "detail" else when)
		if when == "detail":
			# 詳細を開いたまま戻るで閉じてから SKIP
			await _long_press(Vector2(180, 300))
			Nav.back()
			await _frames()
		var skip: Button = null
		for c in ov.get_children():
			if c is Button:
				skip = c
		_tap(skip.get_global_rect().get_center())
		await get_tree().create_timer(1.0).timeout
		var ok1: bool = ov.phase == "summary"
		# 結果一覧で何もないところをタップ・カードを短くタップ
		_tap(Vector2(180, 560))
		await _frames()
		var cards := ov.find_children("*", "MarginContainer", true, false).filter(func(c): return "cid" in c)
		if not cards.is_empty():
			_tap(cards[0].get_global_rect().get_center())
		await get_tree().create_timer(0.3).timeout
		var still: bool = is_instance_valid(ov) and ov.phase == "summary"
		var n_cards := ov.find_children("*", "MarginContainer", true, false).filter(func(c): return "cid" in c).size() if is_instance_valid(ov) else -1
		# 最後のカードを長押し → 詳細が同じキャラか
		var match_ok := false
		if is_instance_valid(ov) and n_cards > 0:
			var last: Control = ov.find_children("*", "MarginContainer", true, false).filter(func(c): return "cid" in c).back()
			await _long_press(last.get_global_rect().get_center())
			match_ok = _detail_no() == last.cid
			Nav.back()
			await _frames()
		print("SKIP at %-8s -> summary=%s  after taps still summary=%s cards=%d  last card detail ok=%s" % [when, ok1, still, n_cards, match_ok])
		if is_instance_valid(ov):
			Nav.close(ov)
		await _frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	get_tree().quit()


func _wait_phase(ov, ph: String) -> void:
	for n in 200:
		if ov.phase == ph:
			return
		await get_tree().create_timer(0.02).timeout


func _detail_no() -> int:
	var top := _top()
	if top == null or "results" in top:
		return -1
	for l in top.find_children("*", "Label", true, false):
		if l.text.begins_with("No."):
			return int(l.text.substr(3, 2))
	return -1


func _top() -> Node:
	var r := get_tree().root
	for i in range(r.get_child_count() - 1, -1, -1):
		if r.get_child(i).has_meta("layer"):
			return r.get_child(i)
	return null


func _frames() -> void:
	for i in 4:
		await get_tree().process_frame


func _long_press(p: Vector2) -> void:
	_touch(p, true)
	await get_tree().create_timer(0.6).timeout
	_touch(p, false)
	await _frames()


func _tap(p: Vector2) -> void:
	_touch(p, true)
	_touch(p, false)


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = pos * (Vector2(get_window().size) / Vector2(360, 640))
	Input.parse_input_event(e)
