extends Control
## 1部リーグ優勝の演出とエンディング。
## full=false なら祝福の演出だけ（2回目以降の優勝）、true なら続けてエンディング（物語と成績、選手の行進）。

const UI = preload("res://scripts/ui/UI.gd")
const Sprites = preload("res://scripts/ui/Sprites.gd")

var full := true
var phase := "celebrate"   # celebrate / credits / end
var _t := 0.0
var _confetti := []
var _stage: Control
var _credits: VBoxContainer
var _parade := []          # 行進する選手のテクスチャ
var _cont: Button
var _clip: Control         # エンディングの文字を、行進の芝より上だけに見せる


func _ready() -> void:
	set_meta("layer", true)
	Nav.push(self, queue_free)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var r := RandomNumberGenerator.new()
	for i in 90:
		_confetti.append({"x": r.randf(), "y": r.randf() * -1.0, "v": r.randf_range(0.08, 0.2), "s": r.randf_range(2, 5),
			"c": [UI.GOLD, UI.CYAN, UI.PINK, UI.LIME, Color.WHITE][r.randi() % 5], "w": r.randf_range(0, TAU)})
	for id in Game.chars:
		if Game.owned(id):
			_parade.append(Sprites.get_tex(Game.chars[id]))
	_parade.shuffle()
	Sound.play("champion")
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_stage.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_stage)
	_show_celebrate()


func _show_celebrate() -> void:
	phase = "celebrate"
	UI.clear(_stage)
	var v := UI.vbox(8)
	v.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = MOUSE_FILTER_IGNORE
	var sp := Control.new()
	sp.custom_minimum_size.y = 170   # トロフィーを描く場所
	v.add_child(sp)
	v.add_child(UI.label("1部リーグ優勝！", 32, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(UI.label("もふもふ蹴球団が頂点に立った！", 15, UI.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(UI.label("1部優勝 %d回目" % int(Game.save.record.titles), 12, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
	var hint := UI.label("タップで続ける", 11, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER, true)
	v.add_child(hint)
	UI.ignore_mouse(v)
	_stage.add_child(v)


func _show_credits() -> void:
	phase = "credits"
	_t = 0.0
	UI.clear(_stage)
	Sound.bgm("menu")
	var rec: Dictionary = Game.save.record
	var lines := [
		["もふもふ蹴球団", 26, UI.CYAN],
		["― 優勝への道のり ―", 13, UI.SUB],
		["", 30, UI.INK],
		["5部の小さなクラブから始まった物語。", 14, UI.INK],
		["ネコの気まぐれドリブル、カピバラの動じない心。", 14, UI.INK],
		["集まった仲間たちと、たくさんの試合を戦いぬいた。", 14, UI.INK],
		["", 24, UI.INK],
		["そしてついに、1部リーグの頂点へ。", 16, UI.GOLD],
		["", 40, UI.INK],
		["― 戦績 ―", 13, UI.SUB],
		["通算 %d勝 %d分 %d敗" % [rec.wins, rec.draws, rec.losses], 14, UI.INK],
		["シーズン %d" % int(Game.save.league.season), 14, UI.INK],
		["ガチャ %d回" % int(Game.save.pulls), 14, UI.INK],
		["図鑑 %d / %d" % [Game.dex_count(), Game.dex_total()], 14, UI.INK],
		["", 40, UI.INK],
		["監督、ありがとう。", 16, UI.INK],
		["", 16, UI.INK],
		["でも、図鑑はまだ埋まっていない。" if Game.dex_count() < Game.dex_total() else "図鑑もすべて埋まった。本当にすごい！", 14, UI.INK],
		["もふもふ蹴球団の冒険は、これからも続く――", 14, UI.INK],
		["", 60, UI.INK],
		["THANK YOU FOR PLAYING", 20, UI.GOLD],
	]
	_credits = UI.vbox(6)
	_credits.mouse_filter = MOUSE_FILTER_IGNORE
	for l in lines:
		if l[0] == "":
			var gap := Control.new()
			gap.custom_minimum_size.y = l[1]
			_credits.add_child(gap)
		else:
			# 折り返さずに1行で。長い行は文字を小さくして画面に収める
			var fs: int = l[1]
			var f: Font = UI.heavy_font if UI.heavy_font else get_theme_default_font()
			while fs > 10 and f.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > get_viewport_rect().size.x - 28:
				fs -= 1
			_credits.add_child(UI.label(l[0], fs, l[2], HORIZONTAL_ALIGNMENT_CENTER, l[1] >= 16))
	var vs := get_viewport_rect().size
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = MOUSE_FILTER_IGNORE
	_clip.position = Vector2.ZERO
	_clip.size = Vector2(vs.x, vs.y - 116)
	_stage.add_child(_clip)
	_clip.add_child(_credits)
	_credits.position = Vector2(12, _clip.size.y)
	_credits.custom_minimum_size.x = vs.x - 24
	_credits.size = Vector2(vs.x - 24, _credits.get_combined_minimum_size().y)
	_cont = UI.button("つづける", "primary", 16, 46)
	_cont.visible = false
	_cont.pressed.connect(func(): Nav.close(self))
	_cont.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	_cont.offset_left = -90
	_cont.offset_right = 90
	_cont.offset_top = -170
	_cont.offset_bottom = -124
	add_child(_cont)


func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed):
		return
	match phase:
		"celebrate":
			if full:
				_show_credits()
			else:
				Nav.close(self)
		"credits":
			_to_end()


func _to_end() -> void:
	phase = "end"
	var vs := get_viewport_rect().size
	_credits.position.y = minf(_credits.position.y, _clip.size.y * 0.55 - _credits.size.y)
	_cont.visible = true


func _process(delta: float) -> void:
	_t += delta
	for c in _confetti:
		c.y += c.v * delta
		c.w += delta * 3.0
		if c.y > 1.05:
			c.y = -0.05
	if phase == "credits" and _credits:
		_credits.position.y -= delta * 38.0
		# 最後の行が上の方まで来たら終わり
		if _credits.position.y + _credits.size.y < _clip.size.y * 0.55:
			_to_end()
	queue_redraw()


func _draw() -> void:
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.03, 0.09, 1.0))
	# 光の筋
	for k in 8:
		var a := _t * 0.2 + k * TAU / 8.0
		var c := Vector2(vs.x / 2, vs.y * 0.3)
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a - 0.08), sin(a - 0.08)) * vs.y, c + Vector2(cos(a + 0.08), sin(a + 0.08)) * vs.y]),
			Color(UI.GOLD, 0.05))
	if phase == "celebrate":
		_trophy(Vector2(vs.x / 2, vs.y * 0.5 - 150))
	# 紙吹雪
	for c in _confetti:
		var p := Vector2(c.x * vs.x + sin(c.w) * 6.0, c.y * vs.y)
		draw_rect(Rect2(p, Vector2(c.s, c.s * (0.5 + 0.5 * absf(sin(c.w))))), c.c)
	# 行進（エンディング中）
	if phase != "celebrate" and not _parade.is_empty():
		var gy := vs.y - 110
		draw_rect(Rect2(0, gy, vs.x, 110), Color("2a7f35"))
		for k in 8:
			if k % 2 == 0:
				draw_rect(Rect2(vs.x * k / 8.0, gy, vs.x / 8.0, 110), Color("2f8d3b"))
		draw_line(Vector2(0, gy), Vector2(vs.x, gy), Color(1, 1, 1, 0.4), 2)
		var spacing := 44.0
		var total := spacing * _parade.size()
		for i in _parade.size():
			var x := fposmod(_t * 40.0 + i * spacing, maxf(total, vs.x + spacing)) - spacing
			var bob := absf(sin(_t * 6.0 + i)) * 4.0
			draw_texture_rect(_parade[i], Rect2(x, gy + 40 - bob, 36, 36), false)


func _trophy(c: Vector2) -> void:
	var gold := UI.GOLD
	var dark := gold.darkened(0.3)
	# カップ
	var cup := PackedVector2Array()
	for k in 17:
		var a := PI * k / 16.0
		cup.append(c + Vector2(-cos(a) * 44, sin(a) * 60))
	cup = PackedVector2Array([c + Vector2(-48, -8)]) + cup + PackedVector2Array([c + Vector2(48, -8)])
	draw_colored_polygon(cup, gold)
	draw_rect(Rect2(c.x - 50, c.y - 14, 100, 10), gold.lightened(0.2))
	# 取っ手
	for side in [-1, 1]:
		draw_arc(c + Vector2(side * 50, 14), 18, -PI / 2 if side == 1 else PI / 2, PI / 2 if side == 1 else PI * 1.5, 16, dark, 7, true)
	# 足と台座
	draw_rect(Rect2(c.x - 8, c.y + 58, 16, 22), dark)
	draw_rect(Rect2(c.x - 34, c.y + 80, 68, 14), gold)
	draw_rect(Rect2(c.x - 42, c.y + 94, 84, 12), dark)
	# ボールの紋章
	draw_circle(c + Vector2(0, 20), 16, Color.WHITE)
	var pent := PackedVector2Array()
	for k in 5:
		var a := -PI / 2 + TAU * k / 5.0
		pent.append(c + Vector2(0, 20) + Vector2(cos(a), sin(a)) * 6)
	draw_colored_polygon(pent, Color("1c1426"))
	# きらめき
	draw_circle(c + Vector2(-26, 6), 4, Color(1, 1, 1, 0.8))
