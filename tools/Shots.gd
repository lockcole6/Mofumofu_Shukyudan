extends Node
## 開発用：ロジックの統計と各画面のスクリーンショットを出す。
## 実行: Godot --path . res://tools/Shots.tscn  （セーブはリセットされる）

const OUT := "res://tools/shots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.load_game()
	_stats()
	Game.reset_game()
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	for tab in ["試合", "ガチャ", "図鑑", "編成", "デバッグ"]:
		main.show_screen(tab)
		await _shot(tab)
	# 試合プレビュー
	main.show_screen("試合")
	var ms = main.content.get_child(0)
	ms._preview(1)
	await _shot("試合_プレビュー")
	ms._kickoff()
	await get_tree().create_timer(7.0).timeout
	await _shot("試合_結果")
	# ガチャ演出
	Game.save.stones = 5000
	Game.save.debug.shiny = 50.0
	main.show_screen("ガチャ")
	main.content.get_child(0)._pull(10)
	await get_tree().create_timer(0.2).timeout
	await _shot("ガチャ_扉")
	await get_tree().create_timer(1.6).timeout
	await _shot("ガチャ_開封")
	var ov = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	ov._show_summary()
	await _shot("ガチャ_結果")
	ov.queue_free()
	for id in Game.chars:
		Game.add_character(id, false)
	main.show_screen("図鑑")
	var dx = main.content.get_child(0)
	dx.page = "伝説"
	dx.build()
	await _shot("図鑑_伝説")
	dx._detail(19, false)
	await _shot("図鑑_詳細")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	get_tree().quit()


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _stats() -> void:
	# ガチャ排出の実測
	Game.save.stones = 1000000
	var cnt := {1: 0, 2: 0, 3: 0, 4: 0}
	var shiny := 0
	for r in Game.pull(10000):
		cnt[r.rarity] += 1
		if r.shiny:
			shiny += 1
	print("gacha 10000: ", cnt, " shiny=", shiny, " dex=", Game.dex_count(), "/", Game.dex_total())
	# 初期編成での各リーグ勝率
	Game.reset_game()
	for tac in Game.TACTICS:
		for li in Game.LEAGUES.size():
			var w := 0
			var d := 0
			var goals := 0
			for i in 500:
				var opp := Game._make_opponent(li)
				var res := Game.simulate(Game.formation_entries(), opp.members, tac)
				if res.outcome == "win": w += 1
				elif res.outcome == "draw": d += 1
				goals += res.goals[0] + res.goals[1]
			print("%s league%d: win %.0f%% draw %.0f%% goals/match %.2f" % [tac, li, w / 5.0, d / 5.0, goals / 500.0])
