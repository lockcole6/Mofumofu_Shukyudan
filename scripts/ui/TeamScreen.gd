extends VBoxContainer
## 編成：7枠を4列（GK・守・中・攻）に並べる。列ごとの人数は自由。

const UI = preload("res://scripts/ui/UI.gd")


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	build()


func build() -> void:
	UI.clear(self)
	var entries := Game.formation_entries()

	# ピッチ（上が攻、下がGK）
	var pitch := PanelContainer.new()
	pitch.add_theme_stylebox_override("panel", UI.sbox(Color("6cbf5f"), 12, Color("4e9a45"), 3, 6))
	var pv := UI.vbox(2)
	for row in ["攻", "中", "守", "GK"]:
		var rh := UI.hbox(4)
		rh.custom_minimum_size.y = 40
		var tg := UI.tag(row, UI.ROW_COLORS[row], 11)
		tg.custom_minimum_size.x = 30
		tg.size_flags_vertical = SIZE_SHRINK_CENTER
		rh.add_child(tg)
		var icons := UI.hbox(2)
		icons.alignment = BoxContainer.ALIGNMENT_CENTER
		icons.size_flags_horizontal = SIZE_EXPAND_FILL
		for p in entries:
			if p.row == row:
				icons.add_child(UI.icon(Game.chars[p.id], p.shiny, false, 38))
		rh.add_child(icons)
		pv.add_child(rh)
	pitch.add_child(pv)
	add_child(pitch)

	var pw := Game.team_power(entries)
	var ph := UI.hbox()
	ph.add_child(UI.label("攻撃力 %d" % pw.atk, 15, UI.ROW_COLORS["攻"]))
	ph.add_child(UI.label("守備力 %d" % pw.def, 15, UI.ROW_COLORS["守"]))
	ph.add_child(UI.spacer())
	var auto := UI.button("おまかせ", UI.BLUE, 13, 30)
	auto.pressed.connect(func():
		Game.auto_formation()
		build())
	ph.add_child(auto)
	add_child(ph)
	add_child(UI.label("攻撃力＝中・攻の列、守備力＝守・GKの列。得意な列だと力を出しきれる", 10, UI.SUB))

	# 枠の一覧
	var list := UI.vbox(4)
	while Game.save.formation.size() < 7:
		Game.save.formation.append({"k": "", "row": "中"})
	for i in 7:
		var s: Dictionary = Game.save.formation[i]
		var h := UI.hbox(6)
		var info := UI.hbox(6)
		info.size_flags_horizontal = SIZE_EXPAND_FILL
		if s.k != "" and Game.save.roster.has(s.k):
			var p := Game.parse_key(s.k)
			var c: Dictionary = Game.chars[p.id]
			info.add_child(UI.icon(c, p.shiny, false, 36))
			var nv := UI.vbox(0)
			nv.add_child(UI.label("%s%s" % [c.name, " ☆" if p.shiny else ""], 13))
			var fit_txt := "" if c.pos == s.row else "  (得意:%s)" % c.pos
			nv.add_child(UI.label("%s Lv%d%s" % [UI.stars(c.rarity), Game.lv_of(s.k), fit_txt], 10,
				UI.SUB if c.pos == s.row else Color("d05050")))
			info.add_child(nv)
		else:
			var e := UI.label("（空き枠：タップして選ぶ）", 12, UI.SUB)
			e.custom_minimum_size.y = 36
			e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			info.add_child(e)
		var t := UI.tile(info, UI.CARD, _pick.bind(i))
		t.size_flags_horizontal = SIZE_EXPAND_FILL
		h.add_child(t)
		var rb := UI.button(s.row, UI.ROW_COLORS[s.row], 14, 40)
		rb.custom_minimum_size.x = 48
		rb.pressed.connect(func():
			s.row = Game.ROWS[(Game.ROWS.find(s.row) + 1) % 4]
			Game.save_game()
			build())
		h.add_child(rb)
		list.add_child(h)
	add_child(UI.scroll(list))
	add_child(UI.label("列ボタンで GK→守→中→攻 を切り替え", 10, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))


func _pick(slot: int) -> void:
	UI.clear(self)
	var top := UI.hbox()
	var back := UI.button("← もどる", UI.GRAY, 13, 30)
	back.pressed.connect(build)
	top.add_child(back)
	top.add_child(UI.label("枠%d に入れる選手" % (slot + 1), 14))
	add_child(top)
	var cur: String = Game.save.formation[slot].k
	if cur != "":
		var rm := UI.button("この枠を空ける", Color("d06060"), 12, 28)
		rm.pressed.connect(func():
			Game.set_slot(slot, "")
			build())
		add_child(rm)

	var in_team := {}
	for s in Game.save.formation:
		in_team[s.k] = true
	var keys: Array = Game.save.roster.keys()
	keys.sort_custom(func(a, b):
		var pa := Game.parse_key(a)
		var pb := Game.parse_key(b)
		var ra: int = Game.chars[pa.id].rarity
		var rb: int = Game.chars[pb.id].rarity
		if ra != rb:
			return ra > rb
		return pa.id * 2 + int(pa.shiny) < pb.id * 2 + int(pb.shiny))
	var g := UI.grid(4, 6)
	for k in keys:
		var p := Game.parse_key(k)
		var c: Dictionary = Game.chars[p.id]
		var lines := [c.name, UI.label("%s Lv%d" % [c.pos, Game.lv_of(k)], 9, UI.ROW_COLORS[c.pos], HORIZONTAL_ALIGNMENT_CENTER)]
		if in_team.has(k):
			lines.append(UI.tag("出場中" if k != cur else "この枠", UI.SUB, 9))
		var t := UI.char_tile(c, p.shiny, false, lines, func():
			Game.set_slot(slot, k)
			build(), 44)
		t.size_flags_horizontal = SIZE_EXPAND_FILL
		g.add_child(t)
	add_child(UI.scroll(g))
