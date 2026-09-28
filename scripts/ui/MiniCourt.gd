extends Control
## 試合中のミニコート。結果は数値判定で決まっていて、ここはそれに合わせた演出。
## 左が自分（右のゴールへ攻める）、右が相手（左のゴールへ攻める）。
##
## ・陣形はボールの位置に合わせて全体で押し上げ／下がる。持っている側は少し前に出る
## ・ボール保持者はドリブルで前進し、前向きのパスを出す。ときどき奪われる
## ・ゴールの少し前から、得点する側がボールを持って前に運び、得点者がシュートする
## ・ゴールにならないシュートはGKがキャッチ。スキル（奪取・チャンス・取り消し）も反映

const UI = preload("res://scripts/ui/UI.gd")
const Sprites = preload("res://scripts/ui/Sprites.gd")
## 自分側（右に攻める）から見た基本の位置。相手は左右反転
const ROW_X := {"GK": 0.05, "守": 0.24, "中": 0.42, "攻": 0.58}
const TEAM_COL := [Color("22d3ff"), Color("ff3d8b")]
const LEAD := 7.0          # ゴールの何分前から攻撃を組み立てるか
const PASS_SPEED := 0.9    # コート幅/秒
const SHOT_SPEED := 1.8
const DRIBBLE := 0.1

var players := [[], []]    # {tex, row, home: Vector2, pos: Vector2}（すべて 0〜1 の座標）
var ball := Vector2(0.5, 0.5)
var holder := Vector2i(-1, -1)
var flight := {}           # 飛んでいるボール {kind: pass/shot/goal/save, to: Vector2i, target: Vector2}
var carry := 0.0           # 保持者がドリブルで進んだ量
var next_action := 0.6
var plan := []             # これから起きるゴール／取り消し [{min, team（攻める側）, kind, scorer}]
var scene := {}            # 進行中の「ゴールまでの組み立て」
var flash := 0.0
var flash_team := 0
var flash_text := ""
var t := 0.0
var far_shots := 0         # 自陣から打ったシュートの数（テスト用）


func setup(mine: Array, opp: Array) -> void:
	custom_minimum_size.y = 150
	for side in 2:
		var team: Array = [mine, opp][side]
		var count := {}
		for p in team:
			count[p.row] = count.get(p.row, 0) + 1
		var seen := {}
		for p in team:
			var i: int = seen.get(p.row, 0)
			seen[p.row] = i + 1
			var x: float = ROW_X[p.row]
			# 相手は縦位置を少しずらして、センター付近で重ならないようにする
			var y: float = (i + 1.0) / (count[p.row] + 1.0) + (0.0 if side == 0 or p.row == "GK" else 0.08)
			var home := Vector2(x if side == 0 else 1.0 - x, clampf(y, 0.1, 0.9))
			players[side].append({"tex": Sprites.get_tex(Game.chars[p.id]), "row": p.row, "home": home, "pos": home})
	_kickoff(randi() % 2)


## 試合のイベントから、ゴールと取り消しの予定を作る
func set_plan(events: Array) -> void:
	for e in events:
		match e.get("kind", ""):
			"goal":
				plan.append({"min": e.min, "team": e.team, "kind": "goal", "scorer": e.get("scorer", -1)})
			"cancel":
				plan.append({"min": e.min, "team": 1 - e.team, "kind": "save", "scorer": -1})


## 毎フレーム、試合の時刻を受け取る
func tick(minute: float) -> void:
	if scene.is_empty() and not plan.is_empty() and minute >= plan[0].min - LEAD:
		scene = plan.pop_front()
		if holder.x != scene.team and flight.is_empty():
			_give(scene.team, _nearest(scene.team, ball, true))


## ゴール（得点する側）。組み立てが間に合っていなければその場でシュートする
func goal(team: int) -> void:
	_shoot(team, "goal")


## 失点取り消し（守る側）
func save_shot(defending: int) -> void:
	_shoot(1 - defending, "save")


func steal(team: int) -> void:
	if holder.x != team and flight.is_empty() and (scene.is_empty() or scene.team == team):
		_give(team, _nearest(team, ball, true))


func _shoot(team: int, kind: String) -> void:
	var shooter := -1
	if not scene.is_empty() and scene.team == team and scene.scorer >= 0 and scene.scorer < players[team].size():
		shooter = scene.scorer
	elif holder.x == team:
		shooter = holder.y
	else:
		shooter = _front_player(team)
	scene = {}
	holder = Vector2i(-1, -1)
	var sp: Vector2 = players[team][shooter].pos
	if (sp.x - 0.5) * _dir(team) < 0.1:
		# ゴール前まで来ていなければ、先にスルーパスを出してから打つ
		var box := Vector2(0.78 if team == 0 else 0.22, 0.5 + randf_range(-0.12, 0.12))
		flight = {"kind": "through", "team": team, "shooter": shooter, "then": kind, "target": box}
		return
	_shot_from(team, shooter, kind)


func _shot_from(team: int, shooter: int, kind: String) -> void:
	var sp: Vector2 = players[team][shooter].pos
	if (sp.x - 0.5) * _dir(team) < 0.0:
		far_shots += 1
	ball = sp + Vector2(0.02 * _dir(team), 0)
	var gy := 0.5 + randf_range(-0.06, 0.06)
	flight = {"kind": kind, "team": team, "target": Vector2(1.0 if team == 0 else 0.0, gy)}


func _dir(side: int) -> float:
	return 1.0 if side == 0 else -1.0


func _kickoff(team: int) -> void:
	ball = Vector2(0.5, 0.5)
	flight = {}
	carry = 0.0
	var mids := []
	for i in players[team].size():
		if players[team][i].row == "中":
			mids.append(i)
	holder = Vector2i(team, mids.pick_random() if not mids.is_empty() else _front_player(team))
	next_action = 0.5


func _front_player(side: int) -> int:
	var best := 0
	for i in players[side].size():
		if players[side][i].home.x * _dir(side) > players[side][best].home.x * _dir(side):
			best = i
	return best


func _nearest(side: int, p: Vector2, no_gk := false) -> int:
	var best := 0
	var bd := INF
	for i in players[side].size():
		if no_gk and players[side][i].row == "GK":
			continue
		var d: float = players[side][i].pos.distance_to(p)
		if d < bd:
			bd = d
			best = i
	return best


func _give(side: int, i: int) -> void:
	holder = Vector2i(side, i)
	flight = {}
	carry = 0.0
	next_action = randf_range(0.35, 0.7)


func _process(delta: float) -> void:
	t += delta
	if players[0].is_empty():
		return
	_move_players(delta)
	_move_ball(delta)
	flash = maxf(flash - delta, 0.0)
	queue_redraw()


func _move_players(delta: float) -> void:
	var attack := holder.x
	if attack < 0 and not flight.is_empty():
		attack = flight.get("team", flight.get("to", Vector2i(-1, -1)).x)
	# 陣形全体がボールに合わせて前後する
	var shift := clampf((ball.x - 0.5) * 0.55, -0.2, 0.2)
	for side in 2:
		var push := 0.06 * _dir(side) if attack == side else -0.03 * _dir(side)
		var presser := -1
		if attack == 1 - side:
			presser = _nearest(side, ball, true)
		for i in players[side].size():
			var p: Dictionary = players[side][i]
			var s := shift * (0.15 if p.row == "GK" else 1.0)
			var target := Vector2(p.home.x + s + (0.0 if p.row == "GK" else push), lerpf(p.home.y, ball.y, 0.15))
			target += Vector2(sin(t * 1.3 + i * 1.7), cos(t * 1.1 + i * 2.3)) * 0.012
			if p.row == "GK":
				target.y = lerpf(0.5, ball.y, 0.5)
			var scorer: bool = not scene.is_empty() and scene.team == side and scene.scorer == i
			if flight.get("kind", "") == "through" and flight.team == side and flight.shooter == i:
				# スルーパスに走り込む
				target = flight.target
				p.pos = p.pos.lerp(target, clampf(delta * 6.0, 0, 1))
				continue
			if holder == Vector2i(side, i):
				target = Vector2(p.home.x + s + push + carry, lerpf(p.home.y, 0.5, 0.3))
			elif scorer or (not scene.is_empty() and scene.team == side and p.row == "攻"):
				# 組み立て中は、得点する選手（とフォワード）がゴール前へ走り込む
				target = Vector2(0.8 if side == 0 else 0.2, lerpf(p.home.y, 0.5, 0.5 if scorer else 0.2))
			elif i == presser:
				target = target.lerp(ball, 0.75)
			elif flight.get("to", Vector2i(-1, -1)) == Vector2i(side, i):
				target = target.lerp(flight.target, 0.5)
			target.x = clampf(target.x, 0.03, 0.97)
			target.y = clampf(target.y, 0.08, 0.92)
			p.pos = p.pos.lerp(target, clampf(delta * 3.5, 0, 1))


func _move_ball(delta: float) -> void:
	if not flight.is_empty():
		var sp := SHOT_SPEED if flight.kind in ["goal", "save", "shot", "through"] else PASS_SPEED
		if flight.kind == "pass":
			var to: Vector2i = flight.to
			flight.target = players[to.x][to.y].pos
		ball = ball.move_toward(flight.target, delta * sp)
		if ball.distance_to(flight.target) < 0.01:
			_arrive()
		return
	if holder.x < 0:
		return
	var side := holder.x
	var hp: Vector2 = players[side][holder.y].pos
	ball = ball.lerp(hp + Vector2(0.018 * _dir(side), 0.03), clampf(delta * 10.0, 0, 1))
	# ドリブルで前進（相手ゴール前で止まる）
	var gx := 0.84 if side == 0 else 0.16
	if (hp.x - gx) * _dir(side) < 0.0:
		var sp := DRIBBLE * (2.2 if not scene.is_empty() and scene.team == side else 1.0)
		carry += sp * delta * _dir(side)
	next_action -= delta
	if next_action <= 0.0:
		_decide()


## 保持者の次の行動：パス、ボールを失う、シュート（ゴールにはならない）
func _decide() -> void:
	var side := holder.x
	var hp: Vector2 = players[side][holder.y].pos
	var in_box := (hp.x > 0.76) if side == 0 else (hp.x < 0.24)
	var scripted: bool = not scene.is_empty()
	if scripted and scene.team == side:
		# 組み立て中：前の選手へつないで、ゴール前で待つ
		if in_box:
			next_action = 0.3
			return
		_pass(side, true)
		return
	if scripted and scene.team != side:
		_lose(side)
		return
	if in_box and randf() < 0.35:
		flight = {"kind": "shot", "team": side, "target": Vector2(1.0 if side == 0 else 0.0, 0.5 + randf_range(-0.08, 0.08))}
		holder = Vector2i(-1, -1)
		return
	if randf() < 0.22:
		_lose(side)
		return
	_pass(side, false)


func _lose(side: int) -> void:
	_give(1 - side, _nearest(1 - side, ball, true))


func _pass(side: int, forward_only: bool) -> void:
	var cur: Dictionary = players[side][holder.y]
	var options := []
	for i in players[side].size():
		if i == holder.y or players[side][i].row == "GK":
			continue
		var fwd: float = (players[side][i].pos.x - cur.pos.x) * _dir(side)
		if fwd > (0.02 if forward_only else -0.12):
			options.append(i)
	if options.is_empty():
		# 前に誰もいなければ、自分でさらに運ぶ
		next_action = 0.4
		return
	var to: int = options.pick_random()
	if not scene.is_empty() and scene.team == side and scene.scorer >= 0 and scene.scorer in options:
		to = scene.scorer if randf() < 0.6 else to
	flight = {"kind": "pass", "to": Vector2i(side, to), "target": players[side][to].pos}
	holder = Vector2i(-1, -1)


func _arrive() -> void:
	match flight.kind:
		"through":
			var f := flight
			_shot_from(f.team, f.shooter, f.then)
			players[f.team][f.shooter].pos = ball - Vector2(0.02 * _dir(f.team), 0)
		"pass":
			var to: Vector2i = flight.to
			_give(to.x, to.y)
		"goal":
			flash = 1.3
			flash_team = flight.team
			flash_text = "GOAL!"
			var conceded: int = 1 - flight.team
			flight = {}
			_kickoff(conceded)
		"save", "shot":
			var def: int = 1 - flight.team
			if flight.kind == "save":
				flash = 0.9
				flash_team = def
				flash_text = "SAVE!"
			var gk := 0
			for i in players[def].size():
				if players[def][i].row == "GK":
					gk = i
			_give(def, gk)
			next_action = 0.7


func _px(p: Vector2) -> Vector2:
	var f := _field()
	return f.position + p * f.size


func _field() -> Rect2:
	return Rect2(Vector2(8, 6), size - Vector2(16, 12))


func _draw() -> void:
	var f := _field()
	draw_rect(Rect2(Vector2.ZERO, size), Color("0f2a22"))
	for i in 8:
		if i % 2 == 0:
			draw_rect(Rect2(f.position.x + f.size.x * i / 8.0, f.position.y, f.size.x / 8.0, f.size.y), Color(1, 1, 1, 0.025))
	var line := Color(1, 1, 1, 0.22)
	draw_rect(f, line, false, 1.0)
	draw_line(Vector2(f.get_center().x, f.position.y), Vector2(f.get_center().x, f.end.y), line)
	draw_arc(f.get_center(), f.size.y * 0.18, 0, TAU, 32, line)
	for side in 2:
		var bx := f.position.x if side == 0 else f.end.x - f.size.x * 0.13
		draw_rect(Rect2(bx, f.position.y + f.size.y * 0.25, f.size.x * 0.13, f.size.y * 0.5), line, false, 1.0)
		var gx := f.position.x - 5 if side == 0 else f.end.x
		draw_rect(Rect2(gx, f.get_center().y - 14, 5, 28), Color(1, 1, 1, 0.55))
	# 選手（ボール保持者は少し大きく）
	for side in 2:
		for i in players[side].size():
			var p: Dictionary = players[side][i]
			var c := _px(p.pos)
			var r := 11.0 if holder == Vector2i(side, i) else 9.5
			draw_circle(c + Vector2(0, 7), 7, Color(0, 0, 0, 0.3))
			draw_circle(c, r, Color(TEAM_COL[side], 0.35))
			draw_arc(c, r, 0, TAU, 20, TEAM_COL[side], 1.5)
			draw_texture_rect(p.tex, Rect2(c - Vector2(9, 9), Vector2(18, 18)), false)
	# ボール
	var b := _px(ball)
	draw_circle(b + Vector2(1, 2), 3.2, Color(0, 0, 0, 0.4))
	draw_circle(b, 3.2, Color.WHITE)
	if flash > 0.0:
		var a := clampf(flash, 0, 1)
		draw_rect(Rect2(Vector2.ZERO, size), Color(TEAM_COL[flash_team], 0.16 * a))
		var font: Font = UI.heavy_font if UI.heavy_font else get_theme_default_font()
		var fs := 34
		var w := font.get_string_size(flash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - w) / 2, size.y / 2 + 12), flash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(TEAM_COL[flash_team], a))
