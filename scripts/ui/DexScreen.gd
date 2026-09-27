extends VBoxContainer

const UI = preload("res://scripts/ui/UI.gd")
const HABITAT_COLORS := {"草原": Color("7cc46a"), "森": Color("3f9a5c"), "海": Color("4a9ad8"),
	"雪山": Color("8fb8d8"), "空": Color("79c6e8"), "伝説": Color("c48ae0")}
const SOURCE_TEXT := {"both": "ガチャ・スカウト", "gacha": "ガチャ限定", "scout": "スカウト限定"}
const LIMIT_TEXT := {"night": "夜の試合だけ", "summer_night": "夏の夜の試合だけ"}

var page := "草原"


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	build()


func build() -> void:
	UI.clear(self)
	# 全体の進み具合
	var head := UI.panel()
	var hv := UI.vbox(4)
	var hh := UI.hbox()
	hh.add_child(UI.label("図鑑", 18))
	hh.add_child(UI.spacer())
	hh.add_child(UI.label("%d / %d" % [Game.dex_count(), Game.dex_total()], 18, UI.ORANGE))
	hv.add_child(hh)
	var bar := ProgressBar.new()
	bar.max_value = Game.dex_total()
	bar.value = Game.dex_count()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 10
	bar.add_theme_stylebox_override("background", UI.sbox(Color("efe2cc"), 5, Color(0, 0, 0, 0), 0, 0))
	bar.add_theme_stylebox_override("fill", UI.sbox(UI.ORANGE, 5, Color(0, 0, 0, 0), 0, 0))
	hv.add_child(bar)
	head.add_child(hv)
	add_child(head)

	# 生息地ページのタブ
	var tabs := UI.grid(3, 4)
	for h in Game.HABITATS:
		var n := Game.page_progress(h, false).x + Game.page_progress(h, true).x
		var b := UI.button("%s %d/%d" % [h, n, Game.ids_in_habitat(h).size() * 2],
			HABITAT_COLORS[h] if h == page else UI.GRAY, 12, 30)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.pressed.connect(func():
			page = h
			build())
		tabs.add_child(b)
	add_child(tabs)

	# ページ報酬
	var rw := UI.hbox(6)
	for shiny in [false, true]:
		var got: bool = Game.save.pages.has(page + ("_s" if shiny else "_n"))
		var p := Game.page_progress(page, shiny)
		var txt := "%s %d/%d  報酬◆%d%s" % ["色違い" if shiny else "通常", p.x, p.y,
			Game.PAGE_REWARD_SHINY if shiny else Game.PAGE_REWARD_NORMAL, " 受取済" if got else ""]
		rw.add_child(UI.label(txt, 11, UI.GREEN if got else UI.SUB))
		if not shiny:
			rw.add_child(UI.spacer())
	add_child(rw)

	# キャラ一覧（通常と色違いを並べる）
	var g := UI.grid(4, 6)
	for id in Game.ids_in_habitat(page):
		var c: Dictionary = Game.chars[id]
		for shiny in [false, true]:
			var has: bool = Game.owned(id, shiny)
			var lines := ["No.%02d %s" % [id, c.name if has else "？？？"]]
			if shiny:
				lines.append(UI.tag("色違い", Color("e8a000") if has else UI.GRAY, 9))
			else:
				lines.append(UI.label(UI.stars(c.rarity), 9, UI.RARITY_COLORS[c.rarity], HORIZONTAL_ALIGNMENT_CENTER))
			var t := UI.char_tile(c, shiny, not has, lines, _detail.bind(id, shiny), 52)
			t.size_flags_horizontal = SIZE_EXPAND_FILL
			g.add_child(t)
	add_child(UI.scroll(g))


func _detail(id: int, shiny: bool) -> void:
	UI.clear(self)
	var c: Dictionary = Game.chars[id]
	var has: bool = Game.owned(id, shiny)
	var k := Game.key(id, shiny)

	var back := UI.button("← 図鑑にもどる", UI.GRAY, 13, 30)
	back.size_flags_horizontal = SIZE_SHRINK_BEGIN
	back.pressed.connect(build)
	add_child(back)

	var v := UI.vbox(8)
	var card := UI.panel(Color("fff4c8") if shiny and has else UI.CARD, 12)
	var cv := UI.vbox(6)
	var ic := UI.icon(c, shiny, not has, 150)
	ic.size_flags_horizontal = SIZE_SHRINK_CENTER
	cv.add_child(ic)
	cv.add_child(UI.label("No.%02d%s" % [id, "（色違い）" if shiny else ""], 12, UI.SUB, HORIZONTAL_ALIGNMENT_CENTER))
	cv.add_child(UI.label(c.name if has else "？？？", 22, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	cv.add_child(UI.label(UI.stars(c.rarity), 16, UI.RARITY_COLORS[c.rarity], HORIZONTAL_ALIGNMENT_CENTER))
	var tags := UI.hbox(6)
	tags.alignment = BoxContainer.ALIGNMENT_CENTER
	tags.add_child(UI.tag(c.habitat, HABITAT_COLORS[c.habitat], 11))
	tags.add_child(UI.tag("得意：" + c.pos, UI.ROW_COLORS[c.pos], 11))
	tags.add_child(UI.tag(SOURCE_TEXT[c.source], UI.SUB, 11))
	if LIMIT_TEXT.has(c.limit):
		tags.add_child(UI.tag(LIMIT_TEXT[c.limit], Color("5a5a9a"), 11))
	cv.add_child(tags)
	card.add_child(cv)
	v.add_child(card)

	var body := UI.panel()
	var bv := UI.vbox(6)
	if has:
		bv.add_child(UI.label("Lv %d / %d" % [Game.lv_of(k), Game.MAX_LV], 13, UI.BLUE))
		for s in [["スピード", "spd"], ["パワー", "pow"], ["パス", "pas"], ["守備", "def"]]:
			var row := UI.hbox(6)
			var l := UI.label(s[0], 12)
			l.custom_minimum_size.x = 64
			row.add_child(l)
			var bar := ProgressBar.new()
			bar.max_value = 10
			bar.value = c[s[1]]
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 10)
			bar.size_flags_horizontal = SIZE_EXPAND_FILL
			bar.size_flags_vertical = SIZE_SHRINK_CENTER
			bar.add_theme_stylebox_override("background", UI.sbox(Color("efe2cc"), 5, Color(0, 0, 0, 0), 0, 0))
			bar.add_theme_stylebox_override("fill", UI.sbox(UI.ORANGE, 5, Color(0, 0, 0, 0), 0, 0))
			row.add_child(bar)
			row.add_child(UI.label(str(c[s[1]]), 12))
			bv.add_child(row)
		bv.add_child(UI.wrap_label(c.desc, 13))
	else:
		bv.add_child(UI.label("まだ出会っていない", 13, UI.SUB))
		var hint: String = "どこかで低確率で出会える、%sの色違い" % ("通常の姿を見つけた" if Game.owned(id, false) else "この選手") if shiny else c.hint
		bv.add_child(UI.wrap_label("ヒント：" + hint, 13))
	body.add_child(bv)
	v.add_child(body)
	add_child(UI.scroll(v))
