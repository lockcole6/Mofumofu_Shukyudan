extends VBoxContainer
## チーム編成：芝のピッチに7体を並べる（上から FW・MF・DF・GK、人数に合わせて左右対称）。
## 下に選んだ選手のスキルと操作ボタン、その下に控え。
## 操作：タップで選択（スキルを確認）、長押しか押したまま動かすと持ち上げて運べる。詳細は「詳細」ボタンから
##       （選手の上で入れ替え・別の列へ移動・控えに落とすと外れる）。

const UI = preload("res://scripts/ui/UI.gd")
const CharDetail = preload("res://scripts/ui/CharDetail.gd")
const Icon = preload("res://scripts/ui/Icon.gd")
const Pitch = preload("res://scripts/ui/Pitch.gd")
const PitchPlayer = preload("res://scripts/ui/PitchPlayer.gd")

const LIFT_TIME := 0.25   # この時間押し続けるとカードが持ち上がる（詳細は「詳細」ボタンから）

var sel := 0            # 選んでいる選手
var back_to := ""       # 別のタブから来たとき、そのタブ名（見出しに戻るボタンを出す）
var _bench_x := 0       # 控えの横スクロール位置（作り直しても戻らないように）
var _bench_sc: ScrollContainer
var _pitch: Control
var _bench: Control
var _drag := {}         # 持ち上げ中 {id, src, preview}


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	build()


func build() -> void:
	_end_drag()
	if is_instance_valid(_bench_sc):
		_bench_x = _bench_sc.scroll_horizontal
	UI.clear(self)
	var entries := Game.formation_entries()
	var pw := Game.team_power(entries)
	var cost := Game.formation_cost()
	var cap := Game.cost_cap()
	if sel == 0 or not Game.owned(sel):
		sel = entries[0].id if not entries.is_empty() else 0

	# 見出し
	var head := UI.hbox(6)
	if back_to != "":
		var bk := UI.button("‹ %s" % back_to, "ghost", 12, 30)
		bk.pressed.connect(Nav.back)
		head.add_child(bk)
	head.add_child(UI.title("チーム編成"))
	head.add_child(UI.spacer())
	var auto := UI.button("おまかせ編成", "lime", 12, 30)
	auto.pressed.connect(_auto_menu)
	head.add_child(auto)
	add_child(head)
	add_child(UI.preset_bar(func():
		sel = 0
		build()))

	# フォーメーション・コスト・攻撃・守備
	var sp := UI.panel(UI.PANEL, 4)
	var sh := UI.hbox(0)
	var stats := [["FORMATION", Game.formation_name(entries), UI.INK], ["コスト", "%d/%d" % [cost, cap], UI.RED if cost > cap else UI.LIME],
		["攻撃", str(int(pw.atk)), UI.ROW_COLORS["攻"]], ["守備", str(int(pw.def)), UI.ROW_COLORS["守"]]]
	for i in stats.size():
		if i > 0:
			var d := ColorRect.new()
			d.color = UI.LINE
			d.custom_minimum_size = Vector2(1, 30)
			d.size_flags_vertical = SIZE_SHRINK_CENTER
			sh.add_child(d)
		var v := UI.vbox(0)
		v.size_flags_horizontal = SIZE_EXPAND_FILL
		v.add_child(UI.label(stats[i][0], 9, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER, true))
		v.add_child(UI.label(stats[i][1], 17, stats[i][2], HORIZONTAL_ALIGNMENT_CENTER, true))
		sh.add_child(v)
	sp.add_child(sh)
	add_child(sp)

	# スキルの確認（個人スキル・連携スキル）
	var sk := UI.hbox(6)
	var b1 := UI.button("個人スキル", "cyan_line", 12, 30)
	b1.size_flags_horizontal = SIZE_EXPAND_FILL
	b1.pressed.connect(_show_skills)
	sk.add_child(b1)
	var n_combo: int = pw.mods.combos.size()
	var b2 := UI.button("連携スキル %d発動中" % n_combo if n_combo > 0 else "連携スキル", "pink_line", 12, 30)
	b2.size_flags_horizontal = SIZE_EXPAND_FILL
	b2.pressed.connect(_show_combos)
	sk.add_child(b2)
	add_child(sk)

	# ピッチ
	var pitch = Pitch.new()
	pitch.size_flags_vertical = SIZE_EXPAND_FILL
	pitch.custom_minimum_size.y = 140
	for p in entries:
		var pp = PitchPlayer.new()
		pp.setup(p.id, p.row)
		pp.selected = p.id == sel
		UI.on_tap(pp, _select.bind(p.id), _start_drag.bind(p.id), LIFT_TIME, false, _start_drag.bind(p.id))
		pitch.add_child(pp)
		pitch.players[p.id] = pp
	add_child(pitch)
	_pitch = pitch

	# 選んだ選手
	if sel != 0:
		add_child(_selected_panel(sel))

	# 案内
	var hint := "タップでスキル確認・長押しかドラッグで移動"
	var hc := UI.DIM
	if cost > cap:
		hint = "コスト上限をこえています。控えへドラッグで外せます"
		hc = UI.RED
	elif entries.size() < Game.TEAM_SIZE:
		hint = "あと%d人出場できます。控えからピッチへドラッグ" % (Game.TEAM_SIZE - entries.size())
		hc = UI.CYAN
	# 操作の説明はいつもは出さず、注意が必要なときだけ出す（ピッチを広く使うため）
	if hc != UI.DIM:
		add_child(UI.label(hint, 10, hc, HORIZONTAL_ALIGNMENT_CENTER, true))

	# 控え
	add_child(_bench_panel())


func _selected_panel(id: int) -> Control:
	var c: Dictionary = Game.chars[id]
	var here := Game.in_team(id)
	var p := UI.panel(UI.PANEL, 6, UI.ROW_COLORS[c.pos])
	var v := UI.vbox(6)
	var top := UI.hbox(10)
	var card = UI.card(id, false, [UI.label(UI.stars(c.rarity), 10, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)], Callable(), 36)
	card.custom_minimum_size = Vector2(60, 58)
	top.add_child(card)
	var iv := UI.vbox(2)
	iv.size_flags_horizontal = SIZE_EXPAND_FILL
	var nh := UI.hbox(6)
	nh.add_child(UI.label(c.name, 15, UI.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
	if not here:
		nh.add_child(UI.tag("控え", UI.SUB, 9, false))
	iv.add_child(nh)
	var line := ColorRect.new()
	line.color = UI.LINE
	line.custom_minimum_size.y = 1
	iv.add_child(line)
	var sk := UI.hbox(6)
	var ib := PanelContainer.new()
	ib.add_theme_stylebox_override("panel", UI.sbox(Color(UI.CYAN, 0.12), 4, Color(UI.CYAN, 0.6), 1, 3))
	ib.add_child(Icon.make("flag", UI.CYAN, 16))
	sk.add_child(ib)
	sk.add_child(UI.label(c.skill.name, 14, UI.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
	sk.add_child(UI.tag("Lv%d" % Game.slv(id), UI.CYAN, 10, false))
	iv.add_child(sk)
	iv.add_child(UI.wrap_label(Game.skill_text(id, Game.slv(id)), 11, UI.CYAN))
	top.add_child(iv)
	v.add_child(top)
	var bh := UI.hbox(8)
	var info := UI.icon_button("詳細", "info", "ghost", 13, 32)
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	info.pressed.connect(_detail.bind(id))
	bh.add_child(info)
	var main_btn: Button
	if here:
		main_btn = UI.icon_button("入れ替え", "swap", "primary", 13, 32)
		main_btn.pressed.connect(_picker.bind(Game.row_of_id(id), id))
	else:
		main_btn = UI.icon_button("出場させる", "swap", "primary", 13, 32)
		main_btn.set_meta("sfx", "")
		main_btn.pressed.connect(func():
			var err := Game.place(id, c.pos)
			if err != "":
				Game.error_toast.emit(err)
				return
			Sound.play("drop")
			build())
	main_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	bh.add_child(main_btn)
	v.add_child(bh)
	p.add_child(v)
	return p


func _bench_panel() -> Control:
	var p := UI.panel(UI.PANEL, 4)
	var h := UI.hbox(8)
	var lab := UI.label("控え", 13, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER, true)
	lab.custom_minimum_size.x = 36
	h.add_child(lab)
	var ids: Array = Game.save.roster.keys().map(func(k): return int(k)).filter(func(id): return not Game.in_team(id))
	ids.sort_custom(func(a, b): return [Game.chars[a].rarity, -a] > [Game.chars[b].rarity, -b])
	var sc = UI.DragScroll.new()
	sc.horizontal = true
	sc.size_flags_horizontal = SIZE_EXPAND_FILL
	sc.custom_minimum_size.y = 50
	var row := UI.hbox(6)
	for id in ids:
		var card = UI.card(id, false, [UI.label(UI.stars(Game.chars[id].rarity), 9, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)], Callable(), 32)
		card.custom_minimum_size = Vector2(52, 50)
		card.selected = id == sel
		UI.on_tap(card, _select.bind(id), _start_drag.bind(id), LIFT_TIME, false, _start_drag.bind(id))
		row.add_child(card)
	if ids.is_empty():
		row.add_child(UI.label("全員出場中", 11, UI.DIM))
	sc.add_child(row)
	h.add_child(sc)
	p.add_child(h)
	_bench = p
	_bench_sc = sc
	# 選んだあとに作り直しても、スクロール位置はそのまま
	var x := _bench_x
	get_tree().process_frame.connect(func():
		if is_instance_valid(sc):
			sc.scroll_horizontal = x, CONNECT_ONE_SHOT)
	return p


func _select(id: int) -> void:
	sel = id
	build()


func _detail(id: int) -> void:
	CharDetail.open(self, id, {"team": true, "on_change": build, "on_swap": _picker.bind(Game.row_of_id(id), id)})


## おまかせの型をえらぶ
func _auto_menu() -> void:
	var v := UI.vbox(8)
	v.add_child(UI.title("おまかせ編成", "コスト上限の中で強い7体を並べる"))
	var desc := {"攻撃型": "FWを厚くして点を取りにいく", "バランス": "攻守のバランスをとる", "守備型": "DFを厚くして失点をおさえる"}
	var col := {"攻撃型": UI.ROW_COLORS["攻"], "バランス": UI.ROW_COLORS["中"], "守備型": UI.ROW_COLORS["守"]}
	var holder := {"m": null}
	for style in Game.AUTO_STYLES:
		var st: Dictionary = Game.AUTO_STYLES[style]
		var p := UI.panel(UI.PANEL2, 10, col[style])
		var h := UI.hbox(10)
		var nv := UI.vbox(2)
		nv.size_flags_horizontal = SIZE_EXPAND_FILL
		nv.add_child(UI.label(style, 16, col[style], HORIZONTAL_ALIGNMENT_LEFT, true))
		nv.add_child(UI.label(desc[style], 11, UI.SUB))
		h.add_child(nv)
		h.add_child(UI.label("%d-%d-%d" % [st["守"], st["中"], st["攻"]], 20, UI.INK, HORIZONTAL_ALIGNMENT_RIGHT, true))
		p.add_child(h)
		UI.on_tap(p, func():
			UI.close(holder.m)
			_auto(style))
		v.add_child(p)
	var cl := UI.button("とじる", "ghost", 13, 36)
	cl.pressed.connect(func(): UI.close(holder.m))
	v.add_child(cl)
	holder.m = UI.modal(self, v)


func _auto(style: String) -> void:
	Sound.play("skill")
	var before := Game.formation_entries().map(func(p): return [p.id, p.row])
	Game.auto_formation(style)
	var after := Game.formation_entries().map(func(p): return [p.id, p.row])
	build()
	Game.toast.emit("おまかせ（%s）で並べました（%s ・ コスト%d/%d）" % [style, Game.formation_name(), Game.formation_cost(), Game.cost_cap()]
		if before != after else "いまの編成がおまかせと同じです")
	for id in _pitch.players:
		var c: Control = _pitch.players[id]
		c.modulate = Color(1.6, 1.6, 1.6)
		c.create_tween().tween_property(c, "modulate", Color.WHITE, 0.5)


# ---------------------------------------------------------------- 持ち上げて運ぶ

func _start_drag(id: int) -> void:
	if not _drag.is_empty():
		return
	var src: Control = _pitch.players.get(id)
	if src == null:
		for c in _bench.find_children("*", "MarginContainer", true, false):
			if "cid" in c and c.cid == id:
				src = c
	if src == null:
		return
	if src is PitchPlayer:
		src.lifted = true
		src.queue_redraw()
	else:
		src.modulate.a = 0.3
	Sound.play("lift")
	var pv = PitchPlayer.new()
	pv.setup(id, "")
	pv.top_level = true
	pv.z_index = 20
	pv.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(pv)
	pv.global_position = src.get_global_rect().get_center() - pv.size / 2
	_drag = {"id": id, "src": src, "preview": pv}


func _input(e: InputEvent) -> void:
	if _drag.is_empty():
		return
	if e is InputEventMouseMotion:
		var pv: Control = _drag.preview
		pv.global_position = e.position - pv.size * Vector2(0.5, 0.45)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		_drop(e.position)


func _drop(at: Vector2) -> void:
	var id: int = _drag.id
	_end_drag()
	var in_team := Game.in_team(id)
	if _bench.get_global_rect().has_point(at):
		if in_team:
			Game.remove_from_team(id)
			Sound.play("remove")
			Game.toast.emit("%s を控えに下げました" % Game.chars[id].name)
	else:
		var other := 0
		for o in _pitch.players:
			if o != id and _pitch.players[o].get_global_rect().has_point(at):
				other = o
		if other:
			_exchange(id, other)
		elif _pitch.get_global_rect().has_point(at):
			var row: String = _pitch.row_at(at - _pitch.global_position)
			if not in_team or row != Game.row_of_id(id):
				var err := Game.place(id, row)
				if err != "":
					Game.error_toast.emit(err)
				else:
					Sound.play("drop")
	sel = id
	build.call_deferred()


## a と b を入れ替える（どちらかが控えならその人が出場）
func _exchange(a: int, b: int) -> void:
	var err := ""
	if Game.in_team(a) and Game.in_team(b):
		Game.swap(a, b)
	elif Game.in_team(b):
		err = Game.place(a, Game.row_of_id(b), b)
	elif Game.in_team(a):
		err = Game.place(b, Game.row_of_id(a), a)
	if err != "":
		Game.error_toast.emit(err)
	else:
		Sound.play("drop")


func _end_drag() -> void:
	if _drag.is_empty():
		return
	var src = _drag.src
	if is_instance_valid(src):
		if src is PitchPlayer:
			src.lifted = false
			src.queue_redraw()
		else:
			src.modulate.a = 1.0
	_drag.preview.queue_free()
	_drag = {}


# ---------------------------------------------------------------- 個人スキル・連携スキル

## 出場中の7体の固有スキル
func _show_skills() -> void:
	var entries := Game.formation_entries()
	var v := UI.vbox(6)
	v.add_child(UI.title("個人スキル", "出場中の選手の固有スキル"))
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
			nh.add_child(UI.label(UI.stars(c.rarity), 9, UI.GOLD))
			sv.add_child(nh)
			var sh := UI.hbox(6)
			sh.add_child(UI.label(c.skill.name, 14, UI.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
			sh.add_child(UI.tag("Lv%d" % p.slv, UI.CYAN, 9, false))
			sv.add_child(sh)
			sv.add_child(UI.wrap_label(Game.skill_text(p.id, p.slv), 11, UI.CYAN))
			h.add_child(sv)
			var pn := UI.panel(UI.PANEL2, 6, UI.ROW_COLORS[row])
			pn.add_child(h)
			UI.on_tap(pn, _detail.bind(p.id))
			v.add_child(pn)
	if entries.is_empty():
		v.add_child(UI.label("出場中の選手がいません", 11, UI.DIM))
	v.add_child(UI.label("タップで詳細", 10, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var holder := {"m": null}
	var cl := UI.button("とじる", "ghost", 13, 36)
	cl.pressed.connect(func(): UI.close(holder.m))
	v.add_child(cl)
	holder.m = UI.modal(self, v)


func _show_combos() -> void:
	var entries := Game.formation_entries()
	var v := UI.vbox(6)
	v.add_child(UI.title("連携スキル", "発動中と、あと1人で発動するもの"))
	var ids := entries.map(func(p): return p.id)
	var shown := 0
	for cb in Game.combos:
		var missing: Array = cb.ids.filter(func(i): return not i in ids)
		if missing.size() > 1 or (missing.size() == 1 and not Game.owned(missing[0])):
			continue
		shown += 1
		var on := missing.is_empty()
		var pn := UI.panel(UI.PANEL2, 8, UI.PINK if on else UI.LINE)
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
	var holder := {"m": null}
	var cl := UI.button("とじる", "ghost", 13, 36)
	cl.pressed.connect(func(): UI.close(holder.m))
	v.add_child(cl)
	holder.m = UI.modal(self, v)


# ---------------------------------------------------------------- 選手をえらぶ

## 選手をえらぶ。replace を渡すとその選手と交代する。
func _picker(row: String, replace := 0) -> void:
	var v := UI.vbox(8)
	var room: int = Game.cost_cap() - Game.formation_cost() + (Game.chars[replace].rarity if replace else 0)
	v.add_child(UI.title("交代する選手" if replace else "選手をえらぶ", "%s ／ 使えるコスト %d" % [UI.POS_LABEL[row], room]))
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
		var lines: Array = [c.name, UI.label(UI.stars(c.rarity), 9, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)]
		var here := Game.in_team(id)
		if here:
			lines.append(UI.tag("出場中:" + UI.POS_LABEL[Game.row_of_id(id)], UI.SUB, 8))
		var card = UI.card(id, false, lines, func():
			var err := Game.place(id, row, replace)
			if err != "":
				Game.error_toast.emit(err)
				return
			Sound.play("drop")
			sel = id
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
