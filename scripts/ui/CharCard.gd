extends MarginContainer
## キャラのカード。レア度の色で下から光るグラデーションを描く。
## 編成ではドラッグで移動できる（draggable / on_drop を設定したとき）。

const UI = preload("res://scripts/ui/UI.gd")

var cid := 0
var silhouette := false
var rcol := Color.GRAY
var selected := false
var dim := false
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
		rcol = UI.RARITY_COLORS[c.rarity] if not sil else UI.DIM
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
		draw_colored_polygon(PackedVector2Array([Vector2(1, 1), Vector2(13, 1), Vector2(1, 13)]), rcol)
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
