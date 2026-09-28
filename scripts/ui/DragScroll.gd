extends ScrollContainer
## 指やマウスのドラッグでスクロールできる ScrollContainer（慣性つき）。
## ボタンやカードの上から始めてもスクロールでき、そのときはタップ扱いにしない。

const THRESHOLD := 8.0

var horizontal := false   # true なら横スクロール（ベンチなど）

var _pressing := false
var _dragging := false
var _start := Vector2.ZERO
var _start_scroll := 0
var _last_y := 0.0
var _vel := 0.0
var _synth := false


func _ready() -> void:
	if horizontal:
		vertical_scroll_mode = SCROLL_MODE_DISABLED
		horizontal_scroll_mode = SCROLL_MODE_SHOW_NEVER
	else:
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
				_start_scroll = scroll_horizontal if horizontal else scroll_vertical
				_last_y = _axis(e.position)
				_vel = 0.0
		elif _pressing:
			_pressing = false
			if _dragging:
				_dragging = false
				get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion and _pressing:
		var d: Vector2 = e.position - _start
		var dy: float = d.x if horizontal else d.y
		var other: float = d.y if horizontal else d.x
		# スクロール方向に動いたときだけ（別方向ならドラッグ＆ドロップに任せる）
		if not _dragging and absf(dy) > THRESHOLD and absf(dy) > absf(other):
			_dragging = true
			_vel = 0.0
			_cancel_press(e.position)
		elif not _dragging and absf(other) > THRESHOLD and absf(other) > absf(dy):
			_pressing = false
		if _dragging:
			_set_scroll(int(_start_scroll - dy))
			_vel = lerpf(_vel, _last_y - _axis(e.position), 0.5)
			_last_y = _axis(e.position)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _pressing or absf(_vel) < 0.3:
		_vel = 0.0
		return
	_set_scroll((scroll_horizontal if horizontal else scroll_vertical) + int(_vel))
	_vel *= pow(0.02, delta)


func _axis(p: Vector2) -> float:
	return p.x if horizontal else p.y


func _set_scroll(v: int) -> void:
	if horizontal:
		scroll_horizontal = v
	else:
		scroll_vertical = v


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
