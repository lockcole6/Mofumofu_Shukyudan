extends VBoxContainer

const UI = preload("res://scripts/ui/UI.gd")
const LockerReveal = preload("res://scripts/ui/LockerReveal.gd")


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	Game.changed.connect(build)
	build()


func build() -> void:
	UI.clear(self)
	# バナー
	var banner := UI.panel(Color("ffe3ef"), 12)
	var bv := UI.vbox(6)
	bv.add_child(UI.label("もふもふロッカーガチャ", 20, Color("c0407a"), HORIZONTAL_ALIGNMENT_CENTER))
	bv.add_child(UI.label("★4 特別枠「ボールの精」「ゴールポストの守り神」登場中！", 11, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var feat := UI.hbox(10)
	feat.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in [19, 16, 17, 18, 20]:
		feat.add_child(UI.icon(Game.chars[id], false, false, 52))
	bv.add_child(feat)
	banner.add_child(bv)
	add_child(banner)

	# 確率・天井
	var info := UI.panel()
	var iv := UI.vbox(4)
	var r: Array = Game.save.debug.rates
	var total := 0.0
	for x in r:
		total += float(x)
	var parts := []
	for i in 4:
		parts.append("%s %.1f%%" % [UI.stars(i + 1), 100.0 * float(r[i]) / maxf(total, 0.001)])
	iv.add_child(UI.label("  ".join(PackedStringArray(parts)), 12, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
	iv.add_child(UI.label("色違い %.1f%%（全キャラ共通）" % float(Game.save.debug.shiny), 12, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
	iv.add_child(UI.label("★3以上確定まで あと %d 回" % Game.pity_left(), 15, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	iv.add_child(UI.label("被りは強化（最大Lv%d）→ その後はユニフォームのかけらに" % Game.MAX_LV, 11, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
	info.add_child(iv)
	add_child(info)

	var sp := Control.new()
	sp.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(sp)

	var btns := UI.hbox(10)
	for n in [1, 10]:
		var b := UI.button("%d回ひく\n◆%d" % [n, Game.GACHA_COST * n], Color("e35d8f") if n == 10 else UI.ORANGE, 16, 64)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.disabled = not Game.can_pull(n)
		b.pressed.connect(_pull.bind(n))
		btns.add_child(b)
	add_child(btns)
	add_child(UI.label("ガチャ石は試合の勝利や図鑑ページのコンプで手に入る", 11, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))


func _pull(n: int) -> void:
	var res := Game.pull(n)
	if res.is_empty():
		return
	var ov := LockerReveal.new()
	ov.results = res
	get_tree().root.add_child(ov)
