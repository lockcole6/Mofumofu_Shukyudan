extends Control
## 編成画面のピッチ。奥が少しすぼまった芝のコートを描き、子の選手（PitchPlayer）を列ごとに並べる。
## 上から FW・MF・DF・GK。同じ列の選手は人数に合わせて左右対称に並ぶ。

const ROW_V := {"攻": 0.13, "中": 0.39, "守": 0.63, "GK": 0.86}
const GAP := {1: 0.0, 2: 0.34, 3: 0.3}
const TOP_W := 0.84        # 奥の幅（手前を1とした割合）

var players := {}          # id -> PitchPlayer
var lineup: Array = []     # 並べる選手 [{id, row}]（相手チームを表示するときなど）。空なら自分の編成


func _ready() -> void:
	resized.connect(layout)
	clip_contents = true


## 0〜1 のコート座標を画面の座標へ（奥ほど幅が狭い）
func to_px(u: float, v: float) -> Vector2:
	var w := size.x * lerpf(TOP_W, 1.0, v)
	return Vector2(size.x / 2 + (u - 0.5) * w, v * size.y)


## 画面の y から、どの列の帯か
func row_at(p: Vector2) -> String:
	var v := p.y / maxf(size.y, 1.0)
	if v < 0.26:
		return "攻"
	if v < 0.51:
		return "中"
	if v < 0.75:
		return "守"
	return "GK"


func layout() -> void:
	# ピッチが低いとき（画面が短い端末）は選手を小さくして重ならないようにする
	var sc := clampf(size.y / 360.0, 0.55, 1.0)
	for row in ROW_V:
		var ids: Array = Game.row_ids(row) if lineup.is_empty() else lineup.filter(func(m): return m.row == row).map(func(m): return m.id)
		var n := ids.size()
		for i in n:
			var p: Control = players.get(ids[i])
			if p == null:
				continue
			var u: float = 0.5 + (i - (n - 1) / 2.0) * GAP.get(n, 0.22)
			var c := to_px(u, ROW_V[row])
			p.scale = Vector2(sc, sc)
			p.position = c - Vector2(p.size.x / 2, p.size.y * 0.42) * sc


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0f2a22"))
	# 芝のしま模様
	var bands := 10
	for b in bands:
		var v0 := float(b) / bands
		var v1 := float(b + 1) / bands
		var col := Color("2f8d3b") if b % 2 == 0 else Color("2a7f35")
		draw_colored_polygon(PackedVector2Array([to_px(0, v0), to_px(1, v0), to_px(1, v1), to_px(0, v1)]), col)
	# 下の方を少し明るく
	draw_colored_polygon(PackedVector2Array([to_px(0, 0.55), to_px(1, 0.55), to_px(1, 1), to_px(0, 1)]),
		Color(1, 1, 1, 0.03))
	var line := Color(1, 1, 1, 0.55)
	var lw := 2.0
	_poly([to_px(0.02, 0.0), to_px(0.98, 0.0), to_px(0.98, 1.0), to_px(0.02, 1.0)], line, lw, true)
	# 相手側のペナルティエリアの端（上）
	_poly([to_px(0.3, 0.0), to_px(0.3, 0.06), to_px(0.7, 0.06), to_px(0.7, 0.0)], line, lw)
	_arc(0.5, 0.06, 0.1, 0.0, PI, line, lw)
	# センターライン・センターサークル
	_poly([to_px(0.02, 0.27), to_px(0.98, 0.27)], line, lw)
	_arc(0.5, 0.27, 0.13, 0.0, TAU, line, lw)
	draw_circle(to_px(0.5, 0.27), 3, line)
	# 自陣のペナルティエリア・ゴールエリア（下）
	_poly([to_px(0.2, 1.0), to_px(0.2, 0.74), to_px(0.8, 0.74), to_px(0.8, 1.0)], line, lw)
	_poly([to_px(0.36, 1.0), to_px(0.36, 0.9), to_px(0.64, 0.9), to_px(0.64, 1.0)], line, lw)
	_arc(0.5, 0.74, 0.1, PI, TAU, line, lw)


func _poly(pts: Array, col: Color, w: float, closed := false) -> void:
	var p := PackedVector2Array(pts)
	if closed:
		p.append(pts[0])
	draw_polyline(p, col, w, true)


## コート座標で円弧を描く（奥行きでつぶれる）
func _arc(u: float, v: float, r: float, a0: float, a1: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for k in 33:
		var a := lerpf(a0, a1, k / 32.0)
		pts.append(to_px(u + cos(a) * r, v + sin(a) * r * 0.55))
	draw_polyline(pts, col, w, true)
