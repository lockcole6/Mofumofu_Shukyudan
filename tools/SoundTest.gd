extends Node
## 開発用：音のファイルがすべて読めるか、BGM がループ設定になっているかを調べる


func _ready() -> void:
	var names := []
	for f in DirAccess.get_files_at("res://assets/audio"):
		if f.ends_with(".wav"):
			names.append(f.get_basename())
	var ok := 0
	for n in names:
		var s: AudioStream = load("res://assets/audio/%s.wav" % n)
		if s == null:
			print("  !! cannot load ", n)
			continue
		ok += 1
		if n.begins_with("bgm_"):
			var w := s as AudioStreamWAV
			print("  %s: %.1fs loop_mode=%d loop_end=%d" % [n, s.get_length(), w.loop_mode, w.loop_end])
	# コードから鳴らしている名前がすべてあるか
	var used := ["tap", "open", "close", "toast", "error", "lift", "drop", "remove", "coin", "levelup", "whistle",
		"whistle_end", "skill", "save", "goal", "opp_goal", "win", "draw", "lose", "promote", "champion", "door_shake",
		"door_open", "reveal1", "reveal2", "reveal3", "reveal4", "new", "scout_ok", "scout_ng"]
	for u in used:
		if not ("sfx_" + u) in names:
			print("  !! missing sfx_", u)
	Sound.bgm("menu")
	Sound.play("goal")
	print("loaded %d/%d audio files" % [ok, names.size()])
	get_tree().quit()
