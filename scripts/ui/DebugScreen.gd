extends VBoxContainer
## デバッグ：排出率・色違い率・天井・ガチャ石・時間帯をその場で変える

const UI = preload("res://scripts/ui/UI.gd")
const TIME_MODES := [["auto", "自動（現実の時間）"], ["day", "昼"], ["night", "夜"], ["summer_night", "夏の夜"]]


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	build()


func build() -> void:
	UI.clear(self)
	var v := UI.vbox(8)
	var d: Dictionary = Game.save.debug

	v.add_child(_section("ガチャ排出の重み（合計は自由）"))
	var g := UI.grid(2, 6)
	for i in 4:
		g.add_child(UI.label(UI.stars(i + 1), 14, UI.RARITY_COLORS[i + 1]))
		g.add_child(_spin(float(d.rates[i]), 0, 1000, 0.5, func(x):
			d.rates[i] = x
			Game.save_game()))
	g.add_child(UI.label("色違い率 %", 13))
	g.add_child(_spin(float(d.shiny), 0, 100, 0.1, func(x):
		d.shiny = x
		Game.save_game()))
	g.add_child(UI.label("天井（回）", 13))
	g.add_child(_spin(float(d.pity), 1, 500, 1, func(x):
		d.pity = int(x)
		Game.save_game()))
	v.add_child(g)

	v.add_child(_section("ガチャ石"))
	var sh := UI.hbox(6)
	var stones := _spin(float(Game.save.stones), 0, 999999, 1, func(x):
		Game.save.stones = int(x)
		Game.save_game())
	stones.size_flags_horizontal = SIZE_EXPAND_FILL
	sh.add_child(stones)
	var add := UI.button("+1000", UI.BLUE, 13, 32)
	add.pressed.connect(func():
		Game.save.stones = int(Game.save.stones) + 1000
		Game.save_game()
		build())
	sh.add_child(add)
	v.add_child(sh)

	v.add_child(_section("時間帯（夜・夏限定キャラの確認用）"))
	var ob := OptionButton.new()
	for i in TIME_MODES.size():
		ob.add_item(TIME_MODES[i][1], i)
		if TIME_MODES[i][0] == d.time:
			ob.select(i)
	ob.item_selected.connect(func(i):
		d.time = TIME_MODES[i][0]
		Game.opponents.clear()
		Game.save_game()
		build())
	v.add_child(ob)
	v.add_child(UI.label("いまの判定：%s" % Game.time_text(), 12, UI.SUB))

	v.add_child(_section("その他"))
	var all := UI.button("全キャラ（通常）を入手", UI.GREEN, 13, 34)
	all.pressed.connect(func():
		for id in Game.chars:
			if not Game.owned(id, false):
				Game.add_character(id, false)
		Game.save_game())
	v.add_child(all)
	var reset := UI.button("セーブを消して最初から", Color("d05050"), 13, 34)
	reset.pressed.connect(func():
		if reset.text.begins_with("本当に"):
			Game.reset_game()
			build()
		else:
			reset.text = "本当に消す？（もう一度押す）")
	v.add_child(reset)
	v.add_child(UI.label("ガチャ %d 回 / 図鑑 %d/%d" % [Game.save.pulls, Game.dex_count(), Game.dex_total()], 12, UI.SUB))
	add_child(UI.scroll(v))


func _section(text: String) -> Label:
	return UI.label("■ " + text, 14, UI.ORANGE)


func _spin(value: float, lo: float, hi: float, step: float, on_change: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = SIZE_EXPAND_FILL
	s.value_changed.connect(on_change)
	return s
