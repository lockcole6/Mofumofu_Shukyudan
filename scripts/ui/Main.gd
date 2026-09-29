extends Control

const UI = preload("res://scripts/ui/UI.gd")
const Icon = preload("res://scripts/ui/Icon.gd")
const TAB_ICONS := {"試合": "ball", "編成": "team", "図鑑": "book", "ガチャ": "gacha", "設定": "gear"}
const TABS := [
	["試合", preload("res://scripts/ui/MatchScreen.gd")],
	["編成", preload("res://scripts/ui/TeamScreen.gd")],
	["図鑑", preload("res://scripts/ui/DexScreen.gd")],
	["ガチャ", preload("res://scripts/ui/GachaScreen.gd")],
	["設定", preload("res://scripts/ui/SettingsScreen.gd")],
]

var content: MarginContainer
var stones_label: Label
var div_label: Label
var tab_buttons := {}
var tab_parts := {}      # タブ -> [アイコン, ラベル]
var toast_box: VBoxContainer
var current := ""


func _ready() -> void:
	# どのボタンも押したら音が鳴るように（ボタンの meta "sfx" で音を変えられる。"" なら鳴らさない）
	get_tree().node_added.connect(_on_node_added)
	get_window().theme = _make_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var root := UI.vbox(0)
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(root)

	# 上のバー
	var top := PanelContainer.new()
	var tsb := UI.sbox(UI.PANEL, 0, UI.LINE, 0, 8)
	tsb.border_width_bottom = 1
	tsb.content_margin_left = 12
	tsb.content_margin_right = 12
	top.add_theme_stylebox_override("panel", tsb)
	var th := UI.hbox(8)
	var logo := UI.hbox(0)
	logo.add_child(UI.label("もふもふ", 15, UI.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
	logo.add_child(UI.label("蹴球団", 15, UI.CYAN, HORIZONTAL_ALIGNMENT_LEFT, true))
	th.add_child(logo)
	th.add_child(UI.spacer())
	var dv := UI.tag("", UI.LIME, 11)
	div_label = dv.get_child(0)
	dv.size_flags_vertical = SIZE_SHRINK_CENTER
	th.add_child(dv)
	var st := UI.hbox(4)
	st.add_child(UI.label("◆", 12, UI.CYAN))
	stones_label = UI.label("0", 14, UI.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	st.add_child(stones_label)
	th.add_child(st)
	top.add_child(th)
	root.add_child(top)

	content = MarginContainer.new()
	content.size_flags_vertical = SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, 10)
	root.add_child(content)

	# 下のタブ
	var bottom := PanelContainer.new()
	var bsb := UI.sbox(UI.PANEL, 0, UI.LINE, 0, 0)
	bsb.border_width_top = 1
	bottom.add_theme_stylebox_override("panel", bsb)
	var tabs := UI.hbox(0)
	for t in TABS:
		var b := Button.new()
		b.custom_minimum_size.y = 58
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.pressed.connect(show_screen.bind(t[0]))
		# アイコンと名前を縦に並べる
		var v := UI.vbox(2)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		var ic := Icon.make(TAB_ICONS[t[0]], UI.SUB, 24)
		ic.size_flags_horizontal = SIZE_SHRINK_CENTER
		v.add_child(ic)
		var lb := UI.label(t[0], 11, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER, true)
		v.add_child(lb)
		UI.ignore_mouse(v)
		b.add_child(v)
		tab_parts[t[0]] = [ic, lb]
		tabs.add_child(b)
		tab_buttons[t[0]] = b
	bottom.add_child(tabs)
	root.add_child(bottom)

	toast_box = UI.vbox(4)
	toast_box.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	toast_box.offset_top = 52
	toast_box.offset_left = 16
	toast_box.offset_right = -16
	toast_box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(toast_box)

	Game.changed.connect(_refresh_top)
	Game.toast.connect(show_toast)
	Game.error_toast.connect(func(t): show_toast(t, true))
	Sound.bgm("menu")
	_refresh_top()
	show_screen("試合", false)


func _refresh_top() -> void:
	stones_label.text = str(Game.save.stones)
	div_label.text = "%d部" % Game.division()


## record=true のときは「戻る」で前のタブに戻れるようにする
func show_screen(tab: String, record := true) -> void:
	if tab == current:
		return
	if record and current != "":
		var prev := current
		Nav.push(self, func(): show_screen(prev, false))
	current = tab
	UI.clear(content)
	for t in TABS:
		if t[0] == tab:
			var s: Control = t[1].new()
			s.size_flags_vertical = SIZE_EXPAND_FILL
			content.add_child(s)
	for k in tab_buttons:
		var on: bool = k == tab
		var b: Button = tab_buttons[k]
		for stn in ["normal", "hover", "pressed"]:
			var sb := UI.sbox(Color(UI.CYAN, 0.08) if on else Color(0, 0, 0, 0), 0, UI.CYAN, 0, 0)
			sb.border_width_top = 3 if on else 0
			b.add_theme_stylebox_override(stn, sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var col: Color = UI.CYAN if on else UI.SUB
		tab_parts[k][0].color = col
		tab_parts[k][0].queue_redraw()
		tab_parts[k][1].add_theme_color_override("font_color", col)



func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("_snd"):
		n.set_meta("_snd", true)
		n.pressed.connect(func(): Sound.play(n.get_meta("sfx", "tap")))


func show_toast(text: String, error := false) -> void:
	Sound.play("error" if error else "toast")
	var p := UI.panel(UI.PANEL2, 10, UI.RED if error else UI.LIME)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(UI.wrap_label(text, 13))
	toast_box.add_child(p)
	while toast_box.get_child_count() > 3:
		toast_box.get_child(0).free()
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


## スライダーのつまみ用の丸
func _dot(d: int, col: Color) -> Texture2D:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(col, clampf(r - dist, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _make_theme() -> Theme:
	var t := Theme.new()
	# Webでも日本語が出るようにフォントを同梱（Noto Sans JP 可変フォント）
	var base: FontFile = load("res://assets/fonts/NotoSansJP.ttf")
	var wght := TextServerManager.get_primary_interface().name_to_tag("wght")
	var f := FontVariation.new()
	f.base_font = base
	f.variation_opentype = {wght: 600}
	var h := FontVariation.new()
	h.base_font = base
	h.variation_opentype = {wght: 900}
	UI.heavy_font = h
	t.default_font = f
	t.default_font_size = 14
	t.set_color("font_color", "Label", UI.INK)
	# SpinBox や OptionButton などの標準部品もダークに
	var field := UI.sbox(UI.PANEL2, 3, UI.LINE, 1, 6)
	for type in ["LineEdit", "OptionButton"]:
		t.set_stylebox("normal", type, field)
		t.set_color("font_color", type, UI.INK)
	t.set_stylebox("focus", "LineEdit", UI.sbox(UI.PANEL2, 3, UI.CYAN, 1, 6))
	for stn in ["hover", "pressed", "focus"]:
		t.set_stylebox(stn, "OptionButton", UI.sbox(UI.PANEL2.lightened(0.05), 3, UI.CYAN, 1, 6))
	t.set_stylebox("panel", "PopupMenu", UI.sbox(UI.PANEL, 4, UI.LINE, 1, 4))
	t.set_color("font_color", "PopupMenu", UI.INK)
	t.set_color("font_hover_color", "PopupMenu", UI.CYAN)
	t.set_stylebox("hover", "PopupMenu", UI.sbox(UI.PANEL2, 2, UI.LINE, 0, 2))
	var grab := UI.sbox(UI.LINE, 3, UI.LINE, 0, 0)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", UI.sbox(Color(0, 0, 0, 0), 0, UI.LINE, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", grab)
	# 音量スライダー
	var track := UI.sbox(Color("262c4a"), 3, UI.LINE, 0, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var fill := UI.sbox(UI.CYAN, 3, UI.CYAN, 0, 0)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _dot(16, UI.INK))
	t.set_icon("grabber_highlight", "HSlider", _dot(16, UI.CYAN))
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", UI.sbox(UI.CYAN, 3, UI.CYAN, 0, 0))
	return t
