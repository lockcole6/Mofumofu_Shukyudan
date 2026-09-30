extends Control
## チュートリアル（初回）。
## ・説明だけの手順：画面を暗くして、中央のカードで説明。タップで次へ
## ・操作してもらう手順：説明は上のバーか下のタブの位置に「帯」で出し、操作する場所には重ねない。
##   必要なら操作する場所だけを明るく抜き（そこだけ触れる）、実際に操作するまで進まない
## 終わると Game.save.tutorial_done = true。

const UI = preload("res://scripts/ui/UI.gd")
const DIM := Color(0.02, 0.03, 0.08, 0.72)

var main: Node
var step := 0
var steps := []
var _round0 := 0
var _hole := Rect2()
var _t := 0.0
var _blocks := []        # 穴のまわりをふさぐ4枚
var _box: PanelContainer # 説明（中央のカード、または帯）
var _text: Label
var _hint: Label
var _head: HBoxContainer   # 中央のカードの見出し（帯では出さない）
var _skip: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 50
	for i in 4:
		var r := ColorRect.new()
		r.color = DIM
		r.mouse_filter = MOUSE_FILTER_STOP
		r.gui_input.connect(_on_tap_input)
		add_child(r)
		_blocks.append(r)
	_box = PanelContainer.new()
	_box.mouse_filter = MOUSE_FILTER_STOP
	_box.gui_input.connect(_on_tap_input)
	var v := UI.vbox(4)
	_head = UI.hbox(6)
	_head.add_child(UI.label("チュートリアル", 10, UI.CYAN, HORIZONTAL_ALIGNMENT_LEFT, true))
	_head.add_child(UI.spacer())
	_hint = UI.label("", 10, UI.SUB, HORIZONTAL_ALIGNMENT_RIGHT, true)
	_head.add_child(_hint)
	v.add_child(_head)
	# 本文とスキップ（帯のときは1段で横に並ぶ）
	var body := UI.hbox(8)
	_text = UI.wrap_label("", 14, UI.INK)
	_text.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(_text)
	_skip = UI.button("スキップ", "ghost", 10, 24)
	_skip.size_flags_vertical = SIZE_SHRINK_CENTER
	_skip.pressed.connect(finish)
	body.add_child(_skip)
	v.add_child(body)
	_box.add_child(v)
	add_child(_box)
	_build_steps()
	_enter(0)


## hole: 明るく抜く場所（なしなら全体を暗く）、dim=false なら暗くしない、
## dock: 帯を出す場所（"top" / "bottom"）。なしなら中央のカード。done: 進む条件（なしならタップで次へ）
func _build_steps() -> void:
	steps = [
		{"text": "ようこそ、もふもふ蹴球団へ！\nあなたはこのクラブの監督。動物や幻獣の選手を集めて、1部リーグ優勝を目指そう！"},
		{"text": "まずは選手を並べよう。下の「編成」タブをタップ！", "dock": "top",
			"hole": func(): return _tab_rect("編成"),
			"done": func(): return main.current == "編成"},
		{"text": "控えの選手をピッチへドラッグして7体並べよう。右上の「おまかせ編成」でもOK！", "dock": "bottom", "dim": false,
			"done": func(): return Game.save.formation.size() >= Game.TEAM_SIZE},
		{"text": "7体そろった！\n選手をタップするとスキルが見られるよ。\nどの列（FW・MF・DF・GK）に何人置くかで、攻撃力と守備力が変わる。"},
		{"text": "次は試合だ。下の「試合」タブをタップ！", "dock": "top",
			"hole": func(): return _tab_rect("試合"),
			"done": func(): return main.current == "試合"},
		{"text": "NEXT MATCH で相手を確認したら「キックオフ」！", "dock": "bottom",
			"hole": func(): return main.content.get_global_rect(),
			"done": func(): return int(Game.save.league.round) > _round0 and not main.tabs_locked,
			"enter": func(): _round0 = int(Game.save.league.round)},
		{"text": "試合に勝ったら、相手の選手を1体スカウトできる！\n負けても選手は失わないから大丈夫。"},
		{"text": "試合やシーズンの報酬でガチャ石がたまる。\n「ガチャ」で仲間を増やして、「図鑑」を埋めていこう。"},
		{"text": "5節のリーグで上位2チームに入ると昇格。\n部が上がるとコスト上限も上がって、強い選手を並べられる。\n目標は1部優勝！ がんばって、監督！"},
	]


func _enter(i: int) -> void:
	step = i
	if step >= steps.size():
		finish()
		return
	var s: Dictionary = steps[step]
	if s.has("enter"):
		s.enter.call()
	_text.text = s.text
	var docked := s.has("dock")
	_text.add_theme_font_size_override("font_size", 11 if docked else 14)
	_head.visible = not docked
	_hint.text = "タップで次へ" if not s.has("done") else "やってみよう"
	_hint.add_theme_color_override("font_color", UI.SUB if not s.has("done") else UI.LIME)
	var sb := UI.sbox(UI.PANEL, 0 if docked else 12, UI.CYAN, 2, 6 if docked else 14)
	if docked:
		sb.set_border_width_all(0)
		if s.dock == "top":
			sb.border_width_bottom = 2
		else:
			sb.border_width_top = 2
	_box.add_theme_stylebox_override("panel", sb)


func finish() -> void:
	Game.save.tutorial_done = true
	Game.save_game()
	queue_free()


func _on_tap_input(e: InputEvent) -> void:
	# 説明だけの手順は、どこをタップしても次へ
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		if step < steps.size() and not steps[step].has("done"):
			Sound.play("tap")
			_enter(step + 1)


func _process(delta: float) -> void:
	_t += delta
	if step >= steps.size():
		return
	var s: Dictionary = steps[step]
	# 試合中は隠して、終わるのを待つ
	visible = not main.tabs_locked
	if s.has("done") and s.done.call():
		_enter(step + 1)
		return
	_hole = s.hole.call() if s.has("hole") else Rect2()
	_layout(s)
	queue_redraw()


func _layout(s: Dictionary) -> void:
	var vs := get_viewport_rect().size
	# 暗くする部分（穴のまわり）
	if not s.get("dim", true):
		for b in _blocks:
			b.size = Vector2.ZERO
	elif _hole.size == Vector2.ZERO:
		_blocks[0].position = Vector2.ZERO
		_blocks[0].size = vs
		for i in range(1, 4):
			_blocks[i].size = Vector2.ZERO
	else:
		var h := _hole.grow(4)
		_blocks[0].position = Vector2.ZERO
		_blocks[0].size = Vector2(vs.x, maxf(h.position.y, 0))
		_blocks[1].position = Vector2(0, h.end.y)
		_blocks[1].size = Vector2(vs.x, maxf(vs.y - h.end.y, 0))
		_blocks[2].position = Vector2(0, h.position.y)
		_blocks[2].size = Vector2(maxf(h.position.x, 0), h.size.y)
		_blocks[3].position = Vector2(h.end.x, h.position.y)
		_blocks[3].size = Vector2(maxf(vs.x - h.end.x, 0), h.size.y)
	# 説明の場所
	if s.has("dock"):
		# 上のバーか下のタブにぴったり重ねる（操作する場所には重ならない）
		var bar: Rect2 = _top_bar_rect() if s.dock == "top" else _tab_bar_rect()
		_box.position = bar.position
		_box.size = Vector2(bar.size.x, 0)
		var need := _box.get_combined_minimum_size().y
		_box.size = Vector2(bar.size.x, maxf(bar.size.y, need))
		if s.dock == "bottom":
			_box.position.y = vs.y - _box.size.y
	else:
		var bw := minf(vs.x - 32, 330)
		_box.size = Vector2(bw, 0)
		var bh := _box.get_combined_minimum_size().y
		_box.size = Vector2(bw, bh)
		_box.position = Vector2((vs.x - bw) / 2, (vs.y - bh) / 2)


func _draw() -> void:
	if _hole.size == Vector2.ZERO or step >= steps.size():
		return
	var a := 0.6 + 0.4 * sin(_t * 5.0)
	draw_style_box(UI.sbox(Color(0, 0, 0, 0), 6, Color(UI.CYAN, a), 3, 0), _hole.grow(6))


func _tab_rect(tab: String) -> Rect2:
	return main.tab_buttons[tab].get_global_rect()


func _top_bar_rect() -> Rect2:
	return main.content.get_parent().get_child(0).get_global_rect()


func _tab_bar_rect() -> Rect2:
	return main.content.get_parent().get_child(2).get_global_rect()
