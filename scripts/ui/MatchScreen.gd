extends VBoxContainer
## 試合：リーグ選択 → 相手を見て作戦を選ぶ → 自動試合 → 勝ったらスカウト

const UI = preload("res://scripts/ui/UI.gd")

var league := 0
var result := {}
var opp_team := {}
var scouted := false


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	show_leagues()


func show_leagues() -> void:
	UI.clear(self)
	var head := UI.hbox()
	head.add_child(UI.label("リーグを選ぶ", 18))
	head.add_child(UI.spacer())
	head.add_child(UI.tag("いまは %s" % Game.time_text(), Color("5a5a9a") if Game.is_night() else UI.ORANGE, 12))
	add_child(head)
	add_child(UI.label("通算 %d勝 %d分 %d敗" % [Game.save.wins, Game.save.draws, Game.save.losses], 12, UI.SUB))

	var list := UI.vbox(8)
	for i in Game.LEAGUES.size():
		var L: Dictionary = Game.LEAGUES[i]
		var v := UI.vbox(4)
		var h := UI.hbox()
		h.add_child(UI.label(L.name, 16))
		h.add_child(UI.spacer())
		h.add_child(UI.tag("強さ " + "▲".repeat(L.lv), [UI.GREEN, UI.ORANGE, Color("d05050")][i], 11))
		v.add_child(h)
		v.add_child(UI.label(L.desc, 11, UI.SUB))
		# 出会える選手（未発見はシルエット）
		var icons := UI.hbox(2)
		var new_count := 0
		for id in L.pool:
			var has: bool = Game.owned(id, false)
			var ic := UI.icon(Game.chars[id], false, not has, 32)
			if not Game.available(id):
				ic.modulate.a = 0.3
			icons.add_child(ic)
			if not has:
				new_count += 1
		v.add_child(icons)
		if new_count > 0:
			v.add_child(UI.label("未登録の選手が %d 体いる" % new_count, 11, Color("d05050")))
		list.add_child(UI.tile(v, UI.CARD, _preview.bind(i)))
	add_child(UI.scroll(list))


func _preview(i: int, refresh := false) -> void:
	league = i
	opp_team = Game.get_opponent(i, refresh)
	UI.clear(self)
	var top := UI.hbox()
	var back := UI.button("←", UI.GRAY, 13, 30)
	back.pressed.connect(show_leagues)
	top.add_child(back)
	top.add_child(UI.label("VS %s" % opp_team.name, 17))
	add_child(top)

	var body := UI.vbox(8)
	var op := UI.panel()
	var ov := UI.vbox(4)
	ov.add_child(UI.label("相手のメンバー（勝てば1体スカウトできる）", 12, UI.SUB))
	var g := UI.grid(4, 4)
	for m in opp_team.members:
		var c: Dictionary = Game.chars[m.id]
		var lines := [c.name, UI.label("%s Lv%d" % [m.row, m.lv], 9, UI.ROW_COLORS[m.row], HORIZONTAL_ALIGNMENT_CENTER)]
		if not Game.owned(m.id, m.shiny):
			lines.append(UI.tag("未登録", Color("e04848"), 9))
		if m.shiny:
			lines.append(UI.tag("色違い", Color("e8a000"), 9))
		var t := UI.char_tile(c, m.shiny, false, lines, Callable(), 40)
		t.size_flags_horizontal = SIZE_EXPAND_FILL
		g.add_child(t)
	ov.add_child(g)
	op.add_child(ov)
	body.add_child(op)

	var mine := Game.formation_entries()
	var a := Game.team_power(mine)
	var b := Game.team_power(opp_team.members)
	var cmp := UI.panel()
	var cg := UI.grid(3, 4)
	for row in [["", "こちら", "相手"], ["攻撃力", "%d" % a.atk, "%d" % b.atk], ["守備力", "%d" % a.def, "%d" % b.def]]:
		for x in row:
			var l := UI.label(x, 13, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
			l.size_flags_horizontal = SIZE_EXPAND_FILL
			cg.add_child(l)
	cmp.add_child(cg)
	body.add_child(cmp)

	body.add_child(UI.label("作戦", 14))
	var th := UI.hbox(6)
	for tac in Game.TACTICS:
		var tb := UI.button(tac, UI.BLUE if tac == Game.save.tactic else UI.GRAY, 14, 36)
		tb.size_flags_horizontal = SIZE_EXPAND_FILL
		tb.pressed.connect(func():
			Game.save.tactic = tac
			Game.save_game()
			_preview(i))
		th.add_child(tb)
	body.add_child(th)
	body.add_child(UI.label(Game.TACTIC_DESC[Game.save.tactic], 12, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(UI.scroll(body))

	var bh := UI.hbox(6)
	var re := UI.button("相手を変える", UI.GRAY, 13, 48)
	re.pressed.connect(_preview.bind(i, true))
	bh.add_child(re)
	var go := UI.button("キックオフ！", Color("e35d5d"), 18, 48)
	go.size_flags_horizontal = SIZE_EXPAND_FILL
	go.disabled = mine.size() < 7
	go.pressed.connect(_kickoff)
	bh.add_child(go)
	add_child(bh)
	if mine.size() < 7:
		add_child(UI.label("編成で7体を並べてね", 12, Color("d05050"), HORIZONTAL_ALIGNMENT_CENTER))


func _kickoff() -> void:
	var mine := Game.formation_entries()
	result = Game.simulate(mine, opp_team.members, Game.save.tactic)
	result.reward = Game.finish_match(league, result.outcome)
	scouted = false
	UI.clear(self)

	var board := UI.panel(Color("2f4a3a"), 10)
	var bv := UI.vbox(2)
	var names := UI.hbox()
	var n1 := UI.label("もふもふ蹴球団", 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var n2 := UI.label(opp_team.name, 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	n1.size_flags_horizontal = SIZE_EXPAND_FILL
	n2.size_flags_horizontal = SIZE_EXPAND_FILL
	names.add_child(n1)
	names.add_child(n2)
	bv.add_child(names)
	var score := UI.label("0 - 0", 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	bv.add_child(score)
	var clock := UI.label("キックオフ", 11, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	bv.add_child(clock)
	board.add_child(bv)
	add_child(board)

	var feed := UI.vbox(4)
	var sc := UI.scroll(feed)
	add_child(sc)
	var skip := UI.button("結果までとばす", UI.GRAY, 13, 34)
	add_child(skip)

	# イベントを少しずつ表示する（演出は後回しなので文字だけ）
	var g := [0, 0]
	var state := {"skip": false}
	skip.pressed.connect(func(): state.skip = true)
	for e in result.events:
		if not state.skip:
			await get_tree().create_timer(0.55).timeout
			if not is_inside_tree():
				return
		var mine_side: bool = e.team == 0
		if e.goal:
			g[e.team] += 1
		var line := UI.label("%d'  %s" % [e.min, e.text], 13,
			UI.ORANGE if mine_side else Color("5a7aa8"),
			HORIZONTAL_ALIGNMENT_LEFT if mine_side else HORIZONTAL_ALIGNMENT_RIGHT)
		feed.add_child(line)
		score.text = "%d - %d" % g
		clock.text = "%d分" % e.min
	if not state.skip:
		await get_tree().create_timer(0.6).timeout
		if not is_inside_tree():
			return
	score.text = "%d - %d" % result.goals
	clock.text = "試合終了"
	skip.queue_free()
	if result.events.is_empty():
		feed.add_child(UI.label("静かな試合だった…", 13, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
	_show_result()


func _show_result() -> void:
	var o: String = result.outcome
	var txt: String = {"win": "勝利！", "draw": "引き分け", "lose": "敗北…"}[o]
	var col: Color = {"win": Color("e35d5d"), "draw": UI.ORANGE, "lose": UI.BLUE}[o]
	var rv := UI.vbox(6)
	rv.add_child(UI.label(txt, 26, col, HORIZONTAL_ALIGNMENT_CENTER))
	rv.add_child(UI.label("ガチャ石 +%d" % result.reward, 14, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	if o == "win":
		rv.add_child(UI.label("スカウトする選手を1体えらんでね（MVPほど成功しやすい）", 11, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
		var g := UI.grid(4, 4)
		for i in opp_team.members.size():
			var m: Dictionary = opp_team.members[i]
			var c: Dictionary = Game.chars[m.id]
			var lines: Array = [c.name, UI.label("成功率%d%%" % result.scout_rates[i], 9, UI.GREEN, HORIZONTAL_ALIGNMENT_CENTER)]
			if i == result.mvp:
				lines.append(UI.tag("MVP", Color("e8a000"), 9))
			if not Game.owned(m.id, m.shiny):
				lines.append(UI.tag("未登録", Color("e04848"), 9))
			var t := UI.char_tile(c, m.shiny, false, lines, _scout.bind(i, rv), 40)
			t.size_flags_horizontal = SIZE_EXPAND_FILL
			g.add_child(t)
		rv.add_child(g)
	else:
		rv.add_child(UI.label("負けても選手は失わない。編成や作戦を見直そう", 11, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
	var panel := UI.panel(UI.CARD, 10)
	panel.add_child(rv)
	add_child(panel)
	var home := UI.button("リーグ選択へ", UI.ORANGE, 15, 40)
	home.pressed.connect(func():
		Game.get_opponent(league, true)
		show_leagues())
	add_child(home)


func _scout(i: int, box: VBoxContainer) -> void:
	if scouted:
		return
	scouted = true
	var m: Dictionary = opp_team.members[i]
	var c: Dictionary = Game.chars[m.id]
	var res := Game.try_scout(m, result.scout_rates[i])
	# 選択肢を消して結果を出す
	for ch in box.get_children():
		if ch is GridContainer:
			ch.queue_free()
	var h := UI.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(UI.icon(c, m.shiny, false, 64))
	var v := UI.vbox(2)
	if res.ok:
		v.add_child(UI.label("%sが仲間になった！" % c.name, 15, Color("e35d5d")))
		var tags := UI.hbox(4)
		if res.new:
			tags.add_child(UI.tag("NEW! 図鑑登録", Color("e04848"), 11))
		elif res.lv_up:
			tags.add_child(UI.tag("被り → Lv%d" % Game.lv_of(Game.key(m.id, m.shiny)), UI.BLUE, 11))
		else:
			tags.add_child(UI.tag("被り → かけら+%d" % res.fragments, Color("c070a0"), 11))
		if m.shiny:
			tags.add_child(UI.tag("色違い", Color("e8a000"), 11))
		v.add_child(tags)
	else:
		v.add_child(UI.label("%sにことわられた…" % c.name, 15, UI.BLUE))
		v.add_child(UI.label("また挑戦しよう", 11, UI.SUB))
	h.add_child(v)
	box.add_child(h)
