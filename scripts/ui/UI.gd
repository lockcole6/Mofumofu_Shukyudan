extends RefCounted
## UI部品を作るヘルパー。画面はすべてコードで組み立てる。

const Sprites = preload("res://scripts/ui/Sprites.gd")

const INK := Color("4a3728")
const SUB := Color("8a7560")
const BG := Color("fdf1dc")
const CARD := Color("fffaf0")
const LINE := Color("ead7b7")
const ORANGE := Color("f39c4a")
const BLUE := Color("4f9ad8")
const GREEN := Color("5bb56a")
const GRAY := Color("b8ab98")
const RARITY_COLORS := {1: Color("8fa6b8"), 2: Color("4fb27a"), 3: Color("eaa822"), 4: Color("cf5fd0")}
const ROW_COLORS := {"GK": Color("e8a33d"), "守": Color("4f8fd8"), "中": Color("5bb56a"), "攻": Color("e0575b")}


static func sbox(color: Color, radius := 10, border := Color(0, 0, 0, 0), bw := 0, margin := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(margin)
	return s


static func panel(color := CARD, margin := 8) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(color, 12, LINE, 2, margin))
	return p


static func label(text: String, size := 14, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func wrap_label(text: String, size := 13, color := INK) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 100
	return l


static func button(text: String, color := ORANGE, size := 15, min_h := 36) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = min_h
	b.add_theme_font_size_override("font_size", size)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var c := color
		match st:
			"hover": c = color.lightened(0.12)
			"pressed": c = color.darkened(0.12)
			"disabled": c = GRAY
		var sb := sbox(c, 12, c.darkened(0.25), 0, 6)
		sb.border_width_bottom = 3
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(fc, Color.WHITE)
	return b


static func icon(c: Dictionary, shiny: bool, silhouette := false, size := 48) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Sprites.get_tex(c, shiny, silhouette)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func stars(r: int) -> String:
	return "★".repeat(r)


static func tag(text: String, color: Color, size := 10) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := sbox(color, 6, Color(0, 0, 0, 0), 0, 1)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(text, size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## タップできるカード。スクロール中のドラッグはタップ扱いしない。
static func tile(content: Control, bg := CARD, on_click := Callable(), border := LINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(bg, 10, border, 2, 4))
	p.add_child(content)
	_ignore_mouse(content)
	if on_click.is_valid():
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		var st := {"down": false, "pos": Vector2.ZERO}
		p.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				if e.pressed:
					st.down = true
					st.pos = e.global_position
				elif st.down:
					st.down = false
					if e.global_position.distance_to(st.pos) < 12.0:
						on_click.call()
		)
	return p


static func _ignore_mouse(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


## キャラ1体のカード（アイコン＋名前＋付加情報）
static func char_tile(c: Dictionary, shiny: bool, silhouette: bool, lines: Array, on_click := Callable(), icon_size := 44) -> PanelContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var ic := icon(c, shiny, silhouette, icon_size)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	for l in lines:
		if l is Control:
			l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(l)
		else:
			var lb := label(str(l), 10, INK, HORIZONTAL_ALIGNMENT_CENTER)
			lb.clip_text = true
			lb.custom_minimum_size.x = icon_size
			v.add_child(lb)
	var bg := CARD
	var border: Color = RARITY_COLORS[c.rarity] if not silhouette else LINE
	if shiny and not silhouette:
		bg = Color("fff4c8")
	return tile(v, bg, on_click, border)


static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func grid(cols: int, sep := 6) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	return g


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func centered(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.add_child(child)
	return c
