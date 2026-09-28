extends Node
## 開発用：全キャラのドット絵を1枚に並べて tools/shots/sheet.png に保存する

const Sprites = preload("res://scripts/ui/Sprites.gd")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/shots"))
	var ids: Array = Game.chars.keys()
	ids.sort_custom(func(a, b): return [Game.chars[a].rarity, a] < [Game.chars[b].rarity, b])
	var cols := 8
	var sc := 4
	var cell := 32 * sc + 8
	var sheet := Image.create(cols * cell, ceili(ids.size() / float(cols)) * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("141a2e"))
	for i in ids.size():
		var img: Image = Sprites.get_tex(Game.chars[ids[i]]).get_image()
		img.resize(32 * sc, 32 * sc, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(0, 0, 32 * sc, 32 * sc), Vector2i((i % cols) * cell + 4, (i / cols) * cell + 4))
	sheet.save_png(ProjectSettings.globalize_path("res://tools/shots/sheet.png"))
	get_tree().quit()
