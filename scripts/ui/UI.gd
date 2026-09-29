extends RefCounted
## UI部品を作るヘルパー（ダーク×ビビッド）。画面はすべてコードで組み立てる。

const Sprites = preload("res://scripts/ui/Sprites.gd")
const CharCard = preload("res://scripts/ui/CharCard.gd")
const DragScroll = preload("res://scripts/ui/DragScroll.gd")

const BG := Color("0c0f1d")
const PANEL := Color("151a2e")
const PANEL2 := Color("1d2340")
const LINE := Color("2b3259")
const INK := Color("eef1ff")
const SUB := Color("8b93b8")
const DIM := Color("50577a")
const CYAN := Color("22d3ff")
const PINK := Color("ff3d8b")
const LIME := Color("b6ff3b")
const GOLD := Color("ffc83d")
const RED := Color("ff4d6d")
const BLUE := Color("3d8bff")
const GREEN := Color("3ddc97")
## ★はポジションの色とまぎれないよう1色に統一。レア度は★の数とカードの枠（★3金・★4虹）で見せる
const STAR := Color("ffeeb0")
const RARITY_COLORS := {1: STAR, 2: STAR, 3: STAR, 4: STAR}
## ガチャの扉と排出率だけはレア度ごとの色
const DOOR_COLORS := {1: Color("8aa0c8"), 2: Color("3ddc97"), 3: Color("ffc83d"), 4: Color("ff4fd8")}
const GOLD_FRAME := Color("ffd24a")
const ROW_COLORS := {"攻": Color("ff4d6d"), "中": Color("3ddc97"), "守": Color("3d8bff"), "GK": Color("ffb020")}
const HABITAT_COLORS := {"草原": Color("8ee05a"), "森": Color("3ddc97"), "海": Color("3d8bff"),
	"雪山": Color("9fd8ff"), "空": Color("22d3ff"), "伝説": Color("ffc83d"), "蹴球": Color("ff4fd8")}
const SKEW := Vector2(0.22, 0)
const LONG_PRESS := 0.4

static var heavy_font: Font


static func sbox(color: Color, radius := 6, border := Color(0, 0, 0, 0), bw := 0, margin := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s


static func panel(color := PANEL, margin := 10, accent := Color(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	var s := sbox(color, 6, LINE, 1, margin)
	if accent.a > 0.0:
		s.border_color = accent
		s.border_width_left = 3
	p.add_theme_stylebox_override("panel", s)
	return p


static func label(text: String, size := 14, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT, heavy := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if heavy and heavy_font:
		l.add_theme_font_override("font", heavy_font)
	return l


static func title(text: String, sub := "") -> HBoxContainer:
	var h := hbox(8)
	var bar := ColorRect.new()
	bar.color = CYAN
	bar.custom_minimum_size = Vector2(4, 18)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	h.add_child(label(text, 17, INK, HORIZONTAL_ALIGNMENT_LEFT, true))
	if sub != "":
		var s := label(sub, 11, SUB)
		s.size_flags_vertical = Control.SIZE_SHRINK_END
		h.add_child(s)
	return h


static func wrap_label(text: String, size := 13, color := INK) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 60
	return l


## kind: primary / pink / ghost / danger / active
static func button(text: String, kind := "primary", size := 14, min_h := 36) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = min_h
	b.add_theme_font_size_override("font_size", size)
	if heavy_font:
		b.add_theme_font_override("font", heavy_font)
	style_button(b, kind)
	return b


static func style_button(b: Button, kind: String) -> void:
	var bg := CYAN
	var fg := BG
	var border := Color(0, 0, 0, 0)
	match kind:
		"pink":
			bg = PINK
			fg = Color.WHITE
		"danger":
			bg = RED
			fg = Color.WHITE
		"ghost":
			bg = PANEL2
			fg = INK
			border = LINE
		"active":
			bg = Color(CYAN, 0.16)
			fg = CYAN
			border = CYAN
	for st in ["normal", "hover", "pressed", "disabled"]:
		var c := bg
		match st:
			"hover": c = bg.lightened(0.1)
			"pressed": c = bg.darkened(0.15)
			"disabled": c = Color("262b45")
		var sb := sbox(c, 3, border, 1 if border.a > 0.0 else 0, 6)
		sb.skew = SKEW
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(fc, fg)
	b.add_theme_color_override("font_disabled_color", DIM)


static func icon(c: Dictionary, silhouette := false, size := 48) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Sprites.get_tex(c, silhouette)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func stars(r: int) -> String:
	return "★".repeat(r)


static func tag(text: String, color: Color, size := 10, filled := true) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := sbox(color if filled else Color(color, 0.14), 2, color, 0 if filled else 1, 1)
	sb.skew = SKEW
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	p.add_theme_stylebox_override("panel", sb)
	var l := label(text, size, BG if filled else color, HORIZONTAL_ALIGNMENT_CENTER, true)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## タップできる領域。スクロール中のドラッグはタップ扱いしない。
## on_long を渡すと、長押し（long_time 秒）でそちらを呼ぶ。長押ししたときはタップ扱いにしない。
## lift_on_move=true なら、押したまま動かし始めた時点でも on_long を呼ぶ（カードを運ぶ操作用）。
static func on_tap(c: Control, cb: Callable, on_long := Callable(), long_time := LONG_PRESS, lift_on_move := false) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var st := {"down": false, "pos": Vector2.ZERO, "moved": false, "long": false, "n": 0}
	c.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				st.down = true
				st.moved = false
				st.long = false
				st.pos = e.global_position
				st.n += 1
				if on_long.is_valid():
					var my: int = st.n
					c.get_tree().create_timer(long_time).timeout.connect(func():
						if is_instance_valid(c) and st.down and not st.moved and st.n == my:
							st.long = true
							on_long.call())
			elif st.down:
				st.down = false
				if not st.long and e.global_position.distance_to(st.pos) < 12.0 and cb.is_valid():
					Sound.play("tap")
					cb.call()
		elif e is InputEventMouseMotion and st.down and not st.long and lift_on_move and on_long.is_valid() 				and e.global_position.distance_to(st.pos) >= 8.0:
			st.long = true
			on_long.call()
		elif e is InputEventMouseMotion and st.down and e.global_position.distance_to(st.pos) >= 18.0:
			st.moved = true
	)


static func ignore_mouse(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		ignore_mouse(c)


static func card(id: int, silhouette := false, lines := [], on_click := Callable(), icon_size := 44, on_long := Callable()) -> Control:
	var cc = CharCard.new()
	cc.setup(id, silhouette, lines, icon_size)
	if on_click.is_valid() or on_long.is_valid():
		on_tap(cc, on_click, on_long)
	return cc


static func bar(value: float, max_value: float, color := CYAN, h := 6) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size.y = h
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := sbox(Color("262c4a"), 1, Color(0, 0, 0, 0), 0, 0)
	var fg := sbox(color, 1, Color(0, 0, 0, 0), 0, 0)
	bg.skew = SKEW
	fg.skew = SKEW
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


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


static func flow(sep := 4) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	return f


static func spacer(vertical := false) -> Control:
	var c := Control.new()
	if vertical:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func scroll(child: Control) -> ScrollContainer:
	var s: ScrollContainer = DragScroll.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func segmented(options: Array, current: String, on_pick: Callable, size := 13) -> HBoxContainer:
	var h := hbox(6)
	for o in options:
		var b := button(o, "active" if o == current else "ghost", size, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(on_pick.bind(o))
		h.add_child(b)
	return h


## 画面全体にかぶせるモーダル。背景タップ・×・戻るで閉じる。閉じるときは UI.close(root)
static func modal(from: Node, content: Control) -> Control:
	var root := Control.new()
	root.set_meta("layer", true)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	# 背景は「押して離した」ときに閉じる。押した瞬間に閉じると、離した入力が下の画面に届いてしまう
	var st := {"down": false}
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				st.down = true
			elif st.down:
				st.down = false
				close(root))
	var box := panel(PANEL, 12)
	var sb: StyleBoxFlat = box.get_theme_stylebox("panel")
	sb.border_color = Color(CYAN, 0.5)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_right = -12
	box.offset_top = 40
	box.offset_bottom = -40
	var sc := scroll(content)
	box.add_child(sc)
	root.add_child(box)
	var x := button("×", "ghost", 16, 34)
	x.custom_minimum_size.x = 44
	x.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	x.offset_left = -60
	x.offset_right = -16
	x.offset_top = 22
	x.pressed.connect(func(): close(root))
	root.add_child(x)
	from.get_tree().root.add_child(root)
	Nav.push(root, root.queue_free)
	Sound.play("open")
	root.tree_exiting.connect(func(): Sound.play("close"))
	return root


static func close(root: Control) -> void:
	Nav.close(root)
