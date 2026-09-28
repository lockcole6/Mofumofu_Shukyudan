extends RefCounted
## キャラ詳細のモーダル。図鑑・編成・試合のどこからでも開ける。
## opts: {"team": true} で「外す」ボタン、{"readonly": true} で操作なし、{"on_change": Callable}

const UI = preload("res://scripts/ui/UI.gd")
const SOURCE_TEXT := {"both": "ガチャ・スカウト", "gacha": "ガチャ限定", "scout": "スカウト限定"}
const LIMIT_TEXT := {"night": "夜だけ出現", "summer_night": "夏の夜だけ出現"}


static func open(from: Node, id: int, opts := {}) -> void:
	var v := UI.vbox(10)
	var h := {"m": null, "refresh": Callable()}
	h.refresh = func():
		UI.clear(v)
		_build(v, id, opts, func():
			if opts.has("on_change"):
				opts.on_change.call()
			h.refresh.call(), func(): UI.close(h.m))
	h.refresh.call()
	h.m = UI.modal(from, v)


static func _build(v: VBoxContainer, id: int, opts: Dictionary, changed: Callable, close: Callable) -> void:
	var c: Dictionary = Game.chars[id]
	var has: bool = Game.owned(id)
	var rc: Color = UI.RARITY_COLORS[c.rarity]

	# 見出し
	var head := UI.hbox(12)
	var card := UI.card(id, not has, [], Callable(), 96)
	card.custom_minimum_size = Vector2(112, 112)
	head.add_child(card)
	var hv := UI.vbox(4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.label("No.%02d" % id, 11, UI.SUB))
	var nm := UI.label(c.name if has else "？？？", 20, UI.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	nm.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	hv.add_child(nm)
	hv.add_child(UI.label(UI.stars(c.rarity) + "  コスト%d" % c.rarity, 14, rc))
	var tags := UI.flow(4)
	tags.add_child(UI.tag(c.habitat, UI.HABITAT_COLORS[c.habitat], 10, false))
	tags.add_child(UI.tag("得意 " + c.pos, UI.ROW_COLORS[c.pos], 10, false))
	tags.add_child(UI.tag(SOURCE_TEXT[c.source], UI.SUB, 10, false))
	if LIMIT_TEXT.has(c.limit):
		tags.add_child(UI.tag(LIMIT_TEXT[c.limit], UI.PINK, 10, false))
	hv.add_child(tags)
	head.add_child(hv)
	v.add_child(head)

	if not has:
		var hp := UI.panel(UI.PANEL2, 10, UI.PINK)
		hp.add_child(UI.wrap_label("ヒント：" + c.hint, 13))
		v.add_child(hp)
	else:
		v.add_child(UI.wrap_label(c.desc, 12, UI.SUB))

	# 能力
	var st := UI.grid(3, 6)
	for s in [["スピード", "spd"], ["パワー", "pow"], ["パス", "pas"], ["守備", "def"]]:
		var l := UI.label(s[0], 11, UI.SUB)
		l.custom_minimum_size.x = 56
		st.add_child(l)
		var b := UI.bar(c[s[1]] if has else 0, 10, UI.CYAN)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		st.add_child(b)
		st.add_child(UI.label(str(c[s[1]]) if has else "?", 12, UI.INK, HORIZONTAL_ALIGNMENT_RIGHT, true))
	v.add_child(st)

	# 固有スキル
	var lv := Game.slv(id)
	var sp := UI.panel(UI.PANEL2, 10, UI.CYAN)
	var sv := UI.vbox(3)
	var sh := UI.hbox(6)
	sh.add_child(UI.label("固有スキル", 10, UI.CYAN, HORIZONTAL_ALIGNMENT_LEFT, true))
	sh.add_child(UI.spacer())
	if has:
		sh.add_child(UI.label("Lv %d / %d" % [lv, Game.MAX_SLV], 12, UI.CYAN, HORIZONTAL_ALIGNMENT_LEFT, true))
	sv.add_child(sh)
	sv.add_child(UI.label(c.skill.name if has else "？？？", 16, UI.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
	sv.add_child(UI.wrap_label(Game.skill_text(id, lv), 12, UI.INK))
	if has and lv < Game.MAX_SLV:
		sv.add_child(UI.label("次のLv：" + Game.skill_text(id, lv + 1), 11, UI.SUB))
	sp.add_child(sv)
	v.add_child(sp)

	# 連携スキル
	var cbs := Game.combos_of(id)
	if not cbs.is_empty():
		v.add_child(UI.label("連携スキル", 11, UI.PINK, HORIZONTAL_ALIGNMENT_LEFT, true))
		var team_ids := Game.formation_entries().map(func(p): return p.id)
		for cb in cbs:
			var active: bool = cb.ids.all(func(i): return i in team_ids)
			var cp := UI.panel(UI.PANEL2, 8, UI.PINK if active else UI.LINE)
			var cv := UI.vbox(4)
			var ch := UI.hbox(6)
			ch.add_child(UI.label(cb.name, 13, UI.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
			ch.add_child(UI.spacer())
			if active:
				ch.add_child(UI.tag("発動中", UI.PINK, 9))
			cv.add_child(ch)
			var mh := UI.hbox(2)
			for mid in cb.ids:
				mh.add_child(UI.icon(Game.chars[mid], not Game.owned(mid), 30))
			cv.add_child(mh)
			cv.add_child(UI.label(Game.combo_text(cb), 11, UI.SUB))
			cp.add_child(cv)
			v.add_child(cp)

	# 操作
	if has and not opts.get("readonly", false):
		v.add_child(UI.label("所持している余り：%d体" % Game.copies(id), 12, UI.SUB))
		var ah := UI.hbox(8)
		var up := UI.button("スキル強化（%d体）" % Game.skill_up_cost(id) if lv < Game.MAX_SLV else "スキル最大", "primary", 13, 38)
		up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		up.disabled = not Game.can_skill_up(id)
		up.pressed.connect(func():
			Game.skill_up(id)
			changed.call())
		ah.add_child(up)
		var sell := UI.button("売却 +◆%d" % Game.SELL_VALUE[c.rarity], "ghost", 13, 38)
		sell.disabled = Game.copies(id) <= 0
		sell.pressed.connect(func():
			Game.sell(id, 1)
			changed.call())
		ah.add_child(sell)
		v.add_child(ah)
		if opts.get("team", false) and Game.in_team(id):
			var rm := UI.button("編成から外す", "danger", 13, 36)
			rm.pressed.connect(func():
				Game.remove_from_team(id)
				if opts.has("on_change"):
					opts.on_change.call()
				close.call())
			v.add_child(rm)
	var cl := UI.button("とじる", "ghost", 13, 36)
	cl.pressed.connect(close)
	v.add_child(cl)
