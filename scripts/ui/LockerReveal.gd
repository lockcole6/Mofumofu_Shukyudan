extends Control
## ガチャ演出：ロッカーの扉の色でレア度がわかり、開くと選手が出てくる。

const UI = preload("res://scripts/ui/UI.gd")
const CharDetail = preload("res://scripts/ui/CharDetail.gd")

var results: Array = []
var idx := 0
var phase := ""   # closed / opening / revealed / summary
var t := 0.0

var glow: ColorRect
var door: Door
var char_icon: TextureRect
var info: VBoxContainer
var hint: Label
var stage: VBoxContainer


class Door extends Control:
	var color := Color.GRAY

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("1d2340"))
		draw_rect(r, color, false, 3.0)
		for i in 5:
			draw_rect(Rect2(size.x * 0.28, 22.0 + i * 9.0, size.x * 0.44, 3), Color(color, 0.6))
		draw_rect(Rect2(size.x - 22, size.y * 0.5 - 18, 5, 36), color)
		draw_colored_polygon(PackedVector2Array([Vector2(0, size.y), Vector2(size.x * 0.5, size.y), Vector2(0, size.y * 0.7)]), Color(color, 0.25))


func _ready() -> void:
	set_meta("layer", true)
	Nav.push(self, queue_free)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.08, 0.96)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)
	stage = UI.vbox(14)
	stage.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(stage)
	var skip := UI.button("SKIP", "ghost", 11, 28)
	skip.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	skip.offset_left = -80
	skip.offset_top = 10
	skip.offset_right = -10
	skip.pressed.connect(_show_summary)
	add_child(skip)
	_show_locker()


func _show_locker() -> void:
	UI.clear(stage)
	var res: Dictionary = results[idx]
	var c: Dictionary = Game.chars[res.id]
	var rc: Color = UI.DOOR_COLORS[res.rarity]
	phase = "closed"
	t = 0.0

	stage.add_child(UI.label("%d / %d" % [idx + 1, results.size()], 12, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER, true))
	var box := Control.new()
	box.custom_minimum_size = Vector2(170, 240)
	box.size_flags_horizontal = SIZE_SHRINK_CENTER
	box.mouse_filter = MOUSE_FILTER_IGNORE
	stage.add_child(box)

	glow = ColorRect.new()
	glow.color = Color(rc, 0.18)
	glow.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	glow.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(glow)

	char_icon = UI.icon(c, false, 150)
	char_icon.set_anchors_and_offsets_preset(PRESET_CENTER)
	char_icon.offset_left = -75
	char_icon.offset_right = 75
	char_icon.offset_top = -75
	char_icon.offset_bottom = 75
	char_icon.pivot_offset = Vector2(75, 75)
	char_icon.scale = Vector2.ZERO
	box.add_child(char_icon)

	door = Door.new()
	door.color = rc
	door.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	door.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(door)

	info = UI.vbox(4)
	info.modulate.a = 0.0
	info.add_child(UI.label(UI.stars(c.rarity), 18, rc, HORIZONTAL_ALIGNMENT_CENTER))
	info.add_child(UI.label(c.name, 22, UI.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	var tags := UI.hbox(6)
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	if res.new:
		tags.add_child(UI.tag("NEW", UI.PINK, 12))
	else:
		tags.add_child(UI.tag("被り → スキル強化素材 +1", UI.CYAN, 11, false))
	info.add_child(tags)
	stage.add_child(info)

	hint = UI.label("タップで次へ ／ 長押しで詳細", 10, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER, true)
	stage.add_child(hint)


func _process(delta: float) -> void:
	t += delta
	if phase == "closed":
		var res: Dictionary = results[idx]
		# ★3以上は扉が震えて光る
		if res.rarity >= 3:
			door.position.x = sin(t * 60.0) * 2.0 * minf(t, 1.0)
			glow.color.a = 0.18 + 0.25 * absf(sin(t * 6.0))
		if t > (1.1 if res.rarity >= 3 else 0.45):
			_open()


func _open() -> void:
	phase = "opening"
	door.position.x = 0
	var tw := create_tween()
	tw.tween_property(door, "scale:x", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(glow, "color:a", 0.35, 0.25)
	tw.tween_property(char_icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(info, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func(): phase = "revealed")


var _press_n := 0
var _long := false
var _pressed_here := false   # この画面で押されたか（ほかの画面で押して、ここで離した入力は無視する）
var _press_phase := ""       # 押したときの演出の段階


func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if e.pressed:
		_pressed_here = true
		_press_phase = phase
		_long = false
		_press_n += 1
		var my := _press_n
		var shown := idx
		# 長押しで詳細。扉が開いている途中から押し続けた場合も、キャラが出ていれば開く
		if phase in ["closed", "opening", "revealed"]:
			get_tree().create_timer(UI.LONG_PRESS).timeout.connect(func():
				if _press_n == my and idx == shown and phase in ["opening", "revealed"]:
					_long = true
					CharDetail.open(self, results[idx].id, {"readonly": true}))
		return
	# 離したとき（ここで押していない・長押しで詳細を開いた、のどちらかなら何もしない）
	_press_n += 1
	if not _pressed_here:
		return
	_pressed_here = false
	if _long:
		_long = false
		return
	match _press_phase:
		"closed":
			if phase == "closed":
				_open()
		"revealed":
			# キャラが出ているときに押して離した → 次へ
			if phase == "revealed":
				idx += 1
				if idx < results.size():
					_show_locker()
				else:
					_show_summary()
		# 扉が開いている途中に押した分は、離しても進めない（演出はそのまま続く）


func _show_summary() -> void:
	if phase == "summary":
		return
	phase = "summary"
	UI.clear(stage)
	for c in get_children():
		if c is Button:
			c.queue_free()
	stage.add_child(UI.label("RESULT", 20, UI.CYAN, HORIZONTAL_ALIGNMENT_CENTER, true))
	stage.add_child(UI.label("長押しで詳細", 10, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
	var g := UI.grid(5, 5)
	g.size_flags_horizontal = SIZE_SHRINK_CENTER
	for res in results:
		var c: Dictionary = Game.chars[res.id]
		var lines := [c.name, UI.label(UI.stars(c.rarity), 9, UI.STAR, HORIZONTAL_ALIGNMENT_CENTER)]
		lines.append(UI.tag("NEW", UI.PINK, 8) if res.new else UI.label("+1", 9, UI.CYAN, HORIZONTAL_ALIGNMENT_CENTER))
		var card = UI.card(res.id, false, lines, Callable(), 44, func(): CharDetail.open(self, res.id, {"readonly": true}))
		card.custom_minimum_size.x = 62
		g.add_child(card)
	stage.add_child(g)
	var close := UI.button("とじる", "primary", 15, 42)
	close.custom_minimum_size.x = 160
	close.size_flags_horizontal = SIZE_SHRINK_CENTER
	close.pressed.connect(func(): Nav.close(self))
	stage.add_child(close)
