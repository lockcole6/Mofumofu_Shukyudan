extends VBoxContainer
## 編成：列（攻・中・守・GK）ごとに選手を並べる。人数に合わせて自動で中央にそろう。
## GKは1人、ほかの列は最大4人、合計7人。
## 操作：タップで詳細、＋で追加、
##       長押しでカードを持ち上げて運ぶ（別の列へ移動・選手の上で入れ替え・右端の「外す」で編成から外す）。

const UI = preload("res://scripts/ui/UI.gd")
const CharDetail = preload("res://scripts/ui/CharDetail.gd")
const CARD_W := 64
const REMOVE_W := 64

var view := "ピッチ"   # ピッチ / スキル
var _cards := {}       # 選手id -> ピッチ上のカード
var _rows := {}        # 列 -> 列のパネル
var _pitch: Control
var _drag := {}        # 持ち上げ中 {id, card, preview, zone}


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	build()


func build() -> void:
	_end_drag()
	UI.clear(self)
	_cards.clear()
	_rows.clear()
	var entries := Game.formation_entries()
	var pw := Game.team_power(entries)
	var cost := Game.formation_cost()
	var cap := Game.cost_cap()
	var full := entries.size() >= Game.TEAM_SIZE

	# 見出し：フォーメーション・コスト・戦力
	var head := UI.panel(UI.PANEL, 8)
	var hh := UI.hbox(14)
	for s in [["FORMATION", Game.formation_name(entries), UI.INK], ["COST", "%d/%d" % [cost, cap], UI.RED if cost > cap else UI.LIME],
			["攻撃", str(int(pw.atk)), UI.ROW_COLORS["攻"]], ["守備", str(int(pw.def)), UI.ROW_COLORS["守"]]]:
		var sv := UI.vbox(0)
		sv.add_child(UI.label(s[0], 9, UI.SUB, HORIZONTAL_ALIGNMENT_LEFT, true))
		sv.add_child(UI.label(s[1], 17, s[2], HORIZONTAL_ALIGNMENT_LEFT, true))
		hh.add_child(sv)
	head.add_child(hh)
	add_child(head)

	# ピッチ／スキルの切り替え
	add_child(UI.segmented(["ピッチ", "スキル"], view, func(v):
		view = v
		build(), 12))
	if view == "スキル":
		add_child(UI.scroll(_skill_list(entries)))
		return

	# 1行の案内（いま何ができるか）と、おまかせ
	var ih := UI.hbox(6)
	var info := UI.flow(4)
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	if cost > cap:
		info.add_child(UI.label("コスト上限をこえています。長押しで右へ運ぶと外せます", 10, UI.RED))
	elif not full:
		info.add_child(UI.label("あと%d人置けます（＋をタップ）" % (Game.TEAM_SIZE - entries.size()), 10, UI.CYAN))
	elif not pw.mods.combos.is_empty():
		info.add_child(UI.label("連携", 10, UI.PINK, HORIZONTAL_ALIGNMENT_LEFT, true))
		for n in pw.mods.combos:
			info.add_child(UI.tag(n, UI.PINK, 9, false))
	else:
		info.add_child(UI.label("タップで詳細 ／ 長押しで持ち上げて移動", 10, UI.DIM))
	ih.add_child(info)
	var auto := UI.button("おまかせ編成", "ghost", 11, 28)
	auto.size_flags_vertical = SIZE_SHRINK_CENTER
	auto.pressed.connect(_auto)
	ih.add_child(auto)
	add_child(ih)

	# ピッチ
	var pitch := PanelContainer.new()
	pitch.add_theme_stylebox_override("panel", UI.sbox(Color("101a24"), 6, Color("1f3a3a"), 1, 4))
	pitch.size_flags_vertical = SIZE_EXPAND_FILL
	var rows := UI.vbox(5)
	for row in Game.GRID_ROWS:
		rows.add_child(_row(row, full))
	pitch.add_child(rows)
	add_child(pitch)
	_pitch = pitch


func _auto() -> void:
	var before := Game.formation_entries().map(func(p): return [p.id, p.row])
	Game.auto_formation()
	var after := Game.formation_entries().map(func(p): return [p.id, p.row])
	build()
	Game.toast.emit("おまかせで並べました（%s ・ コスト%d/%d）" % [Game.formation_name(), Game.formation_cost(), Game.cost_cap()]
		if before != after else "いまの編成がおまかせと同じです")
	# 並べ直したカードを一瞬光らせる
	for id in _cards:
		var c: Control = _cards[id]
		c.modulate = Color(1.6, 1.6, 1.6)
		c.create_tween().tween_property(c, "modulate", Color.WHITE, 0.5)


func _row(row: String, full: bool) -> Control:
	var ids := Game.row_ids(row)
	var col: Color = UI.ROW_COLORS[row]
	var zone := PanelContainer.new()
	zone.add_theme_stylebox_override("panel", UI.sbox(Color(col, 0.05), 4, Color(col, 0.18), 1, 3))
	zone.size_flags_vertical = SIZE_EXPAND_FILL
	_rows[row] = zone
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
		var card = UI.card(id, false, [c.name, st], _detail.bind(id), 32, _start_drag.bind(id))
		card.custom_minimum_size = Vector2(CARD_W, 66)
		_cards[id] = card
		cards.add_child(card)
	var can_add: bool = ids.size() < Game.ROW_MAX[row] and (not full or row == "GK")
	if ids.is_empty():
		var empty = UI.card(0, false, [UI.label("追加", 9, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)], _picker.bind(row), 32)
		empty.custom_minimum_size = Vector2(CARD_W, 66)
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


# ---------------------------------------------------------------- 長押しで持ち上げて運ぶ

func _start_drag(id: int) -> void:
	if not _drag.is_empty() or not _cards.has(id):
		return
	var src: Control = _cards[id]
	src.modulate.a = 0.25
	# 指についてくるカード
	var c: Dictionary = Game.chars[id]
	var preview = UI.card(id, false, [c.name], Callable(), 36)
	preview.top_level = true
	preview.size = Vector2(CARD_W + 6, 70)
	preview.z_index = 10
	UI.ignore_mouse(preview)
	preview.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(preview)
	preview.global_position = src.get_global_rect().get_center() - preview.size / 2
	# 右端の「外す」
	var zone := PanelContainer.new()
	zone.top_level = true
	zone.z_index = 9
	zone.mouse_filter = MOUSE_FILTER_IGNORE
	zone.add_theme_stylebox_override("panel", UI.sbox(Color(UI.RED, 0.18), 4, Color(UI.RED, 0.6), 1, 4))
	var zl := UI.label("外\nす\n\n→", 14, UI.RED, HORIZONTAL_ALIGNMENT_CENTER, true)
	zl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zone.add_child(zl)
	add_child(zone)
	var pr := _pitch.get_global_rect()
	zone.global_position = Vector2(pr.end.x - REMOVE_W, pr.position.y)
	zone.size = Vector2(REMOVE_W, pr.size.y)
	_drag = {"id": id, "card": src, "preview": preview, "zone": zone}


func _input(e: InputEvent) -> void:
	if _drag.is_empty():
		return
	if e is InputEventMouseMotion:
		var pv: Control = _drag.preview
		pv.global_position = e.position - pv.size / 2
		var over: bool = _drag.zone.get_global_rect().has_point(e.position)
		_drag.zone.get_theme_stylebox("panel").bg_color = Color(UI.RED, 0.45 if over else 0.18)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		_drop(e.position)


func _drop(at: Vector2) -> void:
	var id: int = _drag.id
	var removed: bool = _drag.zone.get_global_rect().has_point(at)
	_end_drag()
	if removed:
		Game.remove_from_team(id)
		Game.toast.emit("%s を編成から外しました" % Game.chars[id].name)
	else:
		var done := false
		for other in _cards:
			if other != id and _cards[other].get_global_rect().has_point(at):
				Game.swap(id, other)
				done = true
				break
		if not done:
			for row in _rows:
				if _rows[row].get_global_rect().has_point(at) and row != Game.row_of_id(id):
					_toast(Game.place(id, row))
					break
	build.call_deferred()


func _end_drag() -> void:
	if _drag.is_empty():
		return
	if is_instance_valid(_drag.card):
		_drag.card.modulate.a = 1.0
	_drag.preview.queue_free()
	_drag.zone.queue_free()
	_drag = {}


func _detail(id: int) -> void:
	CharDetail.open(self, id, {"team": true, "on_change": build, "on_swap": _picker.bind(Game.row_of_id(id), id)})


func _toast(err: String) -> void:
	if err != "":
		Game.toast.emit(err)


# ---------------------------------------------------------------- スキル一覧

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
			UI.on_tap(pn, _detail.bind(p.id))
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


# ---------------------------------------------------------------- 選手をえらぶ

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
			build(), 40, func(): CharDetail.open(self, id, {"readonly": true}))
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		card.dim = not here and c.rarity > room
		g.add_child(card)
	v.add_child(g)
	v.add_child(UI.label("長押しで詳細", 10, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var cl := UI.button("とじる", "ghost", 13, 36)
	cl.pressed.connect(func(): UI.close(holder.m))
	v.add_child(cl)
	holder.m = UI.modal(self, v)
