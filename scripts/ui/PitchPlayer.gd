extends Control
## ピッチ上の選手。台座・ドット絵・ポジションのバッジ・★・スキルLvを描く。

const UI = preload("res://scripts/ui/UI.gd")
const Sprites = preload("res://scripts/ui/Sprites.gd")

var cid := 0
var row := ""
var selected := false
var lifted := false
var _t := 0.0


func setup(id: int, r: String) -> void:
	cid = id
	row = r
	custom_minimum_size = Vector2(80, 88)
	size = custom_minimum_size
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = MOUSE_FILTER_PASS


func _process(delta: float) -> void:
	if selected:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var c: Dictionary = Game.chars[cid]
	var pc: Color = UI.ROW_COLORS[c.pos]
	var cx := size.x / 2
	var a := 0.35 if lifted else 1.0
	# 台座
	var base := Vector2(cx, 62)
	_ellipse(base, Vector2(32, 10), Color(0.04, 0.07, 0.16, 0.75 * a))
	_ellipse_line(base, Vector2(32, 10), Color(pc, 0.45 * a), 1.5)
	# 選択中は光る輪
	if selected:
		var glow := 0.55 + 0.25 * sin(_t * 4.0)
		draw_arc(Vector2(cx, 36), 34, 0, TAU, 48, Color(UI.CYAN, 0.25 * glow), 8.0, true)
		draw_arc(Vector2(cx, 36), 34, 0, TAU, 48, Color(UI.CYAN, glow), 2.5, true)
	# ドット絵
	draw_texture_rect(Sprites.get_tex(c), Rect2(cx - 28, 6, 56, 56), false, Color(1, 1, 1, a))
	var f: Font = UI.heavy_font if UI.heavy_font else get_theme_default_font()
	# ポジションのバッジ（左上）
	var lab: String = UI.POS_LABEL[c.pos]
	var bw := 26.0
	draw_colored_polygon(PackedVector2Array([Vector2(6, 2), Vector2(6 + bw + 4, 2), Vector2(6 + bw, 16), Vector2(2, 16)]), Color(pc, a))
	draw_string(f, Vector2(7, 13.5), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(UI.BG, a))
	# ★
	var stars := UI.stars(c.rarity)
	var sw := f.get_string_size(stars, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string_outline(f, Vector2(cx - sw / 2, 80), stars, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.1, 0.06, 0, 0.8 * a))
	draw_string(f, Vector2(cx - sw / 2, 80), stars, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UI.GOLD, a))
	# スキルLv（右下）
	var lc := Vector2(size.x - 13, 64)
	draw_circle(lc, 11, Color(0.05, 0.08, 0.18, a))
	draw_arc(lc, 11, 0, TAU, 24, Color(UI.CYAN, 0.8 * a), 1.5, true)
	var lv := "Lv%d" % Game.slv(cid)
	var lw := f.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_string(f, lc + Vector2(-lw / 2, 3), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(UI.INK, a))
	# 得意でない列にいるときは赤い印
	if row != "" and c.pos != row:
		draw_string_outline(f, Vector2(cx - 18, 88), "得意:" + lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0, 0, 0, 0.7))
		draw_string(f, Vector2(cx - 18, 88), "得意:" + lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI.RED)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _ellipse_line(c: Vector2, r: Vector2, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for k in 33:
		var a := TAU * k / 32.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_polyline(pts, col, w, true)
