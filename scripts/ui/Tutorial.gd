extends Control
## チュートリアル。画面を暗くして、操作してほしい場所だけ明るく抜く（そこだけ触れる）。
## 「タップで次へ」の説明と、実際の操作（タブを開く・7体並べる・キックオフ）を待つ手順がある。
## 終わると Game.save.tutorial_done = true。設定からもう一度見られる。

const UI = preload("res://scripts/ui/UI.gd")
const DIM := Color(0.02, 0.03, 0.08, 0.72)

var main: Node
var step := 0
var steps := []
var _round0 := 0
var _hole := Rect2()
var _t := 0.0
var _blocks := []        # 穴のまわりをふさぐ4枚
var _bubble: PanelContainer
var _text: Label
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 50
	for i in 4:
		var r := ColorRect.new()
		r.color = DIM
		r.mouse_filter = MOUSE_FILTER_STOP
		r.gui_input.connect(_on_block_input)
		add_child(r)
		_blocks.append(r)
	_bubble = UI.panel(UI.PANEL, 12, UI.CYAN)
	var sb: StyleBoxFlat = _bubble.get_theme_stylebox("panel")
	sb.set_border_width_all(2)
	sb.border_color = UI.CYAN
	_bubble.mouse_filter = MOUSE_FILTER_STOP
	_bubble.gui_input.connect(_on_block_input)
	var v := UI.vbox(8)
	var head := UI.hbox(6)
	head.add_child(UI.label("チュートリアル", 11, UI.CYAN, HORIZONTAL_ALIGNMENT_LEFT, true))
	head.add_child(UI.spacer())
	var skip := UI.button("スキップ", "ghost", 10, 24)
	skip.pressed.connect(finish)
	head.add_child(skip)
	v.add_child(head)
	_text = UI.wrap_label("", 14, UI.INK)
	v.add_child(_text)
	_hint = UI.label("", 10, UI.SUB, HORIZONTAL_ALIGNMENT_RIGHT, true)
	v.add_child(_hint)
	_bubble.add_child(v)
	add_child(_bubble)
	_build_steps()
	_enter(0)


func _build_steps() -> void:
	steps = [
		{"text": "ようこそ、もふもふ蹴球団へ！\nあなたはこのクラブの監督。動物や幻獣の選手を集めて、1部リーグ優勝を目指そう！"},
		{"text": "まずは選手を並べよう。\n下の「編成」タブをタップ！", "hole": func(): return _tab_rect("編成"),
			"done": func(): return main.current == "編成"},
		{"text": "控えの選手をピッチへドラッグして、7体並べよう。\n右上の「おまかせ編成」を使えば自動で並べられるよ。", "hole": func(): return main.content.get_global_rect(),
			"done": func(): return Game.save.formation.size() >= Game.TEAM_SIZE},
		{"text": "7体そろった！\n選手をタップするとスキルが見られるよ。\nどの列に何人置くかで、攻撃力と守備力が変わる。"},
		{"text": "次は試合だ。\n下の「試合」タブをタップ！", "hole": func(): return _tab_rect("試合"),
			"done": func(): return main.current == "試合"},
		{"text": "NEXT MATCH で相手を確認して、「キックオフ」！", "hole": _kickoff_rect,
			"done": func(): return int(Game.save.league.round) > _round0 and not main.tabs_locked, "enter": func():
				_round0 = int(Game.save.league.round)},
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
	_hint.text = "タップで次へ" if not s.has("done") else "やってみよう"
	_hint.add_theme_color_override("font_color", UI.SUB if not s.has("done") else UI.LIME)
	# 操作してもらう手順では、吹き出しに触っても下の画面に届くようにする（スキップだけは押せる）
	_bubble.mouse_filter = MOUSE_FILTER_STOP if not s.has("done") else MOUSE_FILTER_IGNORE


func finish() -> void:
	Game.save.tutorial_done = true
	Game.save_game()
	queue_free()


func _on_block_input(e: InputEvent) -> void:
	# 説明だけの手順は、どこをタップしても次へ
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		if not steps[step].has("done"):
			Sound.play("tap")
			_enter(step + 1)


func _process(delta: float) -> void:
	_t += delta
	var s: Dictionary = steps[step] if step < steps.size() else {}
	# 試合中は隠して、終わるのを待つ
	visible = not main.tabs_locked
	if s.has("done") and s.done.call():
		_enter(step + 1)
		return
	_hole = s.hole.call() if s.has("hole") else Rect2()
	_layout()
	queue_redraw()


func _layout() -> void:
	var vs := get_viewport_rect().size
	var h := _hole
	if h.size == Vector2.ZERO:
		h = Rect2(vs / 2, Vector2.ZERO)
		_blocks[0].position = Vector2.ZERO
		_blocks[0].size = vs
		for i in range(1, 4):
			_blocks[i].size = Vector2.ZERO
	else:
		h = h.grow(4)
		_blocks[0].position = Vector2.ZERO
		_blocks[0].size = Vector2(vs.x, h.position.y)
		_blocks[1].position = Vector2(0, h.end.y)
		_blocks[1].size = Vector2(vs.x, vs.y - h.end.y)
		_blocks[2].position = Vector2(0, h.position.y)
		_blocks[2].size = Vector2(h.position.x, h.size.y)
		_blocks[3].position = Vector2(h.end.x, h.position.y)
		_blocks[3].size = Vector2(vs.x - h.end.x, h.size.y)
	# 吹き出しは穴とかぶらない側に
	var bw := minf(vs.x - 24, 340)
	_bubble.size = Vector2(bw, 0)
	_bubble.reset_size()
	_bubble.size.x = bw
	var bh := _bubble.get_combined_minimum_size().y
	var y := 70.0
	if _hole.size.y > vs.y * 0.5:
		y = vs.y - bh - 6   # 大きな穴（画面全体を操作）のときは下のタブの上に
	elif _hole.size != Vector2.ZERO and _hole.get_center().y < vs.y * 0.5:
		y = minf(_hole.end.y + 16, vs.y - bh - 70)
	elif _hole.size != Vector2.ZERO:
		y = maxf(_hole.position.y - bh - 16, 50)
	else:
		y = (vs.y - bh) / 2
	_bubble.position = Vector2((vs.x - bw) / 2, y)


func _draw() -> void:
	if _hole.size == Vector2.ZERO:
		return
	var a := 0.6 + 0.4 * sin(_t * 5.0)
	var sb := UI.sbox(Color(0, 0, 0, 0), 6, Color(UI.CYAN, a), 3, 0)
	draw_style_box(sb, _hole.grow(6))


func _tab_rect(tab: String) -> Rect2:
	return main.tab_buttons[tab].get_global_rect()


func _kickoff_rect() -> Rect2:
	for b in main.content.find_children("*", "Button", true, false):
		if b.visible and b.find_children("*", "Label", true, false).any(func(l): return l.text == "キックオフ"):
			return b.get_global_rect()
	return main.content.get_global_rect()
