extends Node
## 開発用：編成画面の「長押しで持ち上げて運ぶ」の動作確認（終わるとセーブは消える）


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.load_game()
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames()
	main.show_screen("編成")
	await _frames()
	var ts = main.content.get_child(0)
	print("start: 攻=", Game.row_ids("攻"), " 中=", Game.row_ids("中"), " 守=", Game.row_ids("守"))

	# 1) タヌキ(攻)を長押し → ネコ(中)の上で離す → 入れ替え
	await _drag(ts, 2, ts._cards[1].get_global_rect().get_center())
	print("swap: 攻=", Game.row_ids("攻"), " 中=", Game.row_ids("中"))

	# 2) ペンギン(守)を長押し → 攻の列の空いているところで離す → 移動
	var r: Rect2 = ts._rows["攻"].get_global_rect()
	await _drag(ts, 3, Vector2(r.position.x + 40, r.get_center().y))
	print("move: 攻=", Game.row_ids("攻"), " 守=", Game.row_ids("守"))

	# 3) ゾウを長押し → 右端の「外す」で離す → 外れる
	var pr: Rect2 = ts._pitch.get_global_rect()
	await _drag(ts, 6, Vector2(pr.end.x - 20, pr.get_center().y))
	print("remove: in_team(6)=", Game.in_team(6), " team size=", Game.save.formation.size())

	# 4) 短いタップ → 詳細が開く（持ち上がらない）
	var p: Vector2 = ts._cards[5].get_global_rect().get_center()
	_mouse(p, true)
	_mouse(p, false)
	await _frames()
	print("tap -> detail layers=", get_tree().root.get_children().filter(func(c): return c.has_meta("layer")).size(), " dragging=", not ts._drag.is_empty())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	get_tree().quit()


func _drag(ts, id: int, to: Vector2) -> void:
	var from: Vector2 = ts._cards[id].get_global_rect().get_center()
	_mouse(from, true)
	await get_tree().create_timer(0.55).timeout
	print("  lifted ", Game.chars[id].name, ": ", not ts._drag.is_empty())
	for i in 10:
		_move(from.lerp(to, (i + 1) / 10.0))
		await get_tree().process_frame
	if id == 6:
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/shots"))
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/shots/drag.png"))
	_mouse(to, false)
	await _frames()


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
