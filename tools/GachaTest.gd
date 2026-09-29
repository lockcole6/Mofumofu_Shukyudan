extends Node
## 開発用：10連ガチャの画面操作をまるごと再現して、表示と中身が合っているか調べる

var main: Control


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.load_game()
	main = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames()
	Game.save.stones = 1000
	Game.save.debug.rates = [50.0, 0.0, 40.0, 10.0]
	Game.save_game()
	main.show_screen("ガチャ")
	await _frames()

	# 1) 10連ボタンを実際にタップ → 石が減るか・上の表示も変わるか
	var btn: Button = null
	for b in main.content.find_children("*", "Button", true, false):
		if b.text.begins_with("10回"):
			btn = b
	var before: int = Game.save.stones
	_tap(btn.get_global_rect().get_center())
	await _frames()
	print("stones %d -> %d  label=%s" % [before, Game.save.stones, main.stones_label.text])
	var ov: Node = _top()
	print("results: ", ov.results.map(func(r): return Game.chars[r.id].name))

	# 2) 演出を1体ずつ進めながら、各キャラを長押し → 詳細が同じキャラか
	#    奇数番目は背景タップで閉じ、偶数番目は戻るで閉じる
	var mism := 0
	for i in 10:
		# 半分は扉が開いている途中から長押しする
		await _wait_phase(ov, "opening" if i % 3 == 2 else "revealed")
		if ov.idx != i:
			print("  !! idx expected %d got %d" % [i, ov.idx])
		var pn0: int = ov._press_n
		await _long_press(Vector2(180, 300))
		var shown := _detail_no()
		print("  i=%d idx=%d rarity=%d phase=%s press_n %d->%d long=%s layers=%d" % [i, ov.idx, ov.results[ov.idx].rarity, ov.phase, pn0, ov._press_n, ov._long, _layers()])
		var want: int = ov.results[ov.idx].id
		if shown != want:
			mism += 1
			print("  !! reveal %d: detail shows No.%d but card is No.%d" % [i, shown, want])
		var idx_before: int = ov.idx
		if i % 2 == 1:
			_tap(Vector2(180, 15))   # モーダルの外（背景）
		else:
			Nav.back()
		await _frames()
		if ov.idx != idx_before or ov.phase != "revealed":
			print("  !! closing detail advanced the reveal: idx %d -> %d phase=%s" % [idx_before, ov.idx, ov.phase])
		_tap(Vector2(180, 300))       # 次へ
		await _frames()
	print("reveal mismatches: ", mism, "  phase=", ov.phase)

	# 3) 結果一覧：全カードを長押し → 詳細が同じキャラか
	await _frames()
	var cards := ov.find_children("*", "MarginContainer", true, false).filter(func(c): return "cid" in c)
	mism = 0
	for c in cards:
		await _long_press(c.get_global_rect().get_center())
		var shown := _detail_no()
		if shown != c.cid:
			mism += 1
			print("  !! summary card No.%d -> detail No.%d  rect=%s layers=%d top=%s phase=%s" % [c.cid, shown, c.get_global_rect(), _layers(), _top(), ov.phase])
			break
		Nav.back()
		await _frames()
	print("summary cards=%d mismatches=%d  layers=%d" % [cards.size(), mism, _layers()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	get_tree().quit()


func _wait_phase(ov, ph: String) -> void:
	for n in 100:
		if ov.phase == ph:
			return
		await get_tree().create_timer(0.05).timeout


func _detail_no() -> int:
	var top := _top()
	if top == null or not top.has_meta("layer") or top.get_class() != "Control" or "results" in top:
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


func _layers() -> int:
	return get_tree().root.get_children().filter(func(c): return c.has_meta("layer")).size()


func _frames() -> void:
	for i in 4:
		await get_tree().process_frame


func _long_press(p: Vector2) -> void:
	_mouse(p, true)
	await get_tree().create_timer(0.6).timeout
	_mouse(p, false)
	await _frames()


func _tap(p: Vector2) -> void:
	_mouse(p, true)
	_mouse(p, false)


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	get_viewport().push_input(e, true)
