extends RefCounted
## キャラのピクセルアートを20x20でコード生成する。
## 色違いはパレット差し替え（色相シフト）、未発見はシルエット。

const S := 20
const OUTLINE := Color("3a2a2a")
const EYE := Color("2a2020")
const CHEEK := Color("f4a0a0")
const SILHOUETTE := Color("4a4458")

static var _cache := {}


static func get_tex(c: Dictionary, shiny: bool, silhouette := false) -> Texture2D:
	var k := "%d_%d_%d" % [c.id, int(shiny), int(silhouette)]
	if not _cache.has(k):
		_cache[k] = ImageTexture.create_from_image(_draw(c.look, shiny, silhouette))
	return _cache[k]


static func shift(col: Color, shiny: bool) -> Color:
	if not shiny:
		return col
	if col.s < 0.15:
		# 白や黒は金色寄りに
		return Color.from_hsv(0.13, 0.5, maxf(col.v, 0.35))
	return Color.from_hsv(fposmod(col.h + 0.5, 1.0), minf(col.s * 1.1, 1.0), col.v)


static func _draw(look: Dictionary, shiny: bool, silhouette: bool) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var body := shift(Color(look.body), shiny)
	var belly := shift(Color(look.belly), shiny)
	var acc := shift(Color(look.accent), shiny)
	var ears: String = look.ears
	var extra: String = look.extra

	# --- 体の後ろ
	match extra:
		"wings", "dragon":
			_ellipse(img, 2.5, 10.5, 2.6, 3.8, acc)
			_ellipse(img, 17.5, 10.5, 2.6, 3.8, acc)
			for y in [9, 11, 13]:
				_px(img, 1, y, acc.darkened(0.2))
				_px(img, 18, y, acc.darkened(0.2))
		"mane":
			_ellipse(img, 10, 11.5, 8.6, 7.6, acc)
		"post":
			_rect(img, 1, 3, 18, 2, body)
			_rect(img, 1, 3, 2, 16, body)
			_rect(img, 17, 3, 2, 16, body)
			for x in [4, 8, 12, 16]:
				_rect(img, x, 3, 2, 2, acc)
			for y in [7, 11, 15]:
				_rect(img, 1, y, 2, 2, acc)
				_rect(img, 17, y, 2, 2, acc)
		"glow":
			for p in [[15, 16], [16, 16], [16, 15], [17, 15], [17, 14], [18, 13]]:
				_px(img, p[0], p[1], body)
			for p in [[17, 12], [18, 12], [18, 11], [17, 11]]:
				_px(img, p[0], p[1], acc)
	if ears == "big":
		_ellipse(img, 3.5, 11, 3.2, 4.2, body)
		_ellipse(img, 17.5 - 1, 11, 3.2, 4.2, body)
		_ellipse(img, 3.5, 11, 1.8, 2.8, acc)
		_ellipse(img, 16.5, 11, 1.8, 2.8, acc)

	# --- 耳（体の根元に重なる）
	match ears:
		"cat":
			_mirror(img, [[5, 4], [5, 5], [6, 5], [5, 6], [6, 6], [7, 6], [4, 7], [5, 7], [6, 7], [7, 7], [8, 7]], body)
			_mirror(img, [[6, 6]], belly)
		"fox":
			_mirror(img, [[4, 3], [4, 4], [5, 4], [4, 5], [5, 5], [6, 5], [4, 6], [5, 6], [6, 6], [7, 6], [3, 7], [4, 7], [5, 7], [6, 7], [7, 7], [8, 7]], body)
			_mirror(img, [[5, 5], [5, 6], [6, 6]], belly)
		"rabbit":
			_rect(img, 6, 0, 2, 8, body)
			_rect(img, 12, 0, 2, 8, body)
			_rect(img, 7, 1, 1, 5, acc)
			_rect(img, 12, 1, 1, 5, acc)
		"round":
			_ellipse(img, 5.5, 6.5, 2.3, 2.3, body)
			_ellipse(img, 14.5, 6.5, 2.3, 2.3, body)
			_ellipse(img, 5.5, 6.5, 1.1, 1.1, acc)
			_ellipse(img, 14.5, 6.5, 1.1, 1.1, acc)
		"small":
			_mirror(img, [[5, 5], [6, 5], [5, 6], [6, 6]], body)
		"tufts":
			_mirror(img, [[4, 3], [4, 4], [5, 4], [5, 5], [6, 5], [6, 6]], body)
		"fin":
			for p in [[10, 2], [10, 3], [11, 3], [9, 4], [10, 4], [11, 4], [9, 5], [10, 5], [11, 5], [12, 5]]:
				_px(img, p[0], p[1], acc)
		"horn2":
			_mirror(img, [[5, 1], [6, 2], [6, 3], [7, 4], [7, 5], [4, 2]], acc)
			_mirror(img, [[4, 6], [5, 6]], body)
		"crest":
			for p in [[10, 1], [9, 2], [10, 2], [11, 3], [10, 3], [9, 3], [8, 4], [9, 4], [10, 4], [11, 4], [12, 4]]:
				_px(img, p[0], p[1], acc)

	# --- 体
	if extra == "ball":
		_ellipse(img, 10, 11.5, 7.2, 7.2, body)
	else:
		_ellipse(img, 10, 12, 7, 6.5, body)
	if extra not in ["ball", "shell", "armor", "post"]:
		_ellipse(img, 10, 15.5, 4.2, 2.8, belly)

	# --- 模様・特徴
	match extra:
		"stripes":
			for p in [[8, 6], [8, 7], [9, 6], [10, 6], [11, 6], [11, 7], [4, 11], [15, 11]]:
				_px(img, p[0], p[1], acc)
		"mask":
			_ellipse(img, 7.5, 11.5, 2.2, 1.7, acc)
			_ellipse(img, 12.5, 11.5, 2.2, 1.7, acc)
		"spots":
			for p in [[5, 9], [14, 9], [4, 13], [15, 14], [8, 17], [12, 17], [10, 7], [6, 16], [13, 16], [9, 8]]:
				_px(img, p[0], p[1], acc)
		"shell":
			_ellipse(img, 10, 7.8, 7.4, 3.2, acc)
			for p in [[7, 7], [10, 6], [13, 7], [8, 9], [12, 9]]:
				_px(img, p[0], p[1], acc.darkened(0.35))
			_ellipse(img, 10, 15.5, 4.2, 2.8, belly)
		"horn":
			for p in [[10, 2], [9, 3], [10, 3], [9, 4], [10, 4], [9, 5], [10, 5]]:
				_px(img, p[0], p[1], acc)
		"armor":
			for y in [7, 9, 15, 17]:
				for x in S:
					if img.get_pixel(x, y).a > 0.0:
						img.set_pixel(x, y, acc)
		"bolt":
			for p in [[10, 13], [9, 14], [10, 14], [10, 15], [11, 15], [10, 16], [9, 17]]:
				_px(img, p[0], p[1], acc)
		"dragon":
			_mirror(img, [[6, 3], [6, 4], [7, 5], [7, 6]], acc)
		"trunk":
			_rect(img, 9, 13, 2, 5, body.darkened(0.08))
			_px(img, 11, 17, body.darkened(0.08))
		"ball":
			for p in [[9, 6], [10, 6], [9, 7], [10, 7], [4, 11], [4, 12], [5, 12], [15, 11], [15, 12], [14, 12], [8, 16], [9, 16], [10, 16], [11, 16], [9, 17], [10, 17]]:
				_px(img, p[0], p[1], acc)
		"post":
			_rect(img, 6, 16, 8, 1, acc)

	# --- 顔
	if extra == "mask":
		_px(img, 7, 11, Color.WHITE)
		_px(img, 12, 11, Color.WHITE)
		_px(img, 7, 12, EYE)
		_px(img, 12, 12, EYE)
	else:
		for p in [[7, 11], [7, 12], [12, 11], [12, 12]]:
			_px(img, p[0], p[1], EYE)
	if extra in ["beak"]:
		_rect(img, 9, 13, 2, 2, acc)
	elif extra not in ["trunk", "ball"]:
		_px(img, 9, 14, EYE.lightened(0.2))
		_px(img, 10, 14, EYE.lightened(0.2))
	if extra not in ["ball", "shell", "armor", "dragon", "bolt"]:
		_px(img, 5, 13, CHEEK)
		_px(img, 14, 13, CHEEK)

	_outline(img)
	if silhouette:
		for y in S:
			for x in S:
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, SILHOUETTE)
	return img


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < S and y < S:
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in S:
		for x in S:
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c)


static func _mirror(img: Image, pts: Array, c: Color) -> void:
	for p in pts:
		_px(img, p[0], p[1], c)
		_px(img, S - 1 - p[0], p[1], c)


static func _outline(img: Image) -> void:
	var src: Image = img.duplicate()
	for y in S:
		for x in S:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < S and n.y < S and src.get_pixel(n.x, n.y).a > 0.0:
					img.set_pixel(x, y, OUTLINE)
					break
