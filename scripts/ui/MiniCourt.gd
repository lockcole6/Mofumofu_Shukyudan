extends Control
## 試合中のミニコート。両チームの選手がフォーメーションどおりに並び、ボールを回し合う。
## 実際の結果は数値判定で決まっていて、ここは雰囲気の演出。goal() でゴールシーンを見せる。
## 左が自分（右のゴールへ攻める）、右が相手。

const UI = preload("res://scripts/ui/UI.gd")
const Sprites = preload("res://scripts/ui/Sprites.gd")
const ROW_X := {"GK": 0.05, "守": 0.2, "中": 0.33, "攻": 0.44}
const TEAM_COL := [Color("22d3ff"), Color("ff3d8b")]

var players := [[], []]   # {tex, home: Vector2(0-1), pos: Vector2(px)}
var ball := Vector2.ZERO
var holder := Vector2i(-1, -1)   # (チーム, 番号)
var next_pass := 0.8
var shot_team := -1              # ゴールに向かって飛んでいるチーム
var flash := 0.0
var flash_team := 0
var t := 0.0
var _placed := false


func setup(mine: Array, opp: Array) -> void:
	custom_minimum_size.y = 150
	for side in 2:
		var team: Array = [mine, opp][side]
		var by_row := {}
		for p in team:
			by_row[p.row] = by_row.get(p.row, []) + [p]
		for row in by_row:
			var list: Array = by_row[row]
			for i in list.size():
				var x: float = ROW_X[row]
				var home := Vector2(x if side == 0 else 1.0 - x, (i + 1.0) / (list.size() + 1.0))
				players[side].append({"tex": Sprites.get_tex(Game.chars[list[i].id]), "home": home, "pos": Vector2.ZERO})
	_kickoff(randi() % 2)


func _field() -> Rect2:
	return Rect2(Vector2(6, 6), size - Vector2(12, 12))


func _to_px(p: Vector2) -> Vector2:
	var f := _field()
	return f.position + p * f.size


func _kickoff(team: int) -> void:
	ball = _to_px(Vector2(0.5, 0.5))
	var mids: Array = players[team].filter(func(p): return p.home.x > 0.25 and p.home.x < 0.75)
	var idx: int = players[team].find(mids[0]) if not mids.is_empty() else players[team].size() - 1
	holder = Vector2i(team, idx)
	next_pass = 0.6
	for side in 2:
		for p in players[side]:
			if p.pos == Vector2.ZERO:
				p.pos = _to_px(p.home)


## ゴールシーン：team 側がシュートを決める
func goal(team: int) -> void:
	shot_team = team
	holder = Vector2i(-1, -1)


func _process(delta: float) -> void:
	t += delta
	if size.x < 10 or players[0].is_empty():
		return
	if not _placed:
		_placed = true
		for side in 2:
			for p in players[side]:
				p.pos = _to_px(p.home)
		ball = _to_px(Vector2(0.5, 0.5))
	var attack := holder.x if holder.x >= 0 else shot_team
	# 選手の動き：ボールを持っている側は前へ、守る側は下がる。一番近い守備者はボールに寄る
	for side in 2:
		var dir := 1.0 if side == 0 else -1.0
		var push := 0.07 * dir if attack == side else -0.04 * dir
		var closest := -1
		var best := INF
		if attack != side:
			for i in players[side].size():
				var d: float = players[side][i].pos.distance_to(ball)
				if d < best and players[side][i].home.x != (0.05 if side == 0 else 0.95):
					best = d
					closest = i
		for i in players[side].size():
			var p: Dictionary = players[side][i]
			var wob := Vector2(sin(t * 1.3 + i * 1.7), cos(t * 1.1 + i * 2.3)) * 0.02
			var target := _to_px(p.home + Vector2(push, 0) + wob)
			if i == closest:
				target = target.lerp(ball, 0.6)
			if holder == Vector2i(side, i):
				target = _to_px(p.home + Vector2(push * 1.6, 0) + wob)
			p.pos = p.pos.lerp(target, clampf(delta * 3.0, 0, 1))

	# ボール
	if shot_team >= 0:
		var goal_pos := _to_px(Vector2(1.0 if shot_team == 0 else 0.0, 0.5))
		ball = ball.move_toward(goal_pos, delta * 420.0)
		if ball.distance_to(goal_pos) < 2.0:
			flash = 1.2
			flash_team = shot_team
			var conceded := 1 - shot_team
			shot_team = -1
			_kickoff(conceded)
	elif holder.x >= 0:
		var hp: Vector2 = players[holder.x][holder.y].pos
		ball = ball.move_toward(hp + Vector2(6 if holder.x == 0 else -6, 6), delta * 260.0)
		next_pass -= delta
		if next_pass <= 0.0:
			next_pass = randf_range(0.5, 1.1)
			_pass()
	flash = maxf(flash - delta, 0.0)
	queue_redraw()


## 前にいる味方へパス。ときどき相手に奪われる
func _pass() -> void:
	var side := holder.x
	if randf() < 0.28:
		side = 1 - side
		var best := 0
		var bd := INF
		for i in players[side].size():
			var d: float = players[side][i].pos.distance_to(ball)
			if d < bd:
				bd = d
				best = i
		holder = Vector2i(side, best)
		return
	var dir := 1.0 if side == 0 else -1.0
	var options := []
	for i in players[side].size():
		if i == holder.y:
			continue
		var fwd: float = (players[side][i].home.x - players[side][holder.y].home.x) * dir
		if fwd > -0.15:
			options.append(i)
	if options.is_empty():
		options = range(players[side].size())
	holder = Vector2i(side, options.pick_random())


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
		var bx := f.position.x if side == 0 else f.end.x - f.size.x * 0.12
		draw_rect(Rect2(bx, f.position.y + f.size.y * 0.25, f.size.x * 0.12, f.size.y * 0.5), line, false, 1.0)
		var gx := f.position.x - 4 if side == 0 else f.end.x
		draw_rect(Rect2(gx, f.get_center().y - 14, 4, 28), Color(1, 1, 1, 0.5))
	# 選手
	for side in 2:
		for p in players[side]:
			draw_circle(p.pos + Vector2(0, 7), 7, Color(0, 0, 0, 0.3))
			draw_circle(p.pos, 10, Color(TEAM_COL[side], 0.35))
			draw_arc(p.pos, 10, 0, TAU, 20, TEAM_COL[side], 1.5)
			draw_texture_rect(p.tex, Rect2(p.pos - Vector2(9, 9), Vector2(18, 18)), false)
	# ボール
	draw_circle(ball + Vector2(1, 2), 3.2, Color(0, 0, 0, 0.4))
	draw_circle(ball, 3.2, Color.WHITE)
	if flash > 0.0:
		var a := clampf(flash, 0, 1)
		draw_rect(Rect2(Vector2.ZERO, size), Color(TEAM_COL[flash_team], 0.18 * a))
		var font: Font = UI.heavy_font if UI.heavy_font else get_theme_default_font()
		var txt := "GOAL!"
		var fs := 34
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - w) / 2, size.y / 2 + 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(TEAM_COL[flash_team], a))
