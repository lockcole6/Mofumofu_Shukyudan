extends Control

const UI = preload("res://scripts/ui/UI.gd")
const TABS := [
	["試合", preload("res://scripts/ui/MatchScreen.gd")],
	["ガチャ", preload("res://scripts/ui/GachaScreen.gd")],
	["図鑑", preload("res://scripts/ui/DexScreen.gd")],
	["編成", preload("res://scripts/ui/TeamScreen.gd")],
	["デバッグ", preload("res://scripts/ui/DebugScreen.gd")],
]

var content: MarginContainer
var stones_label: Label
var frag_label: Label
var tab_buttons := {}
var toast_box: VBoxContainer


func _ready() -> void:
	theme = _make_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var root := UI.vbox(0)
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(root)

	# 上のバー
	var top := PanelContainer.new()
	var tsb := UI.sbox(UI.ORANGE, 0, Color(0, 0, 0, 0), 0, 6)
	tsb.content_margin_left = 10
	tsb.content_margin_right = 10
	top.add_theme_stylebox_override("panel", tsb)
	var th := UI.hbox(6)
	th.add_child(UI.label("もふもふ蹴球団", 16, Color.WHITE))
	th.add_child(UI.spacer())
	stones_label = _counter(th, "石", Color("5fd3e8"))
	frag_label = _counter(th, "かけら", Color("f2a5c8"))
	top.add_child(th)
	root.add_child(top)

	content = MarginContainer.new()
	content.size_flags_vertical = SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, 8)
	root.add_child(content)

	# 下のタブ
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", UI.sbox(Color("fff6e6"), 0, UI.LINE, 0, 4))
	var tabs := UI.hbox(4)
	for t in TABS:
		var b := UI.button(t[0], UI.GRAY, 13, 40)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.pressed.connect(show_screen.bind(t[0]))
		tabs.add_child(b)
		tab_buttons[t[0]] = b
	bottom.add_child(tabs)
	root.add_child(bottom)

	toast_box = UI.vbox(4)
	toast_box.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	toast_box.offset_top = 46
	toast_box.offset_left = 16
	toast_box.offset_right = -16
	toast_box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(toast_box)

	Game.changed.connect(_refresh_top)
	Game.toast.connect(show_toast)
	_refresh_top()
	show_screen("試合")


func _counter(parent: Control, kind: String, color: Color) -> Label:
	var p := PanelContainer.new()
	var sb := UI.sbox(Color(0, 0, 0, 0.18), 10, Color(0, 0, 0, 0), 0, 2)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	p.add_theme_stylebox_override("panel", sb)
	var h := UI.hbox(4)
	h.add_child(UI.label("◆" if kind == "石" else "✦", 12, color))
	var l := UI.label("0", 13, Color.WHITE)
	h.add_child(l)
	p.add_child(h)
	parent.add_child(p)
	return l


func _refresh_top() -> void:
	stones_label.text = str(Game.save.stones)
	frag_label.text = str(Game.save.fragments)


func show_screen(tab: String) -> void:
	UI.clear(content)
	for t in TABS:
		if t[0] == tab:
			var s: Control = t[1].new()
			s.size_flags_vertical = SIZE_EXPAND_FILL
			content.add_child(s)
	for k in tab_buttons:
		var col: Color = UI.ORANGE if k == tab else UI.GRAY
		for st in ["normal", "hover", "pressed"]:
			var sb: StyleBoxFlat = tab_buttons[k].get_theme_stylebox(st).duplicate()
			sb.bg_color = col if st == "normal" else (col.lightened(0.12) if st == "hover" else col.darkened(0.12))
			sb.border_color = col.darkened(0.25)
			tab_buttons[k].add_theme_stylebox_override(st, sb)


func show_toast(text: String) -> void:
	var p := UI.panel(Color("fff3b0"), 8)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(UI.wrap_label(text, 13))
	toast_box.add_child(p)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _make_theme() -> Theme:
	var t := Theme.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Yu Gothic UI", "Meiryo UI", "Meiryo", "Hiragino Sans",
		"Hiragino Kaku Gothic ProN", "Noto Sans CJK JP", "Noto Sans JP", "Droid Sans Japanese", "sans-serif"])
	f.font_weight = 700
	t.default_font = f
	t.default_font_size = 14
	t.set_color("font_color", "Label", UI.INK)
	return t
