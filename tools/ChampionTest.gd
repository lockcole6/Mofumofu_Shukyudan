extends Node
## 開発用：1部で優勝 → エンディングが出て cleared になる。2回目は祝福だけ（終わるとセーブは消える）


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.load_game()
	Game.save.tutorial_done = true
	Game.place_starters()
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames()
	for n in 2:
		Game.new_season(1)
		while not Game.season_over():
			Game.play_round()
		Game.save.league.table[0].pts = 99   # 優勝にする
		var ms = main.content.get_child(0)
		ms.show_league()
		await _frames()
		ms._season_end()
		await _frames()
		var en: Node = null
		for c in get_tree().root.get_children():
			if "full" in c and "phase" in c:
				en = c
		print("title %d: ending shown=%s full=%s cleared=%s titles=%d division=%d" % [n + 1, en != null, en.full if en else false,
			Game.save.cleared, Game.save.record.titles, Game.division()])
		if en:
			Nav.close(en)
		await _frames()
		Nav.back()
		await _frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	get_tree().quit()


func _frames() -> void:
	for i in 5:
		await get_tree().process_frame
