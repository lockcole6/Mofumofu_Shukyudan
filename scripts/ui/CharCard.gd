extends MarginContainer
## キャラのカード。ポジションの色で縁取りと下からのグラデーションを描き、
## 左上にポジション（攻・中・守・GK）のバッジを出す。レア度は★の数で見せる。
## 編成ではドラッグで移動できる（draggable / on_drop を設定したとき）。

const UI = preload("res://scripts/ui/UI.gd")

var cid := 0
var silhouette := false
var rcol := Color.GRAY
var selected := false
var dim := false
var badge := ""             # 右上に出す小さなラベル（NEW など）
var pos := ""
var rarity := 0
var _t := randf() * 10.0
var draggable := false
var on_drop := Callable()   # (ドラッグしてきた選手id, このカードの選手id)


func setup(id: int, sil := false, lines := [], icon_size := 44) -> void:
	cid = id
	silhouette = sil
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 4)
	var v := UI.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	if id == 0:
		rcol = UI.LINE
		v.add_child(UI.label("+", 22, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		var c: Dictionary = Game.chars[id]
		pos = c.pos if not sil else ""
		rarity = c.rarity if not sil else 0
		rcol = UI.ROW_COLORS[c.pos] if not sil else UI.DIM
		var ic := UI.icon(c, sil, icon_size)
		ic.size_flags_horizontal = SIZE_SHRINK_CENTER
		v.add_child(ic)
	for l in lines:
		if l is Control:
			l.size_flags_horizontal = SIZE_SHRINK_CENTER
			v.add_child(l)
		else:
			var lb := UI.label(str(l), 10, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
			lb.clip_text = true
			lb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			lb.custom_minimum_size.x = 20
			v.add_child(lb)
	add_child(v)
	UI.ignore_mouse(v)
	mouse_filter = MOUSE_FILTER_PASS


func _process(delta: float) -> void:
	if rarity >= 3 and is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sb := UI.sbox(UI.PANEL2, 4, Color(rcol, 0.55 if cid else 0.35), 1, 0)
	if selected:
		sb.border_color = UI.CYAN
		sb.set_border_width_all(2)
	draw_style_box(sb, r)
	if cid:
		var top := size.y * 0.35
		var a := Color(rcol, 0.0)
		var b := Color(rcol, 0.3)
		draw_polygon(PackedVector2Array([Vector2(1, top), Vector2(size.x - 1, top), Vector2(size.x - 1, size.y - 1), Vector2(1, size.y - 1)]),
			PackedColorArray([a, a, b, b]))
		if pos != "":
			var f: Font = UI.heavy_font if UI.heavy_font else get_theme_default_font()
			var w := 18.0 if pos == "GK" else 13.0
			draw_colored_polygon(PackedVector2Array([Vector2(1, 1), Vector2(w + 5, 1), Vector2(w, 13), Vector2(1, 13)]), rcol)
			draw_string(f, Vector2(3, 11), pos, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.BG)
	# ★3は金の枠、★4は虹色の枠。どちらもときどき光が走る
	if rarity >= 3:
		var fc := UI.GOLD_FRAME if rarity == 3 else Color.from_hsv(fposmod(_t * 0.25, 1.0), 0.55, 1.0)
		var fb := UI.sbox(Color(0, 0, 0, 0), 4, fc, 2, 0)
		draw_style_box(fb, r)
		var ph := fposmod(_t, 3.2) / 1.2   # 0〜1 の間だけ光が横切る
		if ph < 1.0:
			var x := -30.0 + ph * (size.x + 60.0)
			var shine := Color(1, 1, 1, 0.22 if rarity == 4 else 0.16)
			var pts := PackedVector2Array()
			for p in [Vector2(x, 2), Vector2(x + 14, 2), Vector2(x - 6, size.y - 2), Vector2(x - 20, size.y - 2)]:
				pts.append(Vector2(clampf(p.x, 2, size.x - 2), p.y))
			if pts[1].x - pts[0].x > 0.5 or pts[2].x - pts[3].x > 0.5:
				draw_colored_polygon(pts, shine)
	if badge != "":
		var f2: Font = UI.heavy_font if UI.heavy_font else get_theme_default_font()
		var tw := f2.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8
		draw_colored_polygon(PackedVector2Array([Vector2(size.x - tw - 3, 1), Vector2(size.x - 1, 1), Vector2(size.x - 1, 12), Vector2(size.x - tw - 6, 12)]), UI.PINK)
		draw_string(f2, Vector2(size.x - tw + 1, 10), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
	if dim:
		draw_rect(r, Color(0, 0, 0, 0.55))


func _get_drag_data(_at: Vector2) -> Variant:
	if not draggable or cid == 0:
		return null
	var p := UI.icon(Game.chars[cid], false, 56)
	p.modulate.a = 0.85
	var holder := Control.new()
	holder.add_child(p)
	p.position = Vector2(-28, -28)
	set_drag_preview(holder)
	return {"id": cid}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return on_drop.is_valid() and data is Dictionary and data.has("id") and int(data.id) != cid


func _drop_data(_at: Vector2, data: Variant) -> void:
	on_drop.call(int(data.id), cid)
