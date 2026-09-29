extends Node
## 開発用：編成画面の操作を検査する（終わるとセーブは消える）
## タップで選択・長押しで詳細・ドラッグで入れ替え／列の移動／控えへ下げる／控えから出場・入れ替えボタン


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.load_game()
	Game.add_character(22)   # 控えにクマ
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames()
	main.show_screen("編成")
	await _frames()
	var ts = main.content.get_child(0)
	print("start: FW=", Game.row_ids("攻"), " MF=", Game.row_ids("中"), " DF=", Game.row_ids("守"), " GK=", Game.row_ids("GK"))

	# 1) タップで選択 → 下の欄がその選手になる
	_tap(_center(ts._pitch.players[9]))
	await _frames()
	print("tap select: sel=", ts.sel, " (イルカ=9)  layers=", _layers())

	# 2) 長押しで詳細
	await _long_press(_center(ts._pitch.players[9]))
	print("long press: layers=", _layers(), " dragging=", not ts._drag.is_empty())
	Nav.back()
	await _frames()

	# 3) タヌキ(FW)をネコ(MF)の上へ → 入れ替え
	await _drag(_center(ts._pitch.players[2]), _center(ts._pitch.players[1]))
	print("swap: FW=", Game.row_ids("攻"), " MF=", Game.row_ids("中"))

	# 4) ペンギン(DF)を FW の帯の空いたところへ → 移動
	var pr: Rect2 = ts._pitch.get_global_rect()
	await _drag(_center(ts._pitch.players[3]), Vector2(pr.position.x + 20, pr.position.y + pr.size.y * 0.13))
	print("move: FW=", Game.row_ids("攻"), " DF=", Game.row_ids("守"))

	# 5) ゾウを控えへ → 外れる
	await _drag(_center(ts._pitch.players[6]), ts._bench.get_global_rect().get_center())
	print("to bench: in_team(6)=", Game.in_team(6), " team=", Game.save.formation.size())

	# 6) 控えのクマをピッチの DF の帯へ → 出場
	var bear: Control = null
	for c in ts._bench.find_children("*", "MarginContainer", true, false):
		if "cid" in c and c.cid == 22:
			bear = c
	pr = ts._pitch.get_global_rect()
	await _drag(_center(bear), Vector2(pr.get_center().x, pr.position.y + pr.size.y * 0.63))
	print("from bench: in_team(22)=", Game.in_team(22), " DF=", Game.row_ids("守"))

	# 7) 選択中の選手の「入れ替え」ボタン → 選手選択が開く
	_tap(_center(ts._pitch.players[4]))
	await _frames()
	var btn: Button = null
	for b in ts.find_children("*", "Button", true, false):
		if b.find_children("*", "Label", true, false).any(func(l): return l.text == "入れ替え"):
			btn = b
	_tap(_center(btn))
	await _frames()
	print("swap button: layers=", _layers())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	get_tree().quit()


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _layers() -> int:
	return get_tree().root.get_children().filter(func(c): return c.has_meta("layer")).size()


func _drag(from: Vector2, to: Vector2) -> void:
	_mouse(from, true)
	for i in 12:
		_move(from.lerp(to, (i + 1) / 12.0))
		await get_tree().process_frame
	_mouse(to, false)
	await _frames()


func _long_press(p: Vector2) -> void:
	_mouse(p, true)
	await get_tree().create_timer(0.6).timeout
	_mouse(p, false)
	await _frames()


func _tap(p: Vector2) -> void:
	_mouse(p, true)
	_mouse(p, false)


func _frames() -> void:
	for i in 4:
		await get_tree().process_frame


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	get_viewport().push_input(e, true)


func _move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e, true)
