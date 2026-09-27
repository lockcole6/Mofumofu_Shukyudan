extends Control
## ガチャ演出：ロッカーの扉の色でレア度がわかり、開くと選手が出てくる。
## 色違いのときだけ背景が虹色になる。

const UI = preload("res://scripts/ui/UI.gd")

var results: Array = []
var idx := 0
var phase := ""   # closed / opening / revealed / summary
var t := 0.0

var interior: ColorRect
var door: Door
var char_icon: TextureRect
var info: VBoxContainer
var hint: Label
var stage: VBoxContainer


class Door extends Control:
	var color := Color.GRAY

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, color)
		draw_rect(r, color.darkened(0.35), false, 4.0)
		for i in 4:
			var y := 24.0 + i * 12.0
			draw_rect(Rect2(size.x * 0.25, y, size.x * 0.5, 5), color.darkened(0.3))
		draw_rect(Rect2(size.x - 26, size.y * 0.5 - 16, 8, 32), color.lightened(0.45))
		draw_rect(Rect2(10, size.y - 50, size.x * 0.4, 26), color.lightened(0.25))


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.09, 0.14, 0.94)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)
	stage = UI.vbox(12)
	stage.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(stage)
	var skip := UI.button("スキップ", UI.GRAY, 12, 28)
	skip.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	skip.offset_left = -84
	skip.offset_top = 8
	skip.offset_right = -8
	skip.pressed.connect(_show_summary)
	add_child(skip)
	_show_locker()


func _show_locker() -> void:
	UI.clear(stage)
	var res: Dictionary = results[idx]
	var c: Dictionary = Game.chars[res.id]
	phase = "closed"
	t = 0.0

	stage.add_child(UI.label("%d / %d" % [idx + 1, results.size()], 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var box := Control.new()
	box.custom_minimum_size = Vector2(170, 250)
	box.size_flags_horizontal = SIZE_SHRINK_CENTER
	box.mouse_filter = MOUSE_FILTER_IGNORE
	stage.add_child(box)

	interior = ColorRect.new()
	interior.color = Color(UI.RARITY_COLORS[c.rarity]).lightened(0.55)
	interior.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	interior.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(interior)

	char_icon = UI.icon(c, res.shiny, false, 140)
	char_icon.set_anchors_and_offsets_preset(PRESET_CENTER)
	char_icon.offset_left = -70
	char_icon.offset_right = 70
	char_icon.offset_top = -70
	char_icon.offset_bottom = 70
	char_icon.pivot_offset = Vector2(70, 70)
	char_icon.scale = Vector2.ZERO
	box.add_child(char_icon)

	door = Door.new()
	door.color = UI.RARITY_COLORS[res.rarity]
	door.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	door.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(door)

	info = UI.vbox(2)
	info.modulate.a = 0.0
	info.add_child(UI.label(UI.stars(c.rarity), 18, UI.RARITY_COLORS[c.rarity], HORIZONTAL_ALIGNMENT_CENTER))
	info.add_child(UI.label(c.name, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var tags := UI.hbox(6)
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	if res.shiny:
		tags.add_child(UI.tag("☆色違い☆", Color("e8a000"), 13))
	if res.new:
		tags.add_child(UI.tag("NEW!", Color("e04848"), 13))
	elif res.lv_up:
		tags.add_child(UI.tag("被り → Lv%d に強化" % Game.lv_of(Game.key(res.id, res.shiny)), UI.BLUE, 13))
	elif res.fragments > 0:
		tags.add_child(UI.tag("被り → かけら +%d" % res.fragments, Color("c070a0"), 13))
	info.add_child(tags)
	stage.add_child(info)

	hint = UI.label("タップで開ける", 12, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	stage.add_child(hint)


func _process(delta: float) -> void:
	t += delta
	if phase == "closed":
		var res: Dictionary = results[idx]
		# ★3以上は扉が震える
		if res.rarity >= 3:
			door.position.x = sin(t * 60.0) * 2.0 * minf(t, 1.0)
		if t > (1.1 if res.rarity >= 3 else 0.5):
			_open()
	if phase in ["opening", "revealed"] and results[idx].shiny:
		interior.color = Color.from_hsv(fposmod(t * 0.35, 1.0), 0.45, 1.0)


func _open() -> void:
	phase = "opening"
	door.position.x = 0
	door.pivot_offset = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(door, "scale:x", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(char_icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(info, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func():
		phase = "revealed"
		hint.text = "タップで次へ" if idx < results.size() - 1 else "タップで結果一覧へ")


func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	match phase:
		"closed":
			_open()
		"revealed":
			idx += 1
			if idx < results.size():
				_show_locker()
			else:
				_show_summary()


func _show_summary() -> void:
	if phase == "summary":
		return
	phase = "summary"
	UI.clear(stage)
	for c in get_children():
		if c is Button:
			c.queue_free()
	stage.add_child(UI.label("ガチャ結果", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var g := UI.grid(5, 6)
	g.size_flags_horizontal = SIZE_SHRINK_CENTER
	for res in results:
		var c: Dictionary = Game.chars[res.id]
		var lines := []
		if res.new:
			lines.append(UI.tag("NEW", Color("e04848"), 9))
		elif res.lv_up:
			lines.append(UI.tag("Lv UP", UI.BLUE, 9))
		else:
			lines.append(UI.tag("かけら", Color("c070a0"), 9))
		if res.shiny:
			lines.append(UI.tag("色違い", Color("e8a000"), 9))
		g.add_child(UI.char_tile(c, res.shiny, false, lines, Callable(), 44))
	stage.add_child(g)
	var close := UI.button("とじる", UI.ORANGE, 16, 44)
	close.custom_minimum_size.x = 160
	close.size_flags_horizontal = SIZE_SHRINK_CENTER
	close.pressed.connect(queue_free)
	stage.add_child(close)
