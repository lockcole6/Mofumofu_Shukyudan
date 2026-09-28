extends Node
## 開発用：ドラッグスクロールと「戻る」の動作確認（終わるとセーブは消える）

const CharDetail = preload("res://scripts/ui/CharDetail.gd")


func _ready() -> void:
	# 0) v2（4x4マス）のセーブを列形式に変換できるか
	var v2 := {"version": 2, "stones": 123, "roster": {"4": {"slv": 1, "copies": 0}, "18": {"slv": 1, "copies": 0}, "1": {"slv": 1, "copies": 0}},
		"formation": [{"id": 1, "cell": 6}, {"id": 4, "cell": 13}, {"id": 18, "cell": 14}],
		"league": {"division": 5, "season": 1, "round": 0, "teams": [{"name": "a", "player": true}, {"name": "b", "members": [{"id": 3, "cell": 9}, {"id": 10, "cell": 13}]}],
			"schedule": [], "table": []}}
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(v2))
	f.close()
	Game.load_game()
	print("migrated: stones=", Game.save.stones, " formation=", Game.save.formation, " ai=", Game.save.league.teams[1].members)
	# ルール：GKは1人（入れると交代）、列は4人まで
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.load_game()
	Game.add_character(10)
	Game.add_character(22)
	print("GK before: ", Game.row_ids("GK"), " place GK: '", Game.place(10, "GK"), "' after: ", Game.row_ids("GK"), " team=", Game.save.formation.size())
	Game.remove_from_team(3)
	Game.place(22, "攻")
	print("攻: ", Game.row_ids("攻"), " formation ", Game.formation_name())
	Game.place(3, "攻")
	print("攻 full try: '", Game.place(9, "攻"), "'")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.load_game()
	for id in Game.chars:
		Game.add_character(id)
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames()

	# 1) 選手選択モーダル（40体）でカードの上からドラッグ → スクロールする・選択されない
	main.show_screen("編成")
	await _frames()
	Game.remove_from_team(2)
	main.content.get_child(0)._picker("攻")
	await _frames()
	var layer: Node = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	var sc: ScrollContainer = layer.find_children("*", "ScrollContainer", true, false)[0]
	var p := sc.get_global_rect().get_center()
	var team_before: int = Game.save.formation.size()
	_mouse(p, true)
	for i in 12:
		_move(p + Vector2(0, -15 * (i + 1)))
		await get_tree().process_frame
	_mouse(p + Vector2(0, -180), false)
	await _frames()
	print("scroll after drag: ", sc.scroll_vertical, "  still open: ", _layers(), "  team size unchanged: ", Game.save.formation.size() == team_before)
	await get_tree().create_timer(0.5).timeout
	print("scroll after inertia: ", sc.scroll_vertical)
	Nav.back()
	main.show_screen("図鑑")
	await _frames()
	var dex = main.content.get_child(0)
	sc = _find_scroll(dex)
	p = sc.get_global_rect().get_center()

	# 2) タップ → 詳細が開く、戻るで閉じる
	sc.scroll_vertical = 0
	await _frames()
	_mouse(p, true)
	_mouse(p, false)
	await _frames()
	print("tap opens modal: ", _layers(), "  has_back: ", Nav.has_back())
	Nav.back()
	await _frames()
	print("after back: layers=", _layers(), " tab=", main.current)

	# 3) タブ移動 → 戻るで前のタブへ
	main.show_screen("ガチャ")
	await _frames()
	Nav.back()
	await _frames()
	print("tab back -> ", main.current, "  back button visible: ", main.back_btn.visible)
	Nav.back()
	await _frames()
	print("tab back -> ", main.current, "  back button visible: ", main.back_btn.visible)

	# 4) 試合 → 戻るで順位表
	Game.save.settings.speed = "instant"
	Game.auto_formation()
	main.show_screen("試合")
	await _frames()
	var ms = main.content.get_child(0)
	ms._kickoff()
	await _frames()
	Nav.back()
	await _frames()
	print("after match back, round=", Game.save.league.round, " view children=", ms.get_child_count())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	get_tree().quit()


func _layers() -> int:
	return get_tree().root.get_children().filter(func(c): return c.has_meta("layer")).size()


func _find_scroll(n: Node) -> ScrollContainer:
	for c in n.get_children():
		if c is ScrollContainer:
			return c
	return null


func _frames() -> void:
	for i in 3:
		await get_tree().process_frame


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	get_viewport().push_input(e)


func _move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e)
