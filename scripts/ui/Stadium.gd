extends Control
## 試合画面の NEXT MATCH の対戦カード。スタジアム風の背景に、両チームの名前・エンブレム・VS・選手を描く。
## 相手の選手をタップすると on_opp_tap(選手id) を呼ぶ。

const UI = preload("res://scripts/ui/UI.gd")
const Sprites = preload("res://scripts/ui/Sprites.gd")

var my_name := ""
var opp_name := ""
var mine: Array = []       # 出場メンバー [{id, row}]
var opp: Array = []
var on_opp_tap := Callable()
var _opp_rects := []       # [Rect2, id]
var _crowd := []


func _ready() -> void:
	custom_minimum_size.y = 172
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for i in 90:
		_crowd.append([r.randf(), r.randf(), r.randf()])
	UI.on_tap(self, _tap_at)


func _tap_at() -> void:
	var p := get_local_mouse_position()
	for it in _opp_rects:
		if it[0].grow(3).has_point(p) and on_opp_tap.is_valid():
			on_opp_tap.call(it[1])
			return


func _draw() -> void:
	var w := size.x
	var h := size.y
	# 夜空とスタンド
	var top := Color("0b1330")
	var mid := Color("15305a")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.62), Vector2(0, h * 0.62)]),
		PackedColorArray([top, top, mid, mid]))
	draw_rect(Rect2(0, h * 0.36, w, h * 0.26), Color(0.02, 0.04, 0.1, 0.5))
	for c in _crowd:
		draw_circle(Vector2(c[0] * w, h * (0.38 + c[1] * 0.22)), 1.2, Color(1, 1, 1, 0.08 + c[2] * 0.18))
	# 照明
	for x in [0.08, 0.3, 0.7, 0.92]:
		var p := Vector2(x * w, h * 0.1)
		for k in 4:
			draw_circle(p, 18 - k * 4, Color(1, 1, 0.9, 0.05 + k * 0.05))
		draw_circle(p, 3, Color(1, 1, 0.95, 0.95))
	# 芝
	var f0 := h * 0.62
	for b in 4:
		var y0 := f0 + (h - f0) * b / 4.0
		var y1 := f0 + (h - f0) * (b + 1) / 4.0
		draw_rect(Rect2(0, y0, w, y1 - y0), Color("2f8d3b") if b % 2 == 0 else Color("2a7f35"))
	draw_line(Vector2(w / 2, f0), Vector2(w / 2, h), Color(1, 1, 1, 0.4), 1.5)
	draw_arc(Vector2(w / 2, h), (h - f0) * 0.8, PI, TAU, 24, Color(1, 1, 1, 0.4), 1.5, true)

	var f: Font = UI.heavy_font if UI.heavy_font else get_theme_default_font()
	# チーム名
	for side in 2:
		var nm: String = [my_name, opp_name][side]
		var cx := w * (0.25 if side == 0 else 0.75)
		var tw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string_outline(f, Vector2(cx - tw / 2, 18), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.6))
		draw_string(f, Vector2(cx - tw / 2, 18), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.INK)
	# エンブレム
	_crest(Vector2(w * 0.25, 58), 30, true)
	_crest(Vector2(w * 0.75, 58), 30, false)
	# VS
	var vs := "VS"
	var vw := f.get_string_size(vs, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string_outline(f, Vector2(w / 2 - vw / 2, 70), vs, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color(0, 0, 0, 0.6))
	draw_string(f, Vector2(w / 2 - vw / 2, 70), vs, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.INK)
	# 選手（4人と3人の2段）
	_opp_rects.clear()
	for side in 2:
		var team: Array = _ordered([mine, opp][side])
		var cx := w * (0.25 if side == 0 else 0.75)
		for i in team.size():
			var line := 0 if i < 4 else 1
			var n := mini(4, team.size()) if line == 0 else team.size() - 4
			var k := i if line == 0 else i - 4
			var x := cx + (k - (n - 1) / 2.0) * 34
			var y := h * 0.66 + line * 26
			var rect := Rect2(x - 15, y - 4, 30, 30)
			_ellipse(Vector2(x, y + 24), Vector2(12, 3.5), Color(0, 0, 0, 0.35))
			draw_texture_rect(Sprites.get_tex(Game.chars[team[i].id]), rect, false)
			if side == 1:
				_opp_rects.append([rect, team[i].id])
				if not Game.owned(team[i].id):
					draw_circle(rect.position + Vector2(27, 3), 3.5, UI.PINK)


func _ordered(team: Array) -> Array:
	var order := {"攻": 0, "中": 1, "守": 2, "GK": 3}
	var t := team.duplicate()
	t.sort_custom(func(a, b): return order[a.row] < order[b.row])
	return t


## エンブレム。自分は青い盾にボールと月桂樹、相手は暗い盾に一番レアな選手
func _crest(c: Vector2, r: float, is_mine: bool) -> void:
	var shape := PackedVector2Array()
	for p in [[-0.85, -0.9], [0.0, -1.05], [0.85, -0.9], [0.85, -0.1], [0.6, 0.5], [0.0, 1.0], [-0.6, 0.5], [-0.85, -0.1]]:
		shape.append(c + Vector2(p[0], p[1]) * r)
	if is_mine:
		# 月桂樹（盾の左右を下から上へ囲む葉）
		for side in [-1, 1]:
			for k in 7:
				var a := lerpf(PI * 0.55, PI * 1.3, k / 6.0)
				var p := c + Vector2(cos(a) * r * 1.22, sin(a) * r * 1.1 + r * 0.1)
				var rot := a + PI / 2
				if side == 1:
					p.x = c.x - (p.x - c.x)
					rot = PI - rot
				_leaf(p, Vector2(6, 2.6), rot, UI.GOLD)
		draw_colored_polygon(shape, Color("1f5fd0"))
		var inner := PackedVector2Array()
		for p in shape:
			inner.append(c + (p - c) * 0.8)
		draw_colored_polygon(inner, Color("3d8bff"))
		draw_polyline(shape + PackedVector2Array([shape[0]]), Color(UI.INK, 0.9), 2.0, true)
		# ボール
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
		draw_polyline(shape + PackedVector2Array([shape[0]]), Color(UI.SUB, 0.9), 2.0, true)
		var best: Dictionary = {}
		for m in opp:
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
