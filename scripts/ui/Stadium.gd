extends Control
## 試合画面の NEXT MATCH の対戦カード。
## 上段：両チームの名前・エンブレム・順位と戦績、真ん中に VS（スタジアム風の背景）
## 下段：芝のコートに両チームを陣形どおりに並べる（自分は左から GK→DF→MF→FW、相手は右から）
## 選手をタップ → on_player_tap(id, side)、エンブレムをタップ → on_crest_tap(side)（side 0=自分 1=相手）

const UI = preload("res://scripts/ui/UI.gd")
const Sprites = preload("res://scripts/ui/Sprites.gd")
const COL_X := {"GK": 0.05, "守": 0.17, "中": 0.3, "攻": 0.43}   # 自分側。相手は左右反転
const TOP_H := 104.0

var names := ["", ""]
var ranks := ["", ""]      # 例 "3位"
var records := ["", ""]    # 例 "2勝1分0敗"
var teams := [[], []]      # [{id, row}]
var on_player_tap := Callable()
var on_crest_tap := Callable()
var _hits := []            # [Rect2, 種類, 値]
var _crowd := []


func _ready() -> void:
	custom_minimum_size.y = 250
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for i in 90:
		_crowd.append([r.randf(), r.randf(), r.randf()])
	UI.on_tap(self, _tap_at)


func _tap_at() -> void:
	var p := get_local_mouse_position()
	for it in _hits:
		if it[0].has_point(p):
			if it[1] == "crest" and on_crest_tap.is_valid():
				on_crest_tap.call(it[2])
			elif it[1] == "player" and on_player_tap.is_valid():
				on_player_tap.call(it[2][0], it[2][1])
			return


func _draw() -> void:
	_hits.clear()
	var w := size.x
	var h := size.y
	var f: Font = UI.heavy_font if UI.heavy_font else get_theme_default_font()
	# 上段：夜空・照明・観客席
	var top := Color("0b1330")
	var mid := Color("15305a")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, TOP_H), Vector2(0, TOP_H)]),
		PackedColorArray([top, top, mid, mid]))
	for c in _crowd:
		draw_circle(Vector2(c[0] * w, TOP_H * (0.55 + c[1] * 0.42)), 1.1, Color(1, 1, 1, 0.06 + c[2] * 0.14))
	var lp := Vector2(w / 2, 8)
	for k in 4:
		draw_circle(lp, 16 - k * 4, Color(1, 1, 0.9, 0.04 + k * 0.04))
	# 両チームの名前・エンブレム・順位と戦績
	for side in 2:
		var cx := w * (0.2 if side == 0 else 0.8)
		_text(f, names[side], Vector2(cx, 15), 12, UI.INK)
		var cc := Vector2(cx, 50)
		_crest(cc, 24, side == 0)
		_hits.append([Rect2(cc - Vector2(30, 30), Vector2(60, 60)), "crest", side])
		_rank_line(f, Vector2(cx, 94), ranks[side], records[side])
	_text(f, "VS", Vector2(w / 2, 62), 30, UI.INK)
	_text(f, "エンブレムで編成", Vector2(w / 2, 92), 9, Color(UI.SUB, 0.8))

	# 下段：芝のコート
	var fr := Rect2(0, TOP_H, w, h - TOP_H)
	for b in 8:
		draw_rect(Rect2(fr.position.x + fr.size.x * b / 8.0, fr.position.y, fr.size.x / 8.0, fr.size.y),
			Color("2f8d3b") if b % 2 == 0 else Color("2a7f35"))
	var line := Color(1, 1, 1, 0.4)
	draw_rect(fr.grow(-3), line, false, 1.5)
	draw_line(Vector2(w / 2, fr.position.y + 3), Vector2(w / 2, fr.end.y - 3), line, 1.5)
	draw_arc(fr.get_center(), fr.size.y * 0.18, 0, TAU, 32, line, 1.5, true)
	for side in 2:
		var bx := fr.position.x + 3 if side == 0 else fr.end.x - 3 - w * 0.1
		draw_rect(Rect2(bx, fr.position.y + fr.size.y * 0.25, w * 0.1, fr.size.y * 0.5), line, false, 1.5)
	# 選手
	for side in 2:
		var team: Array = teams[side]
		for row in COL_X:
			var list := team.filter(func(m): return m.row == row)
			var n := list.size()
			for i in n:
				var x: float = COL_X[row] if side == 0 else 1.0 - COL_X[row]
				var y := fr.position.y + fr.size.y * (i + 1.0) / (n + 1.0) - 4
				_player(f, Vector2(x * w, y), list[i], side)


func _player(f: Font, p: Vector2, m: Dictionary, side: int) -> void:
	var c: Dictionary = Game.chars[m.id]
	var pc: Color = UI.ROW_COLORS[m.row]
	var tc: Color = UI.CYAN if side == 0 else UI.PINK
	# 台座：ポジションの色、縁はチームの色
	_ellipse(p + Vector2(0, 12), Vector2(15, 5), Color(pc, 0.55))
	_ellipse_line(p + Vector2(0, 12), Vector2(15, 5), tc, 1.2)
	var r := Rect2(p - Vector2(14, 16), Vector2(28, 28))
	draw_texture_rect(Sprites.get_tex(c), r, false)
	# ポジション名
	var lab: String = UI.POS_LABEL[m.row]
	var lw := f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_rect(Rect2(p.x - lw / 2 - 3, p.y + 17, lw + 6, 10), Color(pc, 0.9))
	draw_string(f, Vector2(p.x - lw / 2, p.y + 25), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI.BG)
	if side == 1 and not Game.owned(m.id):
		draw_circle(r.position + Vector2(26, 3), 3.5, UI.PINK)
	_hits.append([r.grow(4), "player", [m.id, side]])


func _text(f: Font, t: String, c: Vector2, fs: int, col: Color) -> void:
	var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(f, Vector2(c.x - tw / 2, c.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
	draw_string(f, Vector2(c.x - tw / 2, c.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## 「3位  2勝1分0敗」を中央ぞろえで
func _rank_line(f: Font, c: Vector2, rank: String, rec: String) -> void:
	var w1 := f.get_string_size(rank, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var w2 := f.get_string_size(rec, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var x := c.x - (w1 + 5 + w2) / 2
	draw_string_outline(f, Vector2(x, c.y), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.6))
	draw_string(f, Vector2(x, c.y), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.GOLD if rank == "1位" else UI.INK)
	draw_string(f, Vector2(x + w1 + 5, c.y), rec, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.SUB)


## エンブレム。自分は青い盾にボールと月桂樹、相手は暗い盾に一番レアな選手
func _crest(c: Vector2, r: float, is_mine: bool) -> void:
	var shape := PackedVector2Array()
	for p in [[-0.85, -0.9], [0.0, -1.05], [0.85, -0.9], [0.85, -0.1], [0.6, 0.5], [0.0, 1.0], [-0.6, 0.5], [-0.85, -0.1]]:
		shape.append(c + Vector2(p[0], p[1]) * r)
	if is_mine:
		for side in [-1, 1]:
			for k in 7:
				var a := lerpf(PI * 0.55, PI * 1.3, k / 6.0)
				var p := c + Vector2(cos(a) * r * 1.22, sin(a) * r * 1.1 + r * 0.1)
				var rot := a + PI / 2
				if side == 1:
					p.x = c.x - (p.x - c.x)
					rot = PI - rot
				_leaf(p, Vector2(5.5, 2.4), rot, UI.GOLD)
		draw_colored_polygon(shape, Color("1f5fd0"))
		var inner := PackedVector2Array()
		for p in shape:
			inner.append(c + (p - c) * 0.8)
		draw_colored_polygon(inner, Color("3d8bff"))
		draw_polyline(shape + PackedVector2Array([shape[0]]), Color(UI.INK, 0.9), 2.0, true)
		var bc := c + Vector2(0, 2)
		draw_circle(bc, r * 0.45, Color.WHITE)
		var pent := PackedVector2Array()
		for k in 5:
			var a := -PI / 2 + TAU * k / 5.0
			pent.append(bc + Vector2(cos(a), sin(a)) * r * 0.16)
		draw_colored_polygon(pent, Color("1c1426"))
		for k in 5:
			var a := -PI / 2 + TAU * k / 5.0
			draw_line(bc + Vector2(cos(a), sin(a)) * r * 0.16, bc + Vector2(cos(a), sin(a)) * r * 0.43, Color("1c1426"), 1.5, true)
	else:
		draw_colored_polygon(shape, Color("1b2338"))
		var inner := PackedVector2Array()
		for p in shape:
			inner.append(c + (p - c) * 0.84)
		draw_colored_polygon(inner, Color("27304d"))
		draw_polyline(shape + PackedVector2Array([shape[0]]), Color(UI.PINK, 0.8), 2.0, true)
		var best: Dictionary = {}
		for m in teams[1]:
			if best.is_empty() or Game.chars[m.id].rarity > Game.chars[best.id].rarity:
				best = m
		if not best.is_empty():
			draw_texture_rect(Sprites.get_tex(Game.chars[best.id]), Rect2(c - Vector2(r * 0.62, r * 0.66), Vector2(r * 1.24, r * 1.24)), false)


func _leaf(c: Vector2, r: Vector2, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 12:
		var a := TAU * k / 12.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	draw_colored_polygon(pts, col)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _ellipse_line(c: Vector2, r: Vector2, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for k in 25:
		var a := TAU * k / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_polyline(pts, col, w, true)
