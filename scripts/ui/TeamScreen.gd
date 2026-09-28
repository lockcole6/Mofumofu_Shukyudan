extends VBoxContainer
## 編成：列（攻・中・守・GK）ごとに選手を並べる。人数に合わせて自動で中央にそろう。
## GKは1人、ほかの列は最大4人、合計7人。下にベンチ（出場していない選手）。
## 操作：タップで詳細、＋で追加、ドラッグで移動（選手の上で入れ替え、ベンチに落とすと外れる）、
##       「入れ替え」ボタンをオンにすると、2人をタップするだけで入れ替えられる。

const UI = preload("res://scripts/ui/UI.gd")
const CharDetail = preload("res://scripts/ui/CharDetail.gd")
const DropRow = preload("res://scripts/ui/DropRow.gd")
const CARD_W := 62

var view := "ピッチ"   # ピッチ / スキル
var swap_mode := false
var sel := 0           # 入れ替えモードで選んでいる選手


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	build()


func build() -> void:
	UI.clear(self)
	var entries := Game.formation_entries()
	var pw := Game.team_power(entries)
	var cost := Game.formation_cost()
	var cap := Game.cost_cap()
	var full := entries.size() >= Game.TEAM_SIZE

	# 見出し：フォーメーション・コスト・戦力
	var head := UI.panel(UI.PANEL, 6)
	var hh := UI.hbox(14)
	for s in [["FORMATION", Game.formation_name(entries), UI.INK], ["COST", "%d/%d" % [cost, cap], UI.RED if cost > cap else UI.LIME],
			["攻撃", str(int(pw.atk)), UI.ROW_COLORS["攻"]], ["守備", str(int(pw.def)), UI.ROW_COLORS["守"]]]:
		var sv := UI.vbox(0)
		sv.add_child(UI.label(s[0], 9, UI.SUB, HORIZONTAL_ALIGNMENT_LEFT, true))
		sv.add_child(UI.label(s[1], 16, s[2], HORIZONTAL_ALIGNMENT_LEFT, true))
		hh.add_child(sv)
	head.add_child(hh)
	add_child(head)

	# ピッチ／スキルの切り替え、入れ替え、おまかせ
	var bar := UI.hbox(5)
	var seg := UI.segmented(["ピッチ", "スキル"], view, func(v):
		view = v
		sel = 0
		build(), 12)
	seg.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.add_child(seg)
	if view == "ピッチ":
		var sw := UI.button("入れ替え", "active" if swap_mode else "ghost", 12, 34)
		sw.pressed.connect(func():
			swap_mode = not swap_mode
			sel = 0
			build())
		bar.add_child(sw)
	var auto := UI.button("おまかせ", "ghost", 12, 34)
	auto.pressed.connect(func():
		Game.auto_formation()
		sel = 0
		build())
	bar.add_child(auto)
	add_child(bar)
	if view == "スキル":
		add_child(UI.scroll(_skill_list(entries)))
		return

	# 1行の案内（いま何ができるか）
	var info := UI.flow(4)
	if swap_mode:
		info.add_child(UI.label("選手を選んで、入れ替える相手（ベンチでもOK）か＋をタップ" if sel == 0
			else "%s を選択中 → 入れ替える相手か＋をタップ" % Game.chars[sel].name, 11, UI.CYAN, HORIZONTAL_ALIGNMENT_LEFT, true))
	elif cost > cap:
		info.add_child(UI.label("コスト上限をこえています。試合に出るには減らしてね", 11, UI.RED))
	elif not full:
		info.add_child(UI.label("あと%d人置けます（＋をタップ）" % (Game.TEAM_SIZE - entries.size()), 11, UI.CYAN))
	elif not pw.mods.combos.is_empty():
		info.add_child(UI.label("連携", 11, UI.PINK, HORIZONTAL_ALIGNMENT_LEFT, true))
		for n in pw.mods.combos:
			info.add_child(UI.tag(n, UI.PINK, 10, false))
	else:
		info.add_child(UI.label("タップで詳細 ／ ドラッグで移動・ベンチに落とすと外れる", 10, UI.DIM))
	add_child(info)

	# ピッチ
	var pitch := PanelContainer.new()
	pitch.add_theme_stylebox_override("panel", UI.sbox(Color("101a24"), 6, Color("1f3a3a"), 1, 4))
	pitch.size_flags_vertical = SIZE_EXPAND_FILL
	var rows := UI.vbox(4)
	for row in Game.GRID_ROWS:
		rows.add_child(_row(row, full))
	pitch.add_child(rows)
	add_child(pitch)
	add_child(_bench())


func _card(id: int, lines: Array, icon := 32) -> Control:
	var card = UI.card(id, false, lines, _tap.bind(id), icon)
	card.draggable = true
	card.selected = id == sel
	card.on_drop = func(from, to):
		_exchange(from, to)
		build()
	return card


func _row(row: String, full: bool) -> Control:
	var ids := Game.row_ids(row)
	var col: Color = UI.ROW_COLORS[row]
	var zone = DropRow.new()
	zone.row = row
	zone.on_drop = func(id, r):
		_toast(Game.place(id, r))
		build()
	zone.add_theme_stylebox_override("panel", UI.sbox(Color(col, 0.05), 4, Color(col, 0.18), 1, 3))
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
		var st := UI.label(UI.stars(c.rarity), 9, UI.STAR, HORIZONTAL_ALIGNMENT_CENTER)
		if c.pos != row:
			st.text += " 得意:" + c.pos
			st.add_theme_color_override("font_color", UI.RED)
		var card := _card(id, [c.name, st], 28)
		card.custom_minimum_size = Vector2(CARD_W, 58)
		cards.add_child(card)
	# 追加できるか（入れ替えモードで選択中なら、その選手を移せるか）
	var can_add: bool = ids.size() < Game.ROW_MAX[row] and (not full or row == "GK" or (sel != 0 and Game.in_team(sel)))
	if ids.is_empty():
		var empty = UI.card(0, false, [UI.label("追加", 9, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)], _add.bind(row), 28)
		empty.custom_minimum_size = Vector2(CARD_W, 58)
		empty.dim = not can_add
		cards.add_child(empty)
	center.add_child(cards)
	h.add_child(center)

	# 右端：追加ボタン（左のラベルと同じ幅にして中央をずらさない）
	var right := CenterContainer.new()
	right.custom_minimum_size.x = 26
	if can_add and not ids.is_empty():
		var plus := UI.button("+", "active" if sel else "ghost", 14, 30)
		plus.custom_minimum_size.x = 26
		for stn in ["normal", "hover", "pressed"]:
			var sb: StyleBoxFlat = plus.get_theme_stylebox(stn).duplicate()
			sb.content_margin_left = 2
			sb.content_margin_right = 2
			plus.add_theme_stylebox_override(stn, sb)
		plus.pressed.connect(_add.bind(row))
		right.add_child(plus)
	h.add_child(right)
	zone.add_child(h)
	return zone


## ベンチ：出場していない選手。横スクロール。ここに落とすと編成から外れる。
func _bench() -> Control:
	var zone = DropRow.new()
	zone.row = ""
	zone.on_drop = func(id, _r):
		Game.remove_from_team(id)
		build()
	zone.add_theme_stylebox_override("panel", UI.sbox(UI.PANEL, 4, UI.LINE, 1, 4))
	var v := UI.vbox(3)
	var ids: Array = Game.save.roster.keys().map(func(k): return int(k)).filter(func(id): return not Game.in_team(id))
	ids.sort_custom(func(a, b): return [Game.chars[a].rarity, -a] > [Game.chars[b].rarity, -b])
	var hh := UI.hbox(6)
	hh.add_child(UI.label("ベンチ %d人" % ids.size(), 10, UI.SUB, HORIZONTAL_ALIGNMENT_LEFT, true))
	hh.add_child(UI.label("ここに落とすと外れる", 9, UI.DIM))
	hh.add_child(UI.spacer())
	if swap_mode and sel and Game.in_team(sel):
		var out := UI.button("ベンチへ下げる", "active", 10, 22)
		out.pressed.connect(func():
			Game.remove_from_team(sel)
			sel = 0
			build())
		hh.add_child(out)
	v.add_child(hh)
	var sc = UI.DragScroll.new()
	sc.horizontal = true
	sc.custom_minimum_size.y = 50
	var row := UI.hbox(4)
	for id in ids:
		var card := _card(id, [Game.chars[id].name], 26)
		card.custom_minimum_size = Vector2(54, 50)
		row.add_child(card)
	if ids.is_empty():
		row.add_child(UI.label("全員出場中", 10, UI.DIM))
	sc.add_child(row)
	v.add_child(sc)
	zone.add_child(v)
	return zone


func _tap(id: int) -> void:
	if not swap_mode:
		var row := Game.row_of_id(id)
		CharDetail.open(self, id, {"team": true, "on_change": build, "on_swap": _picker.bind(row, id)})
		return
	if sel == 0 or sel == id or (not Game.in_team(sel) and not Game.in_team(id)):
		sel = 0 if sel == id else id
	else:
		_exchange(sel, id)
		sel = 0
	build()


## a と b を入れ替える（どちらかがベンチならその人が出場）
func _exchange(a: int, b: int) -> void:
	if Game.in_team(a) and Game.in_team(b):
		Game.swap(a, b)
	elif Game.in_team(b):
		_toast(Game.place(a, Game.row_of_id(b), b))
	elif Game.in_team(a):
		_toast(Game.place(b, Game.row_of_id(a), a))


func _add(row: String) -> void:
	if swap_mode and sel:
		_toast(Game.place(sel, row))
		sel = 0
		build()
	else:
		_picker(row)


func _toast(err: String) -> void:
	if err != "":
		Game.toast.emit(err)


## 出場メンバーの固有スキルと、連携スキルの一覧
func _skill_list(entries: Array) -> VBoxContainer:
	var v := UI.vbox(6)
	for row in Game.GRID_ROWS:
		for p in entries:
			if p.row != row:
				continue
			var c: Dictionary = Game.chars[p.id]
			var h := UI.hbox(8)
			var card = UI.card(p.id, false, [], Callable(), 34)
			card.custom_minimum_size = Vector2(50, 50)
			card.size_flags_vertical = SIZE_SHRINK_CENTER
			h.add_child(card)
			var sv := UI.vbox(1)
			sv.size_flags_horizontal = SIZE_EXPAND_FILL
			var nh := UI.hbox(6)
			nh.add_child(UI.label(c.name, 11, UI.SUB, HORIZONTAL_ALIGNMENT_LEFT, true))
			nh.add_child(UI.label(UI.stars(c.rarity), 9, UI.STAR))
			sv.add_child(nh)
			var sh := UI.hbox(6)
			sh.add_child(UI.label(c.skill.name, 14, UI.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
			sh.add_child(UI.tag("Lv%d" % p.slv, UI.CYAN, 9, false))
			sv.add_child(sh)
			sv.add_child(UI.wrap_label(Game.skill_text(p.id, p.slv), 11, UI.CYAN))
			h.add_child(sv)
			var pn := UI.panel(UI.PANEL, 6, UI.ROW_COLORS[row])
			pn.add_child(h)
			UI.on_tap(pn, _tap_detail.bind(p.id))
			v.add_child(pn)

	v.add_child(UI.label("連携スキル", 12, UI.PINK, HORIZONTAL_ALIGNMENT_LEFT, true))
	var ids := entries.map(func(p): return p.id)
	var shown := 0
	for cb in Game.combos:
		var missing: Array = cb.ids.filter(func(i): return not i in ids)
		# 発動中のものと、あと1人で発動するもの（その1人を持っている）を出す
		if missing.size() > 1 or (missing.size() == 1 and not Game.owned(missing[0])):
			continue
		shown += 1
		var on := missing.is_empty()
		var pn := UI.panel(UI.PANEL, 8, UI.PINK if on else UI.LINE)
		var cv := UI.vbox(3)
		var ch := UI.hbox(6)
		ch.add_child(UI.label(cb.name, 13, UI.INK if on else UI.SUB, HORIZONTAL_ALIGNMENT_LEFT, true))
		ch.add_child(UI.spacer())
		ch.add_child(UI.tag("発動中" if on else "あと%sで発動" % Game.chars[missing[0]].name, UI.PINK if on else UI.SUB, 9, on))
		cv.add_child(ch)
		var mh := UI.hbox(2)
		for mid in cb.ids:
			var ic := UI.icon(Game.chars[mid], false, 26)
			if mid in missing:
				ic.modulate.a = 0.35
			mh.add_child(ic)
		cv.add_child(mh)
		cv.add_child(UI.label(Game.combo_text(cb), 11, UI.PINK if on else UI.SUB))
		pn.add_child(cv)
		v.add_child(pn)
	if shown == 0:
		v.add_child(UI.label("発動中の連携はありません。組み合わせは各キャラの詳細で見られます", 10, UI.DIM))
	return v


func _tap_detail(id: int) -> void:
	CharDetail.open(self, id, {"team": true, "on_change": build, "on_swap": _picker.bind(Game.row_of_id(id), id)})


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
		var lines: Array = [c.name, UI.label(UI.stars(c.rarity), 9, UI.STAR, HORIZONTAL_ALIGNMENT_CENTER)]
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
