extends VBoxContainer

const UI = preload("res://scripts/ui/UI.gd")
const LockerReveal = preload("res://scripts/ui/LockerReveal.gd")


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	Game.changed.connect(build)
	build()


func build() -> void:
	UI.clear(self)
	add_child(UI.title("ロッカーガチャ", "1回 ◆%d" % Game.GACHA_COST))

	# 排出率
	var info := UI.panel(UI.PANEL, 12)
	var iv := UI.vbox(6)
	var r: Array = Game.save.debug.rates
	var total := 0.0
	for x in r:
		total += float(x)
	for i in 4:
		var row := UI.hbox(8)
		var st := UI.label(UI.stars(i + 1), 13, UI.STAR)
		st.custom_minimum_size.x = 60
		row.add_child(st)
		var pct := 100.0 * float(r[i]) / maxf(total, 0.001)
		var b := UI.bar(pct, 100, UI.DOOR_COLORS[i + 1], 4)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(b)
		var pl := UI.label("%.1f%%" % pct, 12, UI.INK, HORIZONTAL_ALIGNMENT_RIGHT, true)
		pl.custom_minimum_size.x = 48
		row.add_child(pl)
		iv.add_child(row)
	info.add_child(iv)
	add_child(info)

	var pity := UI.panel(UI.PANEL, 12, UI.GOLD)
	var pv := UI.vbox(4)
	var ph := UI.hbox()
	ph.add_child(UI.label("★3以上確定まで", 12, UI.SUB))
	ph.add_child(UI.spacer())
	ph.add_child(UI.label("あと %d 回" % Game.pity_left(), 14, UI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, true))
	pv.add_child(ph)
	pv.add_child(UI.bar(int(Game.save.pity), int(Game.save.debug.pity), UI.GOLD, 4))
	pity.add_child(pv)
	add_child(pity)

	# 余りの売却
	var sur := Game.surplus_total()
	var sp := UI.panel(UI.PANEL, 12)
	var sh := UI.hbox(8)
	var sv := UI.vbox(0)
	sv.add_child(UI.label("被りの余りを売却", 12, UI.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
	sv.add_child(UI.label("スキル最大に必要な分は残す（余り%d体）" % sur.x, 10, UI.SUB))
	sv.size_flags_horizontal = SIZE_EXPAND_FILL
	sh.add_child(sv)
	var sell := UI.button("◆ +%d" % sur.y, "ghost", 13, 34)
	sell.disabled = sur.x == 0
	sell.set_meta("sfx", "coin")
	sell.pressed.connect(func():
		Game.toast.emit("余り%d体を売却して ◆%d を手に入れた" % [sur.x, Game.sell_all_surplus()]))
	sh.add_child(sell)
	sp.add_child(sh)
	add_child(sp)

	add_child(UI.spacer(true))
	add_child(UI.label("被りはスキル強化の素材になる", 10, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
	var btns := UI.hbox(10)
	for n in [1, 10]:
		var b := UI.button("%d回  ◆%d" % [n, Game.GACHA_COST * n], "pink" if n == 10 else "primary", 16, 56)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.disabled = not Game.can_pull(n)
		b.pressed.connect(_pull.bind(n))
		btns.add_child(b)
	add_child(btns)


func _pull(n: int) -> void:
	var res := Game.pull(n)
	if res.is_empty():
		return
	var ov := LockerReveal.new()
	ov.results = res
	get_tree().root.add_child(ov)
