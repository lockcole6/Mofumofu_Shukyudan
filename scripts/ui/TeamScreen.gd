extends VBoxContainer
## 編成：列（攻・中・守・GK）ごとに選手を並べる。人数に合わせて自動で中央にそろう。
## GKは1人、ほかの列は最大4人、合計7人。
## タップで詳細、＋で追加、ドラッグで列の移動（選手の上に落とすと入れ替え）。

const UI = preload("res://scripts/ui/UI.gd")
const CharDetail = preload("res://scripts/ui/CharDetail.gd")
const DropRow = preload("res://scripts/ui/DropRow.gd")
const CARD_W := 66


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	build()


func build() -> void:
	UI.clear(self)
	var entries := Game.formation_entries()
	var pw := Game.team_power(entries)
	var cost := Game.formation_cost()
	var cap := Game.cost_cap()
	var full := entries.size() >= Game.TEAM_SIZE

	# 見出し：フォーメーション・コスト・戦力
	var head := UI.panel(UI.PANEL, 10)
	var hh := UI.hbox(14)
	var fv := UI.vbox(0)
	fv.add_child(UI.label("FORMATION", 9, UI.SUB, HORIZONTAL_ALIGNMENT_LEFT, true))
	fv.add_child(UI.label(Game.formation_name(entries), 22, UI.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
	hh.add_child(fv)
	var cv := UI.vbox(0)
	cv.add_child(UI.label("COST", 9, UI.SUB, HORIZONTAL_ALIGNMENT_LEFT, true))
	var ch := UI.hbox(2)
	ch.add_child(UI.label(str(cost), 22, UI.RED if cost > cap else UI.LIME, HORIZONTAL_ALIGNMENT_LEFT, true))
	var capl := UI.label("/%d" % cap, 12, UI.SUB)
	capl.size_flags_vertical = SIZE_SHRINK_END
	ch.add_child(capl)
	cv.add_child(ch)
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
	var fl := UI.flow(4)
	if pw.mods.combos.is_empty():
		fl.add_child(UI.label("連携スキル：なし（特定の組み合わせで発動）", 11, UI.DIM))
	else:
		fl.add_child(UI.label("連携", 11, UI.PINK, HORIZONTAL_ALIGNMENT_LEFT, true))
		for n in pw.mods.combos:
			fl.add_child(UI.tag(n, UI.PINK, 10, false))
	add_child(fl)
	if cost > cap:
		add_child(UI.label("コスト上限をこえています。試合に出るには減らしてね", 11, UI.RED))
	elif not full:
		add_child(UI.label("あと%d人置けます（＋をタップ）" % (Game.TEAM_SIZE - entries.size()), 11, UI.CYAN))

	# ピッチ
	var pitch := PanelContainer.new()
	pitch.add_theme_stylebox_override("panel", UI.sbox(Color("101a24"), 6, Color("1f3a3a"), 1, 6))
	pitch.size_flags_vertical = SIZE_EXPAND_FILL
	var rows := UI.vbox(6)
	for row in Game.GRID_ROWS:
		rows.add_child(_row(row, full))
	pitch.add_child(rows)
	add_child(pitch)
	add_child(UI.label("タップで詳細 ／ ドラッグで列を移動・選手の上で入れ替え", 10, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))


func _row(row: String, full: bool) -> Control:
	var ids := Game.row_ids(row)
	var col: Color = UI.ROW_COLORS[row]
	var zone = DropRow.new()
	zone.row = row
	zone.on_drop = func(id, r):
		var err := Game.place(id, r)
		if err != "":
			Game.toast.emit(err)
		build()
	zone.add_theme_stylebox_override("panel", UI.sbox(Color(col, 0.05), 4, Color(col, 0.18), 1, 4))
	zone.size_flags_vertical = SIZE_EXPAND_FILL
	var h := UI.hbox(4)
	var lab := UI.label(row, 11, col, HORIZONTAL_ALIGNMENT_CENTER, true)
	lab.custom_minimum_size.x = 26
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.size_flags_vertical = SIZE_FILL
	h.add_child(lab)

	# 真ん中：人数に合わせて中央寄せ
	var center := CenterContainer.new()
	center.size_flags_horizontal = SIZE_EXPAND_FILL
	center.mouse_filter = MOUSE_FILTER_PASS
	var cards := UI.hbox(5)
	cards.mouse_filter = MOUSE_FILTER_PASS
	for id in ids:
		var c: Dictionary = Game.chars[id]
		var st := UI.label(UI.stars(c.rarity), 9, UI.RARITY_COLORS[c.rarity], HORIZONTAL_ALIGNMENT_CENTER)
		if c.pos != row:
			st.text += " 得意:" + c.pos
			st.add_theme_color_override("font_color", UI.RED)
		var card = UI.card(id, false, [c.name, st], _detail.bind(id, row), 38)
		card.custom_minimum_size = Vector2(CARD_W, 84)
		card.draggable = true
		card.on_drop = func(from, to):
			if Game.in_team(from):
				Game.swap(from, to)
			else:
				Game.place(from, row, to)
			build()
		cards.add_child(card)
	var can_add: bool = ids.size() < Game.ROW_MAX[row] and (not full or row == "GK")
	if ids.is_empty():
		var empty = UI.card(0, false, [UI.label("追加", 9, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)], _picker.bind(row), 38)
		empty.custom_minimum_size = Vector2(CARD_W, 84)
		empty.dim = not can_add
		cards.add_child(empty)
	center.add_child(cards)
	h.add_child(center)

	# 右端：追加ボタン（左のラベルと同じ幅にして中央をずらさない）
	var right := CenterContainer.new()
	right.custom_minimum_size.x = 26
	if can_add and not ids.is_empty():
		var plus := UI.button("+", "ghost", 14, 30)
		plus.custom_minimum_size.x = 26
		for stn in ["normal", "hover", "pressed"]:
			var sb: StyleBoxFlat = plus.get_theme_stylebox(stn).duplicate()
			sb.content_margin_left = 2
			sb.content_margin_right = 2
			plus.add_theme_stylebox_override(stn, sb)
		plus.pressed.connect(_picker.bind(row))
		right.add_child(plus)
	h.add_child(right)
	zone.add_child(h)
	return zone


func _detail(id: int, row: String) -> void:
	CharDetail.open(self, id, {"team": true, "on_change": build, "on_swap": _picker.bind(row, id)})


## 選手をえらぶ。replace を渡すとその選手と交代する。
func _picker(row: String, replace := 0) -> void:
	var v := UI.vbox(8)
	var room: int = Game.cost_cap() - Game.formation_cost() + (Game.chars[replace].rarity if replace else 0)
	v.add_child(UI.title("交代する選手" if replace else "選手をえらぶ", "%s の列 ／ 使えるコスト %d" % [row, room]))
	var ids: Array = Game.save.roster.keys().map(func(k): return int(k))
	ids.erase(replace)
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
			lines.append(UI.tag("出場中:" + Game.row_of_id(id), UI.SUB, 8))
		var card = UI.card(id, false, lines, func():
			var err := Game.place(id, row, replace)
			if err != "":
				Game.toast.emit(err)
				return
			UI.close(holder.m)
			build(), 40)
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		card.dim = not here and c.rarity > room
		g.add_child(card)
	v.add_child(g)
	var cl := UI.button("とじる", "ghost", 13, 36)
	cl.pressed.connect(func(): UI.close(holder.m))
	v.add_child(cl)
	holder.m = UI.modal(self, v)
