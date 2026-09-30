extends Node
## 開発用：試合中のロック・フリーマッチ・個人スキル一覧の更新・連携スキル全表示（終わるとセーブは消える）


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.load_game()
	Game.save.tutorial_done = true
	Game.place_starters()
	Game.save.settings.speed = "fast"
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames()
	var ms = main.content.get_child(0)

	# 1) リーグ戦のキックオフ → 試合中はタブと戻るが効かない → 終わると戻る
	ms._kickoff(false)
	await get_tree().create_timer(1.0).timeout
	print("during match: tabs disabled=", main.tab_buttons["編成"].disabled, " nav locked=", Nav.locked)
	main.tab_buttons["編成"].pressed.emit()
	Nav.back()
	await _frames()
	print("  tried tab + back: tab=", main.current, " still in match=", ms.get_child_count() > 2)
	await get_tree().create_timer(7.0).timeout
	print("after match: tabs disabled=", main.tab_buttons["編成"].disabled, " nav locked=", Nav.locked, " round=", Game.save.league.round)
	Nav.back()
	await _frames()

	# 2) フリーマッチ：順位表は変わらない
	ms.mode = "フリーマッチ"
	ms.free_div = 3
	ms.show_league()
	await _frames()
	var fo := Game.free_opponent(3)
	var round_before: int = Game.save.league.round
	var pts_before: int = Game.save.league.table[0].pts
	Game.save.settings.speed = "instant"
	ms._kickoff(true)
	await get_tree().create_timer(0.5).timeout
	print("free match vs %s(3部相当): outcome=%s reward=%d  league round %d->%d pts %d->%d" % [fo.name, ms.result.outcome, ms.result.reward,
		round_before, Game.save.league.round, pts_before, Game.save.league.table[0].pts])
	var btn: Button = null
	for b in ms.find_children("*", "Button", true, false):
		if b.text == "フリーマッチへ":
			btn = b
	print("  back button: ", btn != null, "  tabs locked after: ", main.tab_buttons["編成"].disabled)
	await _shot("free_result")
	btn.pressed.emit()
	await _frames()
	await _shot("free_top")

	# 3) 個人スキル一覧 → 詳細でスキル強化 → 一覧が更新される
	Game.save.roster["1"].copies = 5
	main.show_screen("編成")
	await _frames()
	var ts = main.content.get_child(0)
	ts._show_skills()
	await _frames()
	var lv_before := _find_label_text("Lv", 0)
	var CharDetail = load("res://scripts/ui/CharDetail.gd")
	for pn in get_tree().root.get_children().filter(func(c): return c.has_meta("layer")).back().find_children("*", "PanelContainer", true, false):
		pass
	CharDetail.open(ts, 1, {"team": true, "on_change": func(): pass})
	await _frames()
	# 一覧から開いたのと同じように、on_change で一覧を更新するか確認するため、一覧のパネルをタップする
	for c in get_tree().root.get_children():
		if c.has_meta("layer"):
			pass
	Nav.back()
	await _frames()
	# ネコのパネルをタップ → 詳細 → 強化
	var modal: Node = get_tree().root.get_children().filter(func(c): return c.has_meta("layer")).back()
	var neko: Control = null
	for pn in modal.find_children("*", "PanelContainer", true, false):
		if pn.find_children("*", "Label", true, false).any(func(l): return l.text == "ネコ"):
			neko = pn
	_tap(neko.get_global_rect().get_center())
	await _frames()
	var up: Button = null
	for b in get_tree().root.find_children("*", "Button", true, false):
		if b.text.begins_with("スキル強化"):
			up = b
	up.pressed.emit()
	await _frames()
	Nav.back()
	await _frames()
	modal = get_tree().root.get_children().filter(func(c): return c.has_meta("layer")).back()
	var tags := modal.find_children("*", "Label", true, false).filter(func(l): return l.text.begins_with("Lv")).map(func(l): return l.text)
	print("skills list after skill up: Lv tags=", tags, "  ネコ slv=", Game.slv(1))
	await _shot("skills")
	Nav.back()
	await _frames()

	# 4) 連携スキル：全部表示
	ts = main.content.get_child(0)
	ts._show_combos()
	await _frames()
	modal = get_tree().root.get_children().filter(func(c): return c.has_meta("layer")).back()
	var n := modal.find_children("*", "PanelContainer", true, false).filter(func(p): return p.get_parent() is VBoxContainer and p.get_parent().get_parent() is ScrollContainer).size()
	print("combos shown: ", n, " / ", Game.combos.size())
	await _shot("combos")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	get_tree().quit()


func _find_label_text(prefix: String, _i: int) -> String:
	return ""


func _shot(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/shots"))
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tools/shots/%s.png" % name))


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
