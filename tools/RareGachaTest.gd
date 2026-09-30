extends Node
## 開発用：★3以上確定ガチャの排出と消費（終わるとセーブは消える）


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.load_game()
	Game.save.tutorial_done = true
	Game.place_starters()
	Game.save.stones = 1200 * 100
	var cnt := {1: 0, 2: 0, 3: 0, 4: 0}
	var before: int = Game.save.stones
	for i in 1000:
		var r: Array = Game.pull(1, true)
		if r.is_empty():
			break
		cnt[r[0].rarity] += 1
	print("rare x1000 (or until out of stones): ", cnt, " spent=", before - int(Game.save.stones))
	Game.save.stones = 110
	print("can pull rare with 110: ", Game.can_pull(1, true), "  normal 10: ", Game.can_pull(10))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	get_tree().quit()
