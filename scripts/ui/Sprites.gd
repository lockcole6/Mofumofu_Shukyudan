extends RefCounted
## キャラのピクセルアートを32x32でコード生成する。
## 球体の陰影（左上から光）＋色つきアウトライン。未発見はシルエット。

const S := 32
const EYE := Color("1c1426")
const CHEEK := Color("ff8fa8")
const SILHOUETTE := Color("39406a")
const LIGHT := Color(1.0, 0.97, 0.88)
const SHADE := Color(0.16, 0.1, 0.3)

static var _cache := {}
# 胴体の楕円（模様に陰影をつけるのに使う）
static var _b := Vector4(16, 19.5, 10.5, 10)


static func get_tex(c: Dictionary, silhouette := false) -> Texture2D:
	var k := "%d_%d" % [c.id, int(silhouette)]
	if not _cache.has(k):
		_cache[k] = ImageTexture.create_from_image(_draw(c.look, silhouette))
	return _cache[k]


static func tone(col: Color, k: float) -> Color:
	if k > 0.0:
		return col.lerp(LIGHT, 0.2 * k)
	return col.lerp(SHADE, 0.2 * -k)


static func _draw(look: Dictionary, silhouette: bool) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var body := Color(look.body)
	var belly := Color(look.belly)
	var acc := Color(look.accent)
	var wing := Color(look.get("wing", look.accent))
	var detail := Color(look.get("detail", look.accent))
	var ears: String = look.ears
	var ex: Array = look.extras
	var shape: String = look.shape

	match shape:
		"tall": _b = Vector4(16, 19, 9, 11.5)
		"wide": _b = Vector4(16, 21, 12.5, 8.5)
		"ball": _b = Vector4(16, 18, 11.5, 11.5)
		_: _b = Vector4(16, 19.5, 10.5, 10)
	var cx := _b.x
	var cy := _b.y
	var rx := _b.z
	var ry := _b.w
	var t := cy - ry            # 頭のてっぺん
	var ey := int(cy - 1)       # 目の高さ
	var eo := 5 if shape == "wide" else 4   # 目の間隔（中心から）

	# ---------------- 体の後ろ
	if "post" in ex:
		for y in range(6, 31, 3):
			for x in range(4, 28):
				_px(img, x, y, Color(1, 1, 1, 0.18))
		for x in range(6, 28, 3):
			for y in range(6, 31):
				_px(img, x, y, Color(1, 1, 1, 0.18))
		_rect(img, 1, 3, 30, 3, body)
		_rect(img, 1, 3, 3, 28, body)
		_rect(img, 28, 3, 3, 28, body)
		for x in [6, 12, 18, 24]:
			_rect(img, x, 3, 3, 3, acc)
		for y in [10, 17, 24]:
			_rect(img, 1, y, 3, 3, acc)
			_rect(img, 28, y, 3, 3, acc)
	if "mane" in ex:
		for i in 14:
			var a := TAU * i / 14.0
			_ell(img, cx + cos(a) * (rx + 0.5), cy - 1 + sin(a) * (ry + 0.5), 3.4, 3.4, acc)
	if "ninetails" in ex:
		for p in [[4.5, cy - 7, 3.2, 6.5], [2.5, cy + 1, 3, 5.5], [27.5, cy - 7, 3.2, 6.5], [29.5, cy + 1, 3, 5.5]]:
			_ell(img, p[0], p[1], p[2], p[3], body)
			_ell(img, p[0], p[1] - p[3] * 0.55, p[2] * 0.8, p[3] * 0.4, acc, false)
	if "wings" in ex:
		for side in [-1, 1]:
			var wx: float = 16 + side * (rx + 2.5)
			_ell(img, wx, cy - 3, 4.2, 6.5, wing)
			_tri(img, Vector2(wx, cy - 9), Vector2(wx + side * 6, cy - 12), Vector2(wx + side * 2, cy - 3), wing)
			for k in 3:
				_px(img, int(wx + side * (k - 1)), int(cy - 1 + k * 2), tone(wing, -2))
	if "bigtail" in ex:
		_ell(img, 26.5, cy - 4, 5, 8.5, acc)
		_ell(img, 27, cy - 6, 2.4, 4.5, tone(acc, 1.5), false)
	if "glowtail" in ex:
		_ell(img, 26, cy + 3, 3.5, 6, body)
		_ell(img, 27.5, cy - 3, 5, 5, Color(acc, 0.28), false)
		_ell(img, 27.5, cy - 3, 3, 3, acc, false)
	if "firetail" in ex:
		for i in 6:
			_px(img, 25 + i / 2, int(cy + 5 - i), tone(body, -1))
		_tri(img, Vector2(28, cy - 9), Vector2(25, cy - 1), Vector2(31, cy - 1), acc)
		_ell(img, 28, cy - 2.5, 1.8, 2.5, Color("ffe060"), false)
	if "flippers" in ex:
		_ell(img, cx - rx + 0.5, cy + 3, 2.4, 5, tone(body, -1))
		_ell(img, cx + rx - 0.5, cy + 3, 2.4, 5, tone(body, -1))
	if "claws" in ex:
		for side in [-1, 1]:
			var kx: float = 16 + side * (rx + 1.5)
			_ell(img, kx, cy - 3, 3.8, 3.8, body)
			_tri(img, Vector2(kx - 1, cy - 7.5), Vector2(kx + 1, cy - 7.5), Vector2(kx, cy - 3), Color(0, 0, 0, 0))
	if "ruff" in ex:
		for side in [-1, 1]:
			for k in 3:
				var yy := cy - 3 + k * 4
				_tri(img, Vector2(16 + side * (rx + 3.5), yy + 1), Vector2(16 + side * (rx - 3), yy - 2.5), Vector2(16 + side * (rx - 3), yy + 3), belly)
	if "quills" in ex:
		# 背中のトゲ（頭の上から後ろにかけて）
		for k in 11:
			var a := lerpf(PI * 1.05, PI * 1.95, k / 10.0)
			var base := Vector2(cx, cy) + Vector2(cos(a) * rx, sin(a) * ry)
			var tip := Vector2(cx, cy) + Vector2(cos(a) * (rx + 5), sin(a) * (ry + 5))
			var side := Vector2(-sin(a), cos(a)) * 2.2
			_tri(img, base - side, base + side, tip, tone(acc, -0.5 if k % 2 == 0 else 0.5))
	if "wool" in ex:
		# もこもこの毛（体のまわりにふくらみ）
		for k in 12:
			var a := TAU * k / 12.0
			_ell(img, cx + cos(a) * (rx - 0.5), cy + sin(a) * (ry - 0.5), 3.6, 3.6, tone(body, 0.6))
	if ears == "big":
		for side in [-1, 1]:
			_ell(img, 16 + side * 11, cy - 1, 5.5, 7.5, body)
			_ell(img, 16 + side * 11.3, cy - 1, 3.4, 5.3, acc, false)

	# ---------------- 耳（体の根元に重なる）
	match ears:
		"cat":
			_mirror_tri(img, Vector2(9, t - 4), Vector2(6.5, t + 5), Vector2(14.5, t + 2), body)
			_mirror_tri(img, Vector2(9.5, t - 1), Vector2(8.3, t + 4), Vector2(12.5, t + 2.5), belly)
		"fox":
			_mirror_tri(img, Vector2(7.5, t - 7), Vector2(5, t + 5), Vector2(14.5, t + 1), body)
			_mirror_tri(img, Vector2(8, t - 3), Vector2(6.8, t + 4), Vector2(11.5, t + 2), belly)
		"rabbit":
			for side in [-1, 1]:
				_ell(img, 16 + side * 4.2, t - 5, 2.7, 7.5, body)
				_ell(img, 16 + side * 4.2, t - 4.5, 1.1, 5.5, acc, false)
		"round":
			for side in [-1, 1]:
				_ell(img, 16 + side * 7.5, t + 2, 3.8, 3.8, body)
				_ell(img, 16 + side * 7.5, t + 2, 1.8, 1.8, tone(acc, 0), false)
		"small":
			for side in [-1, 1]:
				_ell(img, 16 + side * 6.5, t + 1.5, 2.6, 2.6, body)
				_ell(img, 16 + side * 6.5, t + 1.5, 1.1, 1.1, tone(body, -2), false)
		"mouse":
			for side in [-1, 1]:
				_ell(img, 16 + side * 8.5, t + 1, 5, 5, body)
				_ell(img, 16 + side * 8.5, t + 1, 3, 3, Color("ffc0c8"), false)
		"tufts":
			_mirror_tri(img, Vector2(8, t - 5), Vector2(7.5, t + 4), Vector2(13.5, t + 2), body)
		"fin":
			_tri(img, Vector2(18, t - 7), Vector2(12, t + 2), Vector2(20.5, t + 2), acc)
		"crest":
			_tri(img, Vector2(16, t - 7), Vector2(13, t + 1.5), Vector2(19, t + 1.5), detail)
			_mirror_tri(img, Vector2(12, t - 4), Vector2(11, t + 2), Vector2(15, t + 1.5), detail)
		"eyestalks":
			for side in [-1, 1]:
				_rect(img, int(16 + side * 4.5) - 1, int(t - 4), 2, 6, body)

	# ---------------- 体
	_ell(img, cx, cy, rx, ry, body)
	if not ("ball" in ex or "shell" in ex or "armor" in ex or "post" in ex):
		_ell(img, cx, cy + ry * 0.55, rx * 0.56, ry * 0.42, belly)
	if "floppy" == ears:
		for side in [-1, 1]:
			_ell(img, 16 + side * (rx - 1.5), t + 5, 2.8, 5.5, acc)

	# ---------------- 模様・特徴
	if "whitehead" in ex:
		for y in range(0, ey - 3):
			for x in S:
				_paint(img, x, y, acc)
	if "stripes" in ex:
		for p in [[15, 0], [16, 0], [12, 1], [19, 1]]:
			for k in 3:
				_paint(img, p[0], int(t) + 1 + p[1] + k, acc)
		for side in [-1, 1]:
			for yy in [cy - 2, cy + 1]:
				for k in 3:
					_paint(img, int(16 + side * (rx - 1 - k)), int(yy), acc)
	if "spots" in ex:
		for p in [[9, -4], [22, -5], [7, 2], [24, 3], [12, 7], [20, 7], [16, -7], [11, -7], [25, -1]]:
			_paint(img, p[0], int(cy + p[1]), acc)
			_paint(img, p[0] + 1, int(cy + p[1]), acc)
	if "spots_light" in ex:
		for p in [[9, -3], [23, -4], [8, 3], [24, 2], [14, -6], [19, -7]]:
			_paint(img, p[0], int(cy + p[1]), Color("fff6e8"))
	if "armor" in ex:
		for y in [int(t) + 2, int(t) + 3, int(t) + 6, int(t) + 7, int(cy + 4), int(cy + 5), int(cy + 8)]:
			for x in S:
				_paint(img, x, y, acc)
	if "scales" in ex:
		for p in [[8, -2], [10, 1], [8, 4], [24, -2], [22, 1], [24, 4]]:
			_paint(img, p[0], int(cy + p[1]), acc)
			_paint(img, p[0] + 1, int(cy + p[1]) + 1, acc)
	if "shell" in ex:
		_ell(img, cx, t + 4.5, rx * 0.95, 6, acc)
		for p in [[12, 3], [16, 2], [20, 3], [14, 6], [18, 6]]:
			_px(img, p[0], int(t) + p[1], tone(acc, -2))
			_px(img, p[0] + 1, int(t) + p[1], tone(acc, -2))
		_ell(img, cx, cy + ry * 0.55, rx * 0.56, ry * 0.42, belly)
	if "coral" in ex:
		for p in [[11, -3], [11, -2], [10, -4], [12, -4], [21, -2], [21, -3], [20, -4], [22, -5]]:
			_px(img, p[0], int(t) + p[1], acc)
	if "mushroom" in ex:
		_ell(img, 16, t - 0.5, 8.5, 4.8, acc)
		for p in [[13, -2], [18, -3], [20, 0], [11, 1], [16, 1]]:
			_px(img, p[0], int(t) + p[1], Color.WHITE)
			_px(img, p[0] + 1, int(t) + p[1], Color.WHITE)
	if "aurora" in ex:
		var cols := [acc, Color("7aa8ff"), Color("d880ff")]
		for i in 3:
			for x in S:
				var y := int(t + 3 + i * 1.5 + sin(x * 0.5) * 1.2)
				_paint(img, x, y, cols[i])
	if "ice" in ex:
		for p in [[10, 0], [16, -2], [22, 0]]:
			_tri(img, Vector2(p[0], t + p[1] - 5), Vector2(p[0] - 2.2, t + p[1] + 2), Vector2(p[0] + 2.2, t + p[1] + 2), acc)
		for p in [[9, 0], [23, 2], [11, 6]]:
			_paint(img, p[0], int(cy + p[1]), Color.WHITE)
	if "unihorn" in ex:
		_tri(img, Vector2(16, t - 10), Vector2(14.2, t + 1.5), Vector2(17.8, t + 1.5), acc)
		for k in 3:
			_px(img, 15 + k % 2, int(t) - 6 + k * 3, tone(acc, 2))
	if "dragonhorns" in ex:
		_mirror_tri(img, Vector2(9, t - 6), Vector2(9.5, t + 2), Vector2(13.5, t + 1), acc)
	if "antlers" in ex:
		for side in [-1, 1]:
			var ax := int(16 + side * 5)
			for y in range(int(t) - 6, int(t) + 2):
				_px(img, ax, y, acc)
			_px(img, ax + side, int(t) - 4, acc)
			_px(img, ax + side * 2, int(t) - 5, acc)
			_px(img, ax - side, int(t) - 2, acc)
	if "flowerhorn" in ex:
		for side in [-1, 1]:
			var ax := int(16 + side * 5)
			var br := tone(body, -2)
			for y in range(int(t) - 5, int(t) + 2):
				_px(img, ax, y, br)
			_px(img, ax + side, int(t) - 3, br)
			_px(img, ax + side * 2, int(t) - 4, br)
			for fp in [[ax, int(t) - 6], [ax + side * 3, int(t) - 5]]:
				_ell(img, fp[0] + 0.5, fp[1] + 0.5, 1.6, 1.6, acc, false)
				_px(img, fp[0], fp[1], Color("fff080"))
	if "spikes" in ex:
		for p in [[12, 0], [16, -1], [20, 0]]:
			_tri(img, Vector2(p[0], t + p[1] - 4), Vector2(p[0] - 2, t + p[1] + 2), Vector2(p[0] + 2, t + p[1] + 2), acc)
	if "bolt" in ex:
		for p in [[17, 2], [16, 3], [15, 4], [16, 4], [17, 4], [16, 5], [15, 6], [14, 7]]:
			_px(img, p[0], ey + p[1] + 1, acc)
	if "cloud" in ex:
		for p in [[7, 6, 4.5], [13, 8, 5], [19, 8, 5], [25, 6, 4.5]]:
			_ell(img, p[0], cy + p[1], p[2], p[2] * 0.8, Color("f4f8ff"))
	if "spout" in ex:
		for p in [[16, -2], [16, -3], [16, -4], [15, -5], [17, -5], [14, -6], [18, -6]]:
			_px(img, p[0], int(t) + p[1], Color("bfe6ff"))
	if "ball" in ex:
		for p in [[16, cy - 7.5, 3], [6.5, cy + 0.5, 2.6], [25.5, cy + 0.5, 2.6], [11, cy + 8, 2.4], [21, cy + 8, 2.4]]:
			_ell(img, p[0], p[1], p[2], p[2], acc)
	if "armband" in ex:
		for y in range(int(cy + 2), int(cy + 5)):
			for x in range(0, 11):
				_paint(img, x, y, acc)
		_px(img, 8, int(cy + 3), Color.WHITE)

	if "ramhorns" in ex:
		# くるっと巻いた角（左右）
		for side in [-1, 1]:
			var hc := Vector2(16 + side * 8.5, t + 4)
			for k in 20:
				var a := lerpf(-PI * 0.9, PI * 0.9, k / 19.0)
				var r := lerpf(4.2, 1.6, k / 19.0)
				var p := hc + Vector2(cos(a) * r * side, sin(a) * r)
				_ell(img, p.x, p.y, 1.3, 1.3, acc)
	if "grass" in ex:
		for p in [[10, 0], [13, -2], [16, -3], [19, -2], [22, 0]]:
			_tri(img, Vector2(p[0] - 1.6, t + 2), Vector2(p[0] + 1.6, t + 2), Vector2(p[0] + 0.5, t + p[1] - 3), tone(acc, 0.3 if p[0] % 2 == 0 else -0.3))
	if "card" in ex:
		# イエローカードを持っている（右下）
		_rect(img, 22, int(cy) - 1, 6, 8, acc)
		_rect(img, 23, int(cy), 4, 2, tone(acc, 1.5))
	# ---------------- 顔
	if "mask" in ex:
		for side in [-1, 1]:
			_ell(img, 16 + side * (eo + 0.5), ey + 0.5, 3.8, 2.8, detail, false)
	if "owleyes" in ex:
		for side in [-1, 1]:
			_ell(img, 16 + side * (eo + 0.5), ey + 0.5, 3.6, 3.6, belly, false)
			_ell(img, 16 + side * (eo + 0.5), ey + 0.5, 2.3, 2.3, acc, false)
	if "kitsune" in ex:
		for side in [-1, 1]:
			_px(img, 16 + side * eo, ey - 4, acc)
			_px(img, 16 + side * eo + side, ey - 4, acc)
			_px(img, 16 + side * (eo + 3), ey + 2, acc)
	if "tearmarks" in ex:
		for side in [-1, 1]:
			for k in 4:
				_px(img, 16 + side * (eo + 1), ey + 2 + k, acc)
	var eye_y := ey
	if ears == "eyestalks":
		eye_y = int(t - 4)
		for side in [-1, 1]:
			_ell(img, 16 + side * 4.5, eye_y + 0.5, 2.3, 2.3, Color.WHITE, false)
	for side in [-1, 1]:
		var x0: int = 16 + side * eo - (1 if side < 0 else 0)
		_rect(img, x0, eye_y - 1, 2, 3, EYE)
		_px(img, x0, eye_y - 1, Color.WHITE)
	if "snout" in ex:
		_ell(img, 16, ey + 3.5, 4, 2.4, tone(belly, 0.8), false)
		_rect(img, 15, ey + 2, 2, 1, EYE)
	if "nose" in ex:
		_rect(img, 15, ey + 2, 2, 1, EYE)
	if "throat" in ex:
		_ell(img, 16, ey + 4.5, 3, 1.8, acc, false)
	if "beak" in ex:
		_tri(img, Vector2(13.5, ey + 1.5), Vector2(18.5, ey + 1.5), Vector2(16, ey + 5), Color("f0a020") if "throat" in ex or "whitehead" in ex else acc)
	if "whistle" in ex:
		_rect(img, 18, ey + 3, 5, 3, acc)
		_px(img, 22, ey + 3, tone(acc, -2))
		_px(img, 19, ey + 3, Color.WHITE)
	if "trunk" in ex:
		_rect(img, 15, ey + 2, 3, 7, tone(body, -0.5))
		_rect(img, 17, ey + 8, 2, 2, tone(body, -0.5))
	if "whiskers" in ex:
		for side in [-1, 1]:
			for k in 3:
				_px(img, 16 + side * (8 + k), ey + 3, tone(body, -2.5))
				_px(img, 16 + side * (8 + k), ey + 5 - k / 2, tone(body, -2.5))
	var no_mouth := ["trunk", "beak", "snout", "nose", "whistle"].any(func(e): return e in ex)
	if not no_mouth:
		_px(img, 15, ey + 3, EYE.lerp(body, 0.35))
		_px(img, 16, ey + 3, EYE.lerp(body, 0.35))
	if not ["ball", "shell", "dragonhorns", "spikes", "post", "mask"].any(func(e): return e in ex):
		for side in [-1, 1]:
			var x0: int = 16 + side * (eo + 2) - (1 if side < 0 else 0)
			_rect(img, x0, ey + 2, 2, 1, CHEEK)

	if "tusks" in ex:
		for x in [13, 18]:
			_rect(img, x, ey + 3, 2, 6, acc)
			_px(img, x, ey + 8, tone(acc, -1))
	_outline(img)
	if silhouette:
		for y in S:
			for x in S:
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, SILHOUETTE)
	return img


# ---------------------------------------------------------------- 描画部品

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= S or y >= S:
		return
	if c.a <= 0.0:
		img.set_pixel(x, y, Color(0, 0, 0, 0))
	elif c.a < 1.0:
		var under := img.get_pixel(x, y)
		img.set_pixel(x, y, c if under.a == 0.0 else under.lerp(Color(c, 1.0), c.a))
	else:
		img.set_pixel(x, y, c)


## 体の上にだけ模様を描く（胴体の陰影に合わせる）
static func _paint(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= S or y >= S or img.get_pixel(x, y).a == 0.0:
		return
	var dx := (x + 0.5 - _b.x) / _b.z
	var dy := (y + 0.5 - _b.y) / _b.w
	img.set_pixel(x, y, tone(c, _light_level(dx, dy)))


static func _light_level(dx: float, dy: float) -> float:
	var d := dx * dx + dy * dy
	var lit := -0.6 * dx - 0.8 * dy
	if lit > 0.5 and d > 0.3:
		return 1.0
	if lit < -0.6 and d > 0.7:
		return -2.0
	if lit < -0.3 and d > 0.45:
		return -1.0
	return 0.0


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


## 楕円。shade=true なら左上から光が当たったような3段階の陰影
static func _ell(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color, shade := true) -> void:
	for y in S:
		for x in S:
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_px(img, x, y, tone(c, _light_level(dx, dy)) if shade else c)


static func _tri(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	for y in S:
		for x in S:
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := (p - b).cross(a - b)
			var d2 := (p - c).cross(b - c)
			var d3 := (p - a).cross(c - a)
			var neg := d1 < 0 or d2 < 0 or d3 < 0
			var pos := d1 > 0 or d2 > 0 or d3 > 0
			if not (neg and pos):
				_px(img, x, y, col)


static func _mirror_tri(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	_tri(img, a, b, c, col)
	_tri(img, Vector2(S - a.x, a.y), Vector2(S - b.x, b.y), Vector2(S - c.x, c.y), col)


## 隣の色を暗くした色つきアウトライン
static func _outline(img: Image) -> void:
	var src: Image = img.duplicate()
	for y in S:
		for x in S:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < S and n.y < S:
					var nc := src.get_pixel(n.x, n.y)
					if nc.a > 0.5:
						img.set_pixel(x, y, Color(nc, 1.0).lerp(Color("140c22"), 0.72))
						break
