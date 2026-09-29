extends VBoxContainer
## 設定：試合の表示速度、データ、デバッグ（排出率・ガチャ石・ディビジョンなど）

const UI = preload("res://scripts/ui/UI.gd")
const SPEEDS := [["normal", "ふつう"], ["fast", "はやい"], ["instant", "結果だけ"]]

var debug_open := false


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	build()


func build() -> void:
	UI.clear(self)
	var v := UI.vbox(12)
	v.add_child(UI.title("設定"))

	var sp := UI.panel()
	var sv := UI.vbox(8)
	sv.add_child(UI.label("試合の表示速度", 12, UI.SUB, HORIZONTAL_ALIGNMENT_LEFT, true))
	var names := SPEEDS.map(func(s): return s[1])
	var cur := ""
	for s in SPEEDS:
		if s[0] == Game.save.settings.speed:
			cur = s[1]
	sv.add_child(UI.segmented(names, cur, func(n):
		for s in SPEEDS:
			if s[1] == n:
				Game.save.settings.speed = s[0]
		Game.save_game()
		build()))
	sp.add_child(sv)
	v.add_child(sp)

	var rec: Dictionary = Game.save.record
	var rp := UI.panel()
	var rv := UI.vbox(4)
	rv.add_child(UI.label("記録", 12, UI.SUB, HORIZONTAL_ALIGNMENT_LEFT, true))
	rv.add_child(UI.label("通算 %d勝 %d分 %d敗" % [rec.wins, rec.draws, rec.losses], 13))
	rv.add_child(UI.label("最高 %d部 ／ 1部優勝 %d回 ／ ガチャ %d回" % [rec.best, rec.titles, Game.save.pulls], 13))
	rp.add_child(rv)
	v.add_child(rp)

	var reset := UI.button("セーブデータを消して最初から", "danger", 13, 38)
	reset.pressed.connect(func():
		if reset.text.begins_with("本当に"):
			Game.reset_game()
			build()
		else:
			reset.text = "本当に消す？（もう一度押す）")
	v.add_child(reset)

	var db := UI.button("デバッグ ▲" if debug_open else "デバッグ ▼", "ghost", 13, 36)
	db.pressed.connect(func():
		debug_open = not debug_open
		build())
	v.add_child(db)
	if debug_open:
		v.add_child(_debug())
	add_child(UI.scroll(v))


func _debug() -> Control:
	var p := UI.panel(UI.PANEL, 12, UI.GOLD)
	var v := UI.vbox(8)
	var d: Dictionary = Game.save.debug

	v.add_child(UI.label("ガチャ排出の重み（合計は自由）", 11, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, true))
	var g := UI.grid(2, 6)
	for i in 4:
		g.add_child(UI.label(UI.stars(i + 1), 13, UI.RARITY_COLORS[i + 1]))
		g.add_child(_spin(float(d.rates[i]), 0, 1000, 0.5, func(x):
			d.rates[i] = x
			Game.save_game()))
	g.add_child(UI.label("天井（回）", 12))
	g.add_child(_spin(float(d.pity), 1, 500, 1, func(x):
		d.pity = int(x)
		Game.save_game()))
	g.add_child(UI.label("ガチャ石", 12))
	g.add_child(_spin(float(Game.save.stones), 0, 999999, 1, func(x):
		Game.save.stones = int(x)
		Game.save_game()))
	v.add_child(g)

	v.add_child(UI.label("ディビジョン（新しいシーズンを始める）", 11, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, true))
	v.add_child(UI.segmented(["1部", "2部", "3部", "4部", "5部"], "%d部" % Game.division(), func(n):
		Game.new_season(int(n.substr(0, 1)))
		Game.save_game()
		build(), 12))

	var acts := [
		["ガチャ石 +1000", func():
			Game.save.stones = int(Game.save.stones) + 1000
			Game.save_game()],
		["全キャラを入手", func():
			for id in Game.chars:
				Game.add_character(id)
			Game.save_game()],
		["全キャラの被り +5", func():
			for id in Game.chars:
				if Game.owned(id):
					Game.save.roster[str(id)].copies = Game.copies(id) + 5
			Game.save_game()],
		["今シーズンの残りを自動で消化", func():
			while not Game.season_over():
				Game.play_round(Game.save.tactic)],
	]
	for a in acts:
		var b := UI.button(a[0], "ghost", 12, 34)
		b.pressed.connect(func():
			a[1].call()
			build())
		v.add_child(b)
	p.add_child(v)
	return p


func _spin(value: float, lo: float, hi: float, step: float, on_change: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = SIZE_EXPAND_FILL
	s.value_changed.connect(on_change)
	return s
