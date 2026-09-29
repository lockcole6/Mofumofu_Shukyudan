extends Control
## コードで描く小さなアイコン。kind で種類を選ぶ。
## ball / team / book / gacha / gear / info / swap / flag

var kind := "ball"
var color := Color.WHITE


static func make(k: String, c: Color, s := 22) -> Control:
	var i = load("res://scripts/ui/Icon.gd").new()
	i.kind = k
	i.color = c
	i.custom_minimum_size = Vector2(s, s)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2
	var c := o + Vector2(s, s) / 2
	var w := maxf(1.6, s * 0.09)
	match kind:
		"ball":
			draw_arc(c, s * 0.44, 0, TAU, 32, color, w, true)
			var pent := PackedVector2Array()
			for k in 5:
				var a := -PI / 2 + TAU * k / 5.0
				pent.append(c + Vector2(cos(a), sin(a)) * s * 0.16)
			draw_colored_polygon(pent, color)
			for k in 5:
				var a := -PI / 2 + TAU * k / 5.0
				draw_line(c + Vector2(cos(a), sin(a)) * s * 0.16, c + Vector2(cos(a), sin(a)) * s * 0.42, color, w * 0.8, true)
		"team":
			for p in [[-0.26, 0.8], [0.26, 0.8], [0.0, 1.0]]:
				var hx: float = c.x + p[0] * s
				var sc: float = p[1]
				draw_circle(Vector2(hx, c.y - s * 0.14 * sc), s * 0.12 * sc, color)
				var body := PackedVector2Array()
				for k in 9:
					var a := PI + PI * k / 8.0
					body.append(Vector2(hx, c.y + s * 0.3) + Vector2(cos(a), sin(a) * 0.9) * s * 0.2 * sc)
				draw_colored_polygon(body, color)
		"book":
			for side in [-1, 1]:
				var pts := PackedVector2Array([c + Vector2(0, -s * 0.28), c + Vector2(side * s * 0.42, -s * 0.34),
					c + Vector2(side * s * 0.42, s * 0.3), c + Vector2(0, s * 0.36)])
				draw_polyline(pts + PackedVector2Array([pts[0]]), color, w, true)
				for k in 3:
					var y := -s * 0.16 + k * s * 0.13
					draw_line(c + Vector2(side * s * 0.1, y), c + Vector2(side * s * 0.32, y - s * 0.03), color, w * 0.6, true)
		"gacha":
			draw_set_transform(c, -PI / 4)
			var r := s * 0.18
			draw_arc(Vector2(0, -s * 0.14), r, PI, TAU, 16, color, w, true)
			draw_arc(Vector2(0, s * 0.14), r, 0, PI, 16, color, w, true)
			draw_line(Vector2(-r, -s * 0.14), Vector2(-r, s * 0.14), color, w, true)
			draw_line(Vector2(r, -s * 0.14), Vector2(r, s * 0.14), color, w, true)
			draw_rect(Rect2(-r, -w / 2, r * 2, w), color)
			var top := PackedVector2Array()
			for k in 9:
				var a := PI + PI * k / 8.0
				top.append(Vector2(0, -s * 0.14) + Vector2(cos(a), sin(a)) * r)
			top.append(Vector2(r, 0))
			top.append(Vector2(-r, 0))
			draw_colored_polygon(top, Color(color, 0.55))
			draw_set_transform(Vector2.ZERO)
		"gear":
			for k in 8:
				var a := TAU * k / 8.0
				draw_set_transform(c, a)
				draw_rect(Rect2(-s * 0.07, -s * 0.46, s * 0.14, s * 0.18), color)
			draw_set_transform(Vector2.ZERO)
			draw_circle(c, s * 0.32, color)
			draw_circle(c, s * 0.13, Color("0c0f1d"))
		"info":
			draw_arc(c, s * 0.42, 0, TAU, 32, color, w, true)
			draw_circle(c + Vector2(0, -s * 0.2), s * 0.06, color)
			draw_rect(Rect2(c.x - s * 0.045, c.y - s * 0.07, s * 0.09, s * 0.3), color)
		"swap":
			var a1 := c + Vector2(-s * 0.36, -s * 0.13)
			var b1 := c + Vector2(s * 0.3, -s * 0.13)
			draw_line(a1, b1, color, w * 1.2, true)
			draw_colored_polygon(PackedVector2Array([b1 + Vector2(s * 0.12, 0), b1 + Vector2(-s * 0.06, -s * 0.13), b1 + Vector2(-s * 0.06, s * 0.13)]), color)
			var a2 := c + Vector2(s * 0.36, s * 0.15)
			var b2 := c + Vector2(-s * 0.3, s * 0.15)
			draw_line(a2, b2, color, w * 1.2, true)
			draw_colored_polygon(PackedVector2Array([b2 + Vector2(-s * 0.12, 0), b2 + Vector2(s * 0.06, -s * 0.13), b2 + Vector2(s * 0.06, s * 0.13)]), color)
		"flag":
			draw_line(c + Vector2(-s * 0.28, -s * 0.38), c + Vector2(-s * 0.28, s * 0.4), color, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.26, -s * 0.36), c + Vector2(s * 0.34, -s * 0.24),
				c + Vector2(s * 0.08, -s * 0.08), c + Vector2(s * 0.34, s * 0.06), c + Vector2(-s * 0.26, s * 0.06)]), color)
