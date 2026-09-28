extends ScrollContainer
## 指やマウスのドラッグでスクロールできる ScrollContainer（慣性つき）。
## ボタンやカードの上から始めてもスクロールでき、そのときはタップ扱いにしない。

const THRESHOLD := 8.0

var _pressing := false
var _dragging := false
var _start := Vector2.ZERO
var _start_scroll := 0
var _last_y := 0.0
var _vel := 0.0
var _synth := false


func _ready() -> void:
	horizontal_scroll_mode = SCROLL_MODE_DISABLED


func _input(e: InputEvent) -> void:
	if _synth or not is_visible_in_tree():
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			if get_global_rect().has_point(e.position) and _is_top_layer():
				_pressing = true
				_dragging = false
				_start = e.position
				_start_scroll = scroll_vertical
				_last_y = e.position.y
				_vel = 0.0
		elif _pressing:
			_pressing = false
			if _dragging:
				_dragging = false
				get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion and _pressing:
		var dy: float = e.position.y - _start.y
		if not _dragging and absf(dy) > THRESHOLD:
			_dragging = true
			_vel = 0.0
			_cancel_press(e.position)
		if _dragging:
			scroll_vertical = int(_start_scroll - dy)
			_vel = lerpf(_vel, _last_y - e.position.y, 0.5)
			_last_y = e.position.y
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _pressing or absf(_vel) < 0.3:
		_vel = 0.0
		return
	scroll_vertical += int(_vel)
	_vel *= pow(0.02, delta)


## ボタンなどが押しっぱなし扱いにならないよう、画面外で離したことにする
func _cancel_press(at: Vector2) -> void:
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(-9999, -9999)
	up.global_position = up.position
	_synth = true
	get_viewport().push_input(up)
	_synth = false


## モーダルが開いているときは、その中のスクロールだけ動かす
func _is_top_layer() -> bool:
	var top: Node = null
	var root := get_tree().root
	for i in range(root.get_child_count() - 1, -1, -1):
		if root.get_child(i).has_meta("layer"):
			top = root.get_child(i)
			break
	var mine: Node = self
	while mine and not mine.has_meta("layer"):
		mine = mine.get_parent()
	return mine == top
