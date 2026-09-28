extends VBoxContainer

const UI = preload("res://scripts/ui/UI.gd")
const CharDetail = preload("res://scripts/ui/CharDetail.gd")

var page := "草原"


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	build()


func build() -> void:
	UI.clear(self)
	var head := UI.hbox()
	head.add_child(UI.title("図鑑"))
	head.add_child(UI.spacer())
	head.add_child(UI.label("%d" % Game.dex_count(), 22, UI.CYAN, HORIZONTAL_ALIGNMENT_RIGHT, true))
	var tot := UI.label("/%d" % Game.dex_total(), 12, UI.SUB)
	tot.size_flags_vertical = SIZE_SHRINK_END
	head.add_child(tot)
	add_child(head)
	add_child(UI.bar(Game.dex_count(), Game.dex_total(), UI.CYAN, 4))

	# 生息地ページ
	var tabs := UI.flow(5)
	for h in Game.HABITATS:
		var p := Game.page_progress(h)
		var done := p.x == p.y
		var b := UI.button("%s %d/%d" % [h, p.x, p.y], "active" if h == page else "ghost", 11, 28)
		if done and h != page:
			b.add_theme_color_override("font_color", UI.LIME)
		b.pressed.connect(func():
			page = h
			build())
		tabs.add_child(b)
	add_child(tabs)
	var got: bool = Game.save.pages.has(page)
	add_child(UI.label("ページをうめると ◆%d%s" % [Game.PAGE_REWARD, "（受取済）" if got else ""], 10, UI.LIME if got else UI.SUB))

	var g := UI.grid(4, 6)
	for id in Game.ids_in_habitat(page):
		var c: Dictionary = Game.chars[id]
		var has: bool = Game.owned(id)
		var lines := ["No.%02d" % id if not has else c.name,
			UI.label(UI.stars(c.rarity), 9, UI.RARITY_COLORS[c.rarity] if has else UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)]
		var card = UI.card(id, not has, lines, func(): CharDetail.open(self, id, {"on_change": build}), 50)
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		g.add_child(card)
	add_child(UI.scroll(g))
