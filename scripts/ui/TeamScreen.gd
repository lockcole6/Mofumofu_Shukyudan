extends VBoxContainer
## 編成：4x4のピッチに7体を置く。上から 攻・中・守・GK の列。
## タップで詳細、ドラッグで移動、空きマスのタップで選手を選ぶ。

const UI = preload("res://scripts/ui/UI.gd")
const CharDetail = preload("res://scripts/ui/CharDetail.gd")


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	build()


func build() -> void:
	UI.clear(self)
	var entries := Game.formation_entries()
	var pw := Game.team_power(entries)
	var cost := Game.formation_cost()
	var cap := Game.cost_cap()

	# 見出し：コスト・戦力
	var head := UI.panel(UI.PANEL, 10)
	var hh := UI.hbox(14)
	var cv := UI.vbox(2)
	cv.add_child(UI.label("COST", 9, UI.SUB, HORIZONTAL_ALIGNMENT_LEFT, true))
	var ch := UI.hbox(2)
	ch.add_child(UI.label(str(cost), 22, UI.RED if cost > cap else UI.LIME, HORIZONTAL_ALIGNMENT_LEFT, true))
	var capl := UI.label("/%d" % cap, 12, UI.SUB)
	capl.size_flags_vertical = SIZE_SHRINK_END
	ch.add_child(capl)
	cv.add_child(ch)
	var cb := UI.bar(cost, cap, UI.RED if cost > cap else UI.LIME, 4)
	cb.custom_minimum_size.x = 60
	cv.add_child(cb)
	hh.add_child(cv)
	for s in [["攻撃", pw.atk, UI.ROW_COLORS["攻"]], ["守備", pw.def, UI.ROW_COLORS["守"]]]:
		var sv := UI.vbox(0)
		sv.add_child(UI.label(s[0], 9, UI.SUB, HORIZONTAL_ALIGNMENT_LEFT, true))
		sv.add_child(UI.label(str(int(s[1])), 22, s[2], HORIZONTAL_ALIGNMENT_LEFT, true))
		hh.add_child(sv)
	hh.add_child(UI.spacer())
	var auto := UI.button("おまかせ", "ghost", 12, 32)
	auto.size_flags_vertical = SIZE_SHRINK_CENTER
	auto.pressed.connect(func():
		Game.auto_formation()
		build())
	hh.add_child(auto)
	head.add_child(hh)
	add_child(head)

	# 発動中の連携スキル
	var combos: Array = pw.mods.combos
	var fl := UI.flow(4)
	if combos.is_empty():
		fl.add_child(UI.label("連携スキル：なし（特定の組み合わせで発動）", 11, UI.DIM))
	else:
		fl.add_child(UI.label("連携", 11, UI.PINK, HORIZONTAL_ALIGNMENT_LEFT, true))
		for n in combos:
			fl.add_child(UI.tag(n, UI.PINK, 10, false))
	add_child(fl)
	if cost > cap:
		add_child(UI.label("コスト上限をこえています。試合に出るには減らしてね", 11, UI.RED))
	elif entries.size() < Game.TEAM_SIZE:
		add_child(UI.label("あと%d体置けます（空きマスをタップ）" % (Game.TEAM_SIZE - entries.size()), 11, UI.CYAN))

	# 4x4 のピッチ
	var pitch := PanelContainer.new()
	var psb := UI.sbox(Color("101a24"), 6, Color("1f3a3a"), 1, 6)
	pitch.add_theme_stylebox_override("panel", psb)
	pitch.size_flags_vertical = SIZE_EXPAND_FILL
	var rows := UI.vbox(6)
	for r in 4:
		var row: String = Game.GRID_ROWS[r]
		var rh := UI.hbox(5)
		rh.size_flags_vertical = SIZE_EXPAND_FILL
		var lab := UI.label(row, 11, UI.ROW_COLORS[row], HORIZONTAL_ALIGNMENT_CENTER, true)
		lab.custom_minimum_size.x = 22
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.size_flags_vertical = SIZE_FILL
		rh.add_child(lab)
		for col in 4:
			var cell := r * 4 + col
			var id := Game.formation_at(cell)
			var lines := []
			if id:
				var c: Dictionary = Game.chars[id]
				lines = [c.name, UI.label(UI.stars(c.rarity), 9, UI.RARITY_COLORS[c.rarity], HORIZONTAL_ALIGNMENT_CENTER)]
				if c.pos != row:
					lines[1].text += " 得意:" + c.pos
					lines[1].add_theme_color_override("font_color", UI.RED)
			var card = UI.card(id, false, lines, _tap.bind(cell), 38)
			card.size_flags_horizontal = SIZE_EXPAND_FILL
			card.size_flags_vertical = SIZE_EXPAND_FILL
			card.drag_cell = cell
			card.on_drop = func(from, to):
				Game.move_cell(from, to)
				build()
			rh.add_child(card)
		rows.add_child(rh)
	pitch.add_child(rows)
	add_child(pitch)
	add_child(UI.label("タップで詳細 ／ ドラッグで移動", 10, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))


func _tap(cell: int) -> void:
	var id := Game.formation_at(cell)
	if id:
		CharDetail.open(self, id, {"team": true, "on_change": build})
	else:
		_picker(cell)


func _picker(cell: int) -> void:
	var v := UI.vbox(8)
	var row := Game.row_of(cell)
	var room := Game.cost_cap() - Game.formation_cost()
	v.add_child(UI.title("選手をえらぶ", "%s の列 ／ 残りコスト %d" % [row, room]))
	var ids: Array = Game.save.roster.keys().map(func(k): return int(k))
	ids.sort_custom(func(a, b):
		var ka := [not Game.in_team(a), Game.chars[a].pos == row, Game.chars[a].rarity, -a]
		var kb := [not Game.in_team(b), Game.chars[b].pos == row, Game.chars[b].rarity, -b]
		return ka > kb)
	var g := UI.grid(4, 5)
	var holder := {"m": null}
	for id in ids:
		var c: Dictionary = Game.chars[id]
		var lines: Array = [c.name, UI.label("%s ★%d" % [c.pos, c.rarity], 9, UI.ROW_COLORS[c.pos], HORIZONTAL_ALIGNMENT_CENTER)]
		var here := Game.in_team(id)
		if here:
			lines.append(UI.tag("出場中", UI.SUB, 8))
		var card = UI.card(id, false, lines, func():
			var err := Game.place(id, cell)
			if err != "":
				Game.toast.emit(err)
				return
			holder.m.queue_free()
			build(), 40)
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		card.dim = not here and c.rarity > room
		g.add_child(card)
	v.add_child(g)
	var cl := UI.button("とじる", "ghost", 13, 36)
	cl.pressed.connect(func(): holder.m.queue_free())
	v.add_child(cl)
	holder.m = UI.modal(self, v)
