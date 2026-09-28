extends Node
## 開発用：ロジックの統計と各画面のスクリーンショットを出す。
## 実行: Godot --path . res://tools/Shots.tscn  （終わるとセーブは消える）

const OUT := "res://tools/shots/"
const CharDetail = preload("res://scripts/ui/CharDetail.gd")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.load_game()
	_stats()
	if "stats" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.load_game()
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	for tab in ["編成", "試合", "図鑑", "ガチャ", "設定"]:
		main.show_screen(tab)
		await _shot(tab)
	# 編成：詳細と選手選択
	main.show_screen("編成")
	var ts = main.content.get_child(0)
	CharDetail.open(ts, 1, {"team": true})
	await _shot("編成_詳細")
	_close_modals(main)
	Game.remove_from_team(2)
	ts.build()
	ts._picker("攻")
	await _shot("編成_選択")
	_close_modals(main)
	Game.place(2, "攻")
	# 試合
	Game.save.settings.speed = "normal"
	main.show_screen("試合")
	var ms = main.content.get_child(0)
	ms._kickoff()
	for k in 4:
		await get_tree().create_timer(2.2).timeout
		await _shot("試合_途中%d" % k)
	await get_tree().create_timer(5.0).timeout
	await _shot("試合_結果")
	Game.save.settings.speed = "instant"
	while not Game.season_over():
		Game.play_round("バランス")
	ms.show_league()
	await _shot("試合_全日程終了")
	ms._season_end()
	await _shot("試合_シーズン結果")
	# ガチャ
	Game.save.stones = 5000
	main.show_screen("ガチャ")
	main.content.get_child(0)._pull(10)
	await get_tree().create_timer(0.1).timeout
	await _shot("ガチャ_扉")
	await get_tree().create_timer(1.5).timeout
	await _shot("ガチャ_開封")
	var ov = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	ov._show_summary()
	await _shot("ガチャ_結果")
	ov.queue_free()
	# 図鑑：全キャラ入手後
	for id in Game.chars:
		Game.add_character(id)
	main.show_screen("図鑑")
	var dx = main.content.get_child(0)
	dx.page = "蹴球"
	dx.build()
	await _shot("図鑑_蹴球")
	CharDetail.open(dx, 19)
	await _shot("図鑑_詳細")
	_close_modals(main)
	Game.auto_formation()
	main.show_screen("編成")
	await _shot("編成_おまかせ")
	var ts3 = main.content.get_child(0)
	ts3.swap_mode = true
	ts3.sel = Game.row_ids("中")[0]
	ts3.build()
	await _shot("編成_入れ替え")
	var ts2 = main.content.get_child(0)
	ts2.view = "スキル"
	ts2.build()
	await _shot("編成_スキル")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	get_tree().quit()


func _close_modals(main: Node) -> void:
	for c in get_tree().root.get_children():
		if c != main and c != self and c is Control:
			c.queue_free()


func _shot(name: String) -> void:
	for m in get_tree().root.get_children():
		if "toast_box" in m:
			UI_clear(m.toast_box)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _stats() -> void:
	Game.save.stones = 1000000
	var cnt := {1: 0, 2: 0, 3: 0, 4: 0}
	for r in Game.pull(10000):
		cnt[r.rarity] += 1
	print("gacha 10000: ", cnt, " dex=", Game.dex_count(), "/", Game.dex_total())
	# 各部での勝率：初期メンバー / その部のコスト上限で全キャラからおまかせ
	for mode in ["starter", "best"]:
		for d in [5, 4, 3, 2, 1]:
			Game.load_game()
			if mode == "starter":
				DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
				Game.load_game()
			Game.new_season(d)
			if mode == "best":
				for id in Game.chars:
					Game.add_character(id)
				Game.auto_formation()
			var w := 0
			var dr := 0
			var goals := 0
			for i in 400:
				Game.new_season(d)
				var opp := Game.lineup(1 + i % 5)
				var res := Game.simulate(Game.formation_entries(), opp, "バランス", "バランス")
				if res.outcome == "win": w += 1
				elif res.outcome == "draw": dr += 1
				goals += res.goals[0] + res.goals[1]
			print("%s %d部 cost%d: win %.0f%% draw %.0f%% goals %.2f" % [mode, d, Game.formation_cost(), w / 4.0, dr / 4.0, goals / 400.0])


func UI_clear(n: Node) -> void:
	for c in n.get_children():
		c.free()
