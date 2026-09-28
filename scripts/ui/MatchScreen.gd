extends VBoxContainer
## 試合：ディビジョンの順位表 → 次の相手を見て作戦を選ぶ → 自動試合 → 勝ったらスカウト
## 5節終わるとシーズン終了。上位2チームが昇格、下位2チームが降格。

const UI = preload("res://scripts/ui/UI.gd")
const CharDetail = preload("res://scripts/ui/CharDetail.gd")
const SPEED := {"normal": 0.5, "fast": 0.15, "instant": 0.0}
const ZONE_COLORS := {"up": Color("3ddc97"), "champion": Color("ffc83d"), "down": Color("ff4d6d"), "": Color(0, 0, 0, 0)}

var result := {}
var scouted := false
var _view := 0   # 画面を切り替えるたびに増やす。試合の演出が古い画面に書き込まないように


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	show_league()


func show_league() -> void:
	_view += 1
	UI.clear(self)
	var L: Dictionary = Game.save.league
	var body := UI.vbox(10)
	var head := UI.hbox()
	head.add_child(UI.title("%d部リーグ" % Game.division(), "SEASON %d" % L.season))
	head.add_child(UI.spacer())
	head.add_child(UI.tag("いまは %s" % Game.time_text(), UI.PINK if Game.is_night() else UI.GOLD, 10, false))
	body.add_child(head)
	body.add_child(_table(Game.standings(), L.table))

	if Game.season_over():
		var p := UI.panel(UI.PANEL, 12, UI.LIME)
		var pv := UI.vbox(8)
		pv.add_child(UI.label("全日程終了！", 18, UI.LIME, HORIZONTAL_ALIGNMENT_CENTER, true))
		var b := UI.button("シーズン結果へ", "primary", 15, 44)
		b.pressed.connect(_season_end)
		pv.add_child(b)
		p.add_child(pv)
		body.add_child(p)
		add_child(UI.scroll(body))
		return

	var opp_i := Game.opponent_index()
	var opp := Game.lineup(opp_i)
	var mine := Game.formation_entries()
	var np := UI.panel(UI.PANEL, 10, UI.CYAN)
	var nv := UI.vbox(8)
	var nh := UI.hbox(6)
	nh.add_child(UI.label("第%d節" % (int(L.round) + 1), 12, UI.CYAN, HORIZONTAL_ALIGNMENT_LEFT, true))
	nh.add_child(UI.label("VS", 12, UI.SUB, HORIZONTAL_ALIGNMENT_LEFT, true))
	nh.add_child(UI.label(L.teams[opp_i].name, 15, UI.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
	nv.add_child(nh)
	nv.add_child(_mini_pitch(opp))
	nv.add_child(UI.label("勝てば1体スカウトできる（ガチャ限定の選手は不可）", 10, UI.SUB))

	var a := Game.team_power(mine)
	var b := Game.team_power(opp)
	for s in [["攻撃", "atk", UI.ROW_COLORS["攻"]], ["守備", "def", UI.ROW_COLORS["守"]]]:
		var row := UI.hbox(6)
		var mv: float = a[s[1]]
		var ov: float = b[s[1]]
		var l1 := UI.label(str(int(mv)), 13, UI.CYAN, HORIZONTAL_ALIGNMENT_RIGHT, true)
		l1.custom_minimum_size.x = 34
		row.add_child(l1)
		var b1 := UI.bar(mv, mv + ov, UI.CYAN, 6)
		b1.fill_mode = ProgressBar.FILL_END_TO_BEGIN
		b1.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(b1)
		var mid := UI.label(s[0], 11, s[2], HORIZONTAL_ALIGNMENT_CENTER, true)
		mid.custom_minimum_size.x = 34
		row.add_child(mid)
		var b2 := UI.bar(ov, mv + ov, UI.PINK, 6)
		b2.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(b2)
		var l2 := UI.label(str(int(ov)), 13, UI.PINK, HORIZONTAL_ALIGNMENT_LEFT, true)
		l2.custom_minimum_size.x = 34
		row.add_child(l2)
		nv.add_child(row)
	np.add_child(nv)
	body.add_child(np)

	body.add_child(UI.label("作戦", 11, UI.SUB, HORIZONTAL_ALIGNMENT_LEFT, true))
	body.add_child(UI.segmented(Game.TACTICS, Game.save.tactic, func(t):
		Game.save.tactic = t
		Game.save_game()
		show_league()))
	body.add_child(UI.label(Game.TACTIC_DESC[Game.save.tactic], 11, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(UI.scroll(body))

	var go := UI.button("キックオフ", "pink", 18, 50)
	var cost := Game.formation_cost()
	if mine.size() < Game.TEAM_SIZE:
		go.disabled = true
		go.text = "編成で7体を並べてね"
	elif cost > Game.cost_cap():
		go.disabled = true
		go.text = "コスト上限オーバー（%d/%d）" % [cost, Game.cost_cap()]
	go.pressed.connect(_kickoff)
	add_child(go)


func _table(order: Array, T: Array) -> PanelContainer:
	var p := UI.panel(UI.PANEL, 8)
	var g := UI.grid(6, 4)
	var heads := ["", "チーム", "試", "勝-分-敗", "得失", "勝点"]
	for h in heads:
		var l := UI.label(h, 9, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER, true)
		g.add_child(l)
	for rank in order.size():
		var i: int = order[rank]
		var t: Dictionary = T[i]
		var me := i == 0
		var z := Game.zone(rank + 1)
		var col := UI.CYAN if me else UI.INK
		var rk := UI.tag(str(rank + 1), ZONE_COLORS[z] if z != "" else UI.LINE, 10)
		rk.size_flags_horizontal = SIZE_SHRINK_CENTER
		g.add_child(rk)
		var nm := UI.label(Game.save.league.teams[i].name, 12, col, HORIZONTAL_ALIGNMENT_LEFT, me)
		nm.size_flags_horizontal = SIZE_EXPAND_FILL
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		g.add_child(nm)
		g.add_child(UI.label(str(int(t.w) + int(t.d) + int(t.l)), 11, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
		g.add_child(UI.label("%d-%d-%d" % [t.w, t.d, t.l], 11, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
		var gd := int(t.gf) - int(t.ga)
		g.add_child(UI.label(("+%d" if gd > 0 else "%d") % gd, 11, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
		g.add_child(UI.label(str(t.pts), 14, col, HORIZONTAL_ALIGNMENT_CENTER, true))
	var v := UI.vbox(6)
	v.add_child(g)
	var legend := UI.hbox(10)
	if Game.division() > 1:
		legend.add_child(UI.label("■ 昇格", 9, ZONE_COLORS.up))
	else:
		legend.add_child(UI.label("■ 優勝", 9, ZONE_COLORS.champion))
	if Game.division() < 5:
		legend.add_child(UI.label("■ 降格", 9, ZONE_COLORS.down))
	legend.add_child(UI.spacer())
	legend.add_child(UI.label("コスト上限 %d" % Game.cost_cap(), 9, UI.SUB))
	v.add_child(legend)
	p.add_child(v)
	return p


## 相手のメンバーを列ごとに中央寄せで見せる
func _mini_pitch(members: Array) -> VBoxContainer:
	var v := UI.vbox(3)
	for row in Game.GRID_ROWS:
		var h := UI.hbox(3)
		var lab := UI.label(row, 9, UI.ROW_COLORS[row], HORIZONTAL_ALIGNMENT_CENTER, true)
		lab.custom_minimum_size.x = 22
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.size_flags_vertical = SIZE_FILL
		h.add_child(lab)
		var center := CenterContainer.new()
		center.size_flags_horizontal = SIZE_EXPAND_FILL
		var cards := UI.hbox(3)
		for m in members:
			if m.row != row:
				continue
			var lines := []
			if not Game.owned(m.id):
				lines.append(UI.tag("NEW", UI.PINK, 8))
			var card = UI.card(m.id, false, lines, func(): CharDetail.open(self, m.id, {"readonly": true}), 30)
			card.custom_minimum_size = Vector2(52, 48)
			cards.add_child(card)
		center.add_child(cards)
		h.add_child(center)
		var r := Control.new()
		r.custom_minimum_size.x = 22
		h.add_child(r)
		v.add_child(h)
	v.add_child(UI.label(Game.formation_name(members), 10, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER, true))
	return v


func _kickoff() -> void:
	var L: Dictionary = Game.save.league
	result = Game.play_round(Game.save.tactic)
	scouted = false
	_view += 1
	var view := _view
	UI.clear(self)
	Nav.push(self, show_league)

	var board := PanelContainer.new()
	var bsb := UI.sbox(UI.PANEL, 6, Color(UI.CYAN, 0.4), 1, 10)
	board.add_theme_stylebox_override("panel", bsb)
	var bv := UI.vbox(2)
	var names := UI.hbox()
	var n1 := UI.label("もふもふ蹴球団", 11, UI.CYAN, HORIZONTAL_ALIGNMENT_CENTER, true)
	var n2 := UI.label(L.teams[result.opp_i].name, 11, UI.PINK, HORIZONTAL_ALIGNMENT_CENTER, true)
	n1.size_flags_horizontal = SIZE_EXPAND_FILL
	n2.size_flags_horizontal = SIZE_EXPAND_FILL
	names.add_child(n1)
	names.add_child(n2)
	bv.add_child(names)
	var score := UI.label("0 - 0", 40, UI.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	bv.add_child(score)
	var clock := UI.label("KICK OFF", 10, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER, true)
	bv.add_child(clock)
	board.add_child(bv)
	add_child(board)

	var feed := UI.vbox(3)
	add_child(UI.scroll(feed))
	var skip := UI.button("結果までとばす", "ghost", 12, 32)
	add_child(skip)

	var wait: float = SPEED.get(Game.save.settings.speed, 0.5)
	var state := {"skip": wait <= 0.0}
	skip.pressed.connect(func(): state.skip = true)
	var g := [0, 0]
	for e in result.events:
		if not state.skip:
			await get_tree().create_timer(wait).timeout
			if not is_inside_tree() or view != _view:
				return
		var mine: bool = e.team == 0
		if e.goal:
			g[e.team] += 1
		var txt: String = ("%d'  " % e.min if e.min > 0 else "") + e.text
		var col: Color = UI.SUB
		if e.goal:
			col = UI.CYAN if mine else UI.PINK
		elif e.get("skill", false):
			col = Color(UI.CYAN if mine else UI.PINK, 0.7)
		var line := UI.label(txt, 14 if e.goal else 11, col,
			HORIZONTAL_ALIGNMENT_LEFT if mine else HORIZONTAL_ALIGNMENT_RIGHT, e.goal)
		feed.add_child(line)
		score.text = "%d - %d" % g
		clock.text = "%d'" % e.min
	if not state.skip:
		await get_tree().create_timer(wait).timeout
		if not is_inside_tree() or view != _view:
			return
	score.text = "%d - %d" % result.goals
	clock.text = "FULL TIME"
	skip.queue_free()
	if result.events.is_empty():
		feed.add_child(UI.label("静かな試合だった…", 12, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
	_show_result()


func _show_result() -> void:
	var o: String = result.outcome
	var txt: String = {"win": "WIN", "draw": "DRAW", "lose": "LOSE"}[o]
	var col: Color = {"win": UI.LIME, "draw": UI.GOLD, "lose": UI.RED}[o]
	var p := UI.panel(UI.PANEL, 10, col)
	var rv := UI.vbox(6)
	var rh := UI.hbox(10)
	rh.alignment = BoxContainer.ALIGNMENT_CENTER
	rh.add_child(UI.label(txt, 26, col, HORIZONTAL_ALIGNMENT_CENTER, true))
	var rw := UI.label("◆ +%d" % result.reward, 14, UI.CYAN, HORIZONTAL_ALIGNMENT_CENTER, true)
	rw.size_flags_vertical = SIZE_SHRINK_CENTER
	rh.add_child(rw)
	rv.add_child(rh)
	if o == "win":
		rv.add_child(UI.label("スカウトする選手を1体えらぶ（MVPは成功率100%）", 10, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
		var g := UI.grid(4, 4)
		for i in result.opp.size():
			var m: Dictionary = result.opp[i]
			var c: Dictionary = Game.chars[m.id]
			var rate: int = result.scout_rates[i]
			var lines: Array = [c.name]
			if rate > 0:
				lines.append(UI.label("%d%%" % rate, 10, UI.LIME, HORIZONTAL_ALIGNMENT_CENTER, true))
			else:
				lines.append(UI.label("不可", 10, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER, true))
			if i == result.mvp:
				lines.append(UI.tag("MVP", UI.GOLD, 8))
			elif not Game.owned(m.id):
				lines.append(UI.tag("NEW", UI.PINK, 8))
			var card = UI.card(m.id, false, lines, _scout.bind(i, rv), 34)
			card.size_flags_horizontal = SIZE_EXPAND_FILL
			card.dim = rate == 0
			g.add_child(card)
		rv.add_child(g)
	else:
		rv.add_child(UI.label("負けても選手は失わない。編成や作戦を見直そう", 10, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
	# 同じ節のほかの試合
	var others := UI.vbox(1)
	for r in result.others:
		var T: Array = Game.save.league.teams
		others.add_child(UI.label("%s  %d - %d  %s" % [T[r.a].name, r.goals[0], r.goals[1], T[r.b].name], 10, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
	rv.add_child(others)
	p.add_child(rv)
	add_child(p)
	var nx := UI.button("順位表へ", "primary", 15, 42)
	nx.pressed.connect(func(): Nav.close(self))
	add_child(nx)


func _scout(i: int, box: VBoxContainer) -> void:
	var rate: int = result.scout_rates[i]
	if scouted or rate <= 0:
		return
	scouted = true
	var m: Dictionary = result.opp[i]
	var c: Dictionary = Game.chars[m.id]
	var res := Game.try_scout(m, rate)
	for ch in box.get_children():
		if ch is GridContainer:
			ch.queue_free()
	var h := UI.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(UI.icon(c, false, 56))
	var v := UI.vbox(2)
	if res.ok:
		v.add_child(UI.label("%s が仲間になった！" % c.name, 14, UI.LIME, HORIZONTAL_ALIGNMENT_LEFT, true))
		v.add_child(UI.tag("NEW! 図鑑登録" if res.new else "被り → スキル強化素材 +1", UI.PINK if res.new else UI.CYAN, 10))
	else:
		v.add_child(UI.label("%s にことわられた…" % c.name, 14, UI.SUB, HORIZONTAL_ALIGNMENT_LEFT, true))
	h.add_child(v)
	box.add_child(h)
	box.move_child(h, 1)


func _season_end() -> void:
	var order := Game.standings()
	var table: Array = Game.save.league.table.duplicate(true)
	var teams: Array = Game.save.league.teams
	var s := Game.end_season()
	_view += 1
	UI.clear(self)
	Nav.push(self, show_league)
	var body := UI.vbox(10)
	var msg: Array = {"up": ["昇格！", UI.LIME, "%d部へ上がります" % s.to],
		"down": ["降格…", UI.RED, "%d部へ下がります" % s.to],
		"champion": ["優勝！", UI.GOLD, "1部の頂点に立った！"],
		"": ["残留", UI.CYAN, "%d部で次のシーズンへ" % s.to]}[s.zone]
	var p := UI.panel(UI.PANEL, 14, msg[1])
	var pv := UI.vbox(4)
	pv.add_child(UI.label("SEASON RESULT  %d部 %d位" % [s.from, s.rank], 12, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER, true))
	pv.add_child(UI.label(msg[0], 34, msg[1], HORIZONTAL_ALIGNMENT_CENTER, true))
	pv.add_child(UI.label(msg[2], 13, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	pv.add_child(UI.label("シーズン報酬 ◆ +%d" % s.reward, 15, UI.CYAN, HORIZONTAL_ALIGNMENT_CENTER, true))
	if s.to != s.from:
		pv.add_child(UI.label("コスト上限 %d → %d" % [Game.COST_CAP[s.from], Game.COST_CAP[s.to]], 12, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
	p.add_child(pv)
	body.add_child(p)
	var fin := UI.vbox(2)
	for rank in order.size():
		var i: int = order[rank]
		fin.add_child(UI.label("%d. %s  %d点" % [rank + 1, teams[i].name, table[i].pts], 12,
			UI.CYAN if i == 0 else UI.SUB))
	body.add_child(fin)
	add_child(UI.scroll(body))
	var nx := UI.button("次のシーズンへ", "primary", 15, 44)
	nx.pressed.connect(func(): Nav.close(self))
	add_child(nx)
