extends Node
## 開発用：控えのスクロール位置・おまかせの型・試合→編成の戻る・編成プリセット（終わるとセーブは消える）


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.load_game()
	Game.save.tutorial_done = true
	Game.place_starters()
	for id in Game.chars:
		Game.add_character(id)
	Game.new_season(1)   # コスト上限20
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames()

	# 1) 試合 → 「自分の編成を変える」→ 編成に戻るボタン → 試合へ
	var ms = main.content.get_child(0)
	ms._goto_team()
	await _frames()
	var ts = main.content.get_child(0)
	print("from match: tab=", main.current, " back_to=", ts.back_to)
	var bk: Button = null
	for b in ts.find_children("*", "Button", true, false):
		if b.text.begins_with("‹"):
			bk = b
	bk.pressed.emit()
	await _frames()
	print("back pressed: tab=", main.current)
	main.show_screen("編成")
	await _frames()
	ts = main.content.get_child(0)

	# 2) 控えを右へスクロール → 控えの選手をタップ → 位置がそのまま
	ts._bench_sc.scroll_horizontal = 300
	await _frames()
	var x0: int = ts._bench_sc.scroll_horizontal
	var target: Control = null
	for c in ts._bench.find_children("*", "MarginContainer", true, false):
		if "cid" in c and c.get_global_rect().intersects(ts._bench_sc.get_global_rect()) and c.get_global_rect().position.x > ts._bench_sc.get_global_rect().position.x + 60:
			target = c
			break
	_tap(target.get_global_rect().get_center())
	await _frames()
	ts = main.content.get_child(0)
	print("bench scroll before=%d after select=%d  sel=%d" % [x0, ts._bench_sc.scroll_horizontal, ts.sel])

	# 3) おまかせの型：DF と FW に入った選手の★
	for style in Game.AUTO_STYLES:
		Game.auto_formation(style)
		var r := {}
		for row in ["攻", "中", "守", "GK"]:
			r[Game.POS_LABEL[row]] = Game.row_ids(row).map(func(id): return "%s★%d" % [Game.chars[id].name, Game.chars[id].rarity])
		print("%s %s cost=%d  %s" % [style, Game.formation_name(), Game.formation_cost(), r])

	# 4) プリセット：2番に切り替え → いまの編成のコピーから始まる → 変更 → 1番に戻る → 2番に戻ると変更が残っている
	Game.auto_formation("バランス")
	var p1 := Game.formation_name()
	Game.select_preset(1)
	print("preset2 starts empty: ", Game.save.formation.is_empty(), " ", Game.formation_name())
	Game.auto_formation("攻撃型")
	Game.select_preset(0)
	print("back to preset1: ", Game.formation_name(), "  names=", range(5).map(func(i): return Game.preset_name(i)))
	Game.select_preset(1)
	print("preset2 kept: ", Game.formation_name())
	Game.load_game()
	print("after reload: preset=", Game.save.preset, " ", Game.formation_name(), " names=", range(5).map(func(i): return Game.preset_name(i)))
	# 5) 名前：初期は「チーム1」…、長い名前は5文字で切る、空なら初期名、入力欄から変える
	print("default names: ", range(5).map(func(i): return Game.preset_title(i)))
	Game.rename_preset(2, "とても長いチーム名")
	Game.rename_preset(3, "   ")
	print("long -> ", Game.preset_title(2), "  empty -> ", Game.preset_title(3))
	main.show_screen("編成")
	await _frames()
	var UI = load("res://scripts/ui/UI.gd")
	UI.rename_dialog(main.content.get_child(0), 0, func(): pass)
	await _frames()
	var le: LineEdit = get_tree().root.find_children("*", "LineEdit", true, false)[0]
	le.text = "こうげき"
	le.text_submitted.emit(le.text)
	await _frames()
	Game.load_game()
	print("renamed via dialog + reload: ", Game.preset_title(0), "  max_length=", le.max_length if is_instance_valid(le) else -1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	get_tree().quit()


func _frames() -> void:
	for i in 4:
		await get_tree().process_frame


func _tap(p: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		get_viewport().push_input(e, true)
