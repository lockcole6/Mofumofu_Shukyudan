extends VBoxContainer
## ガチャ：通常ガチャ（1回・10回）と ★3以上確定ガチャ。被りの余りの売却。

const UI = preload("res://scripts/ui/UI.gd")
const LockerReveal = preload("res://scripts/ui/LockerReveal.gd")


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	Game.changed.connect(build)
	build()


func build() -> void:
	UI.clear(self)
	add_child(UI.title("ロッカーガチャ"))

	# 排出率
	var info := UI.panel(UI.PANEL, 10)
	var iv := UI.vbox(5)
	iv.add_child(UI.label("通常ガチャの排出率", 11, UI.SUB, HORIZONTAL_ALIGNMENT_LEFT, true))
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

	# 余りの売却
	var sur := Game.surplus_total()
	var sp := UI.panel(UI.PANEL, 10)
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

	# 通常ガチャ
	var np := UI.panel(UI.PANEL, 10, UI.CYAN)
	var nv := UI.vbox(8)
	var nh := UI.hbox(6)
	nh.add_child(UI.label("通常ガチャ", 15, UI.CYAN, HORIZONTAL_ALIGNMENT_LEFT, true))
	nh.add_child(UI.spacer())
	nh.add_child(UI.label("★1〜★4", 11, UI.SUB))
	nv.add_child(nh)
	var btns := UI.hbox(10)
	for n in [1, 10]:
		var b := UI.button("%d回  ◆%d" % [n, Game.gacha_cost(n)], "primary", 16, 48)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.disabled = not Game.can_pull(n)
		b.pressed.connect(_pull.bind(n, false))
		btns.add_child(b)
	nv.add_child(btns)
	np.add_child(nv)
	add_child(np)

	# ★3以上確定ガチャ
	var r3 := 100.0 * float(r[2]) / maxf(float(r[2]) + float(r[3]), 0.001)
	var gp := UI.panel(UI.PANEL, 10, UI.GOLD)
	var gv := UI.vbox(8)
	var gh := UI.hbox(6)
	gh.add_child(UI.label("★3以上確定ガチャ", 15, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT, true))
	gh.add_child(UI.spacer())
	gh.add_child(UI.label("★3 %d%% ／ ★4 %d%%" % [roundi(r3), 100 - roundi(r3)], 11, UI.SUB))
	gv.add_child(gh)
	var gb := UI.button("1回  ◆%d" % Game.gacha_cost(1, true), "gold", 16, 48)
	gb.disabled = not Game.can_pull(1, true)
	gb.pressed.connect(_pull.bind(1, true))
	gv.add_child(gb)
	gp.add_child(gv)
	add_child(gp)


func _pull(n: int, rare: bool) -> void:
	var res := Game.pull(n, rare)
	if res.is_empty():
		return
	var ov := LockerReveal.new()
	ov.results = res
	get_tree().root.add_child(ov)
