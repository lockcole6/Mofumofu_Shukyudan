extends Node
## ゲーム全体の状態とルール。UIはここを読んで表示し、ここの関数で状態を変える。

signal changed
signal toast(text: String)
signal error_toast(text: String)   # うまくいかなかったとき（音がちがう）

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 3
## 編成は列ごと。上から 攻・中・守・GK。GKは1人、ほかの列は最大4人。
const GRID_ROWS := ["攻", "中", "守", "GK"]
const ROW_MAX := {"攻": 3, "中": 3, "守": 3, "GK": 1}
const POS_LABEL := {"攻": "FW", "中": "MF", "守": "DF", "GK": "GK"}
## おまかせ編成の型（GK・DF・MF・FW の人数）
const PRESET_COUNT := 5
const PRESET_NAME_MAX := 5    # プリセット名の最大文字数（ボタンからはみ出さないように）
## おまかせで枠を埋める順番（先に埋める列ほど、コストの高い強い選手が入りやすい）
const AUTO_ORDER := {
	"攻撃型": ["攻", "攻", "中", "攻", "中", "GK", "守"],
	"バランス": ["GK", "中", "攻", "守", "中", "攻", "守"],
	"守備型": ["守", "GK", "守", "中", "守", "中", "攻"],
}
const AUTO_STYLES := {
	"攻撃型": {"GK": 1, "守": 1, "中": 2, "攻": 3},
	"バランス": {"GK": 1, "守": 2, "中": 2, "攻": 2},
	"守備型": {"GK": 1, "守": 3, "中": 2, "攻": 1},
}
const HABITATS := ["草原", "森", "海", "雪山", "空", "伝説", "蹴球"]
const TACTICS := ["攻める", "バランス", "守る"]
const TACTIC_DESC := {
	"攻める": "得点しやすいが、失点も増える",
	"バランス": "標準",
	"守る": "失点しにくいが、引き分けが増える",
}
const TEAM_SIZE := 7
const GACHA_COST := 10
const GACHA_RARE_COST := 120   # ★3以上確定ガチャ（1回）
const MAX_SLV := 5
const SELL_VALUE := {1: 2, 2: 6, 3: 20, 4: 50}
const PAGE_REWARD := 200
const STARTERS := [[4, "GK"], [3, "守"], [6, "守"], [1, "中"], [9, "中"], [2, "攻"], [5, "攻"]]

## ディビジョン（5部が一番下、1部が一番上）
const COST_CAP := {5: 12, 4: 14, 3: 16, 2: 18, 1: 20}
const DIV_BOOST := {5: 0.78, 4: 0.86, 3: 0.92, 2: 0.95, 1: 0.97}
const SEASON_REWARD := [150, 100, 70, 50, 40, 30]
const PROMOTE := 2
const RELEGATE := 2
const TEAM_NAMES := ["はらっぱFC", "ひだまりユナイテッド", "のんびりSC", "こもれびFC", "しおかぜシティ",
	"どんぐりローヴァーズ", "ふぶきアスレチック", "あおぞらウィングス", "かみなりFC", "もりのくまさんズ",
	"しっぽバルセロナ", "にくきゅうミラン", "ふわふわシティ", "かわうそユナイテッド", "つきよのオウルズ",
	"ぽかぽかレアル", "けだまFC", "もぐもぐローヴァーズ", "しろくまアスレチック", "ひなたぼっこSC"]

const SKILL_DESC := {
	"self_atk": "自分の攻撃力+{v}%",
	"self_def": "自分の守備力+{v}%",
	"team_atk": "チームの攻撃力+{v}%",
	"team_def": "チームの守備力+{v}%",
	"team_both": "チームの攻撃力と守備力+{v}%",
	"early_atk": "前半、チームの攻撃力+{v}%",
	"late_atk": "後半、チームの攻撃力+{v}%",
	"comeback": "後半に負けていたら、チームの攻撃力+{v}%",
	"finisher": "チームのシュート成功率+{v}%",
	"shrink": "相手のシュート成功率-{v}%",
	"opp_atk_down": "相手の攻撃力-{v}%",
	"chance": "各ハーフ{v}%の確率で攻撃チャンス+1",
	"steal": "各ハーフ{v}%の確率で相手のチャンス-1",
	"cancel": "{v}%の確率で最初の失点を取り消す",
}

var chars := {}          # id -> キャラデータ
var combos := []
var save := {}
var _lineup_cache := {}
var free_opp := {}       # フリーマッチの相手 {div, name, members}（セーブしない）  # "season_round_team" -> 出場メンバー


func _ready() -> void:
	randomize()
	_load_data()
	load_game()


# ---------------------------------------------------------------- データ

func _load_data() -> void:
	for c in JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json")):
		c.id = int(c.id)
		c.rarity = int(c.rarity)
		for s in ["spd", "pow", "pas", "def"]:
			c[s] = int(c[s])
		chars[c.id] = c
	for cb in JSON.parse_string(FileAccess.get_file_as_string("res://data/combos.json")):
		var ids := []
		for i in cb.ids:
			ids.append(int(i))
		cb.ids = ids
		combos.append(cb)


func ids_in_habitat(h: String) -> Array:
	var out := []
	for id in chars:
		if chars[id].habitat == h:
			out.append(id)
	out.sort_custom(func(a, b): return [chars[a].rarity, a] < [chars[b].rarity, b])
	return out


static func skill_value(base: float, lv: int) -> float:
	return base * (1.0 + 0.25 * (lv - 1))


func skill_text(id: int, lv: int) -> String:
	var s: Dictionary = chars[id].skill
	return SKILL_DESC[s.type].replace("{v}", _num(skill_value(s.base, lv)))


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


func combo_text(cb: Dictionary) -> String:
	return SKILL_DESC[cb.type].replace("{v}", _num(cb.value))


func combos_of(id: int) -> Array:
	return combos.filter(func(cb): return id in cb.ids)


# ---------------------------------------------------------------- 所持

func owned(id: int) -> bool:
	return save.roster.has(str(id))


func slv(id: int) -> int:
	return int(save.roster[str(id)].slv) if owned(id) else 1


func copies(id: int) -> int:
	return int(save.roster[str(id)].copies) if owned(id) else 0


func dex_total() -> int:
	return chars.size()


func dex_count() -> int:
	return save.roster.size()


## キャラを1体入手する。新規なら図鑑登録、被りならスキル強化素材になる。
func add_character(id: int) -> Dictionary:
	var k := str(id)
	var res := {"id": id, "new": false}
	if not save.roster.has(k):
		save.roster[k] = {"slv": 1, "copies": 0}
		res.new = true
		_check_pages()
	else:
		save.roster[k].copies = int(save.roster[k].copies) + 1
	return res


func skill_up_cost(id: int) -> int:
	return slv(id)


func can_skill_up(id: int) -> bool:
	return owned(id) and slv(id) < MAX_SLV and copies(id) >= skill_up_cost(id)


func skill_up(id: int) -> void:
	if not can_skill_up(id):
		return
	var r: Dictionary = save.roster[str(id)]
	r.copies = int(r.copies) - skill_up_cost(id)
	r.slv = int(r.slv) + 1
	save_game()


## スキルを最大にするのにまだ必要な数を引いた、余りの数
func surplus(id: int) -> int:
	var need := 0
	for l in range(slv(id), MAX_SLV):
		need += l
	return maxi(copies(id) - need, 0)


func sell(id: int, n: int) -> int:
	n = mini(n, copies(id))
	if n <= 0:
		return 0
	save.roster[str(id)].copies = copies(id) - n
	var gain: int = SELL_VALUE[chars[id].rarity] * n
	save.stones = int(save.stones) + gain
	save_game()
	return gain


func surplus_total() -> Vector2i:
	var n := 0
	var gain := 0
	for k in save.roster:
		var s := surplus(int(k))
		n += s
		gain += s * SELL_VALUE[chars[int(k)].rarity]
	return Vector2i(n, gain)


func sell_all_surplus() -> int:
	var total := 0
	for k in save.roster.keys():
		var s := surplus(int(k))
		if s > 0:
			save.roster[k].copies = copies(int(k)) - s
			total += s * SELL_VALUE[chars[int(k)].rarity]
	save.stones = int(save.stones) + total
	save_game()
	return total


func page_progress(h: String) -> Vector2i:
	var ids := ids_in_habitat(h)
	return Vector2i(ids.filter(func(id): return owned(id)).size(), ids.size())


func _check_pages() -> void:
	for h in HABITATS:
		if save.pages.has(h):
			continue
		var p := page_progress(h)
		if p.x == p.y:
			save.pages[h] = true
			save.stones = int(save.stones) + PAGE_REWARD
			toast.emit("図鑑「%s」コンプリート！ ガチャ石+%d" % [h, PAGE_REWARD])


# ---------------------------------------------------------------- セーブ

func _default_save() -> Dictionary:
	var s := {
		"version": SAVE_VERSION,
		"stones": 300,
		"pity": 0,
		"pulls": 0,
		"roster": {},
		"formation": [],
		"presets": [],     # 編成プリセット（5つ）。いま使っている番号は preset
		"preset": 0,
		"preset_names": [],
		"tutorial_done": false,
		"cleared": false,       # 1部優勝したことがあるか（エンディングを見た）
		"pages": {},
		"record": {"wins": 0, "draws": 0, "losses": 0, "best": 5, "titles": 0},
		"settings": {"speed": "normal", "bgm": 0.7, "sfx": 0.8},
		"debug": {"rates": [60.0, 30.0, 8.0, 2.0]},
		"league": {},
	}
	# はじめの選手は控えにいるだけ（配置はチュートリアルで自分でする）
	for st in STARTERS:
		s.roster[str(st[0])] = {"slv": 1, "copies": 0}
	s.presets = [s.formation.duplicate(true)]
	for i in PRESET_COUNT - 1:
		s.presets.append([])
	s.preset_names = _default_preset_names()
	return s


static func _default_preset_names() -> Array:
	var names := []
	for i in PRESET_COUNT:
		names.append("チーム%d" % (i + 1))
	return names


func load_game() -> void:
	save = _default_save()
	var data = null
	if FileAccess.file_exists(SAVE_PATH):
		data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary and int(data.get("version", 0)) == 2:
		_migrate_v2(data)
	if data is Dictionary:
		data = _intify(data)
	if data is Dictionary and int(data.get("version", 0)) == SAVE_VERSION:
		for k in data:
			save[k] = data[k]
		if not data.has("tutorial_done"):
			save.tutorial_done = true   # チュートリアルができる前から遊んでいたセーブ
		for f in save.formation:
			f.id = int(f.id)
		_fit_row_max()
	if save.presets.size() != PRESET_COUNT:
		save.presets = [save.formation.duplicate(true)]
		for i in PRESET_COUNT - 1:
			save.presets.append([])
	if save.settings.get("speed", "normal") not in ["slow", "normal", "fast"]:
		save.settings.speed = "fast"   # 「結果だけ」はなくした
	if save.get("preset_names", []).size() != PRESET_COUNT:
		save.preset_names = _default_preset_names()
	if save.league.is_empty():
		new_season(5)
	_lineup_cache.clear()


## JSONは数値をすべて小数で返すので、整数の値は int に戻す（勝点が 4.0 と出ないように）
## ただしガチャの排出の重みなど、小数を使う設定はそのまま
static func _intify(v):
	if v is Dictionary:
		for k in v:
			if k != "rates":
				v[k] = _intify(v[k])
	elif v is Array:
		for i in v.size():
			v[i] = _intify(v[i])
	elif v is float and v == floorf(v):
		return int(v)
	return v


## 1列の上限を4人から3人に減らしたので、あふれた選手は人数の少ない列へ移す
func _fit_row_max() -> void:
	for row in ["攻", "中", "守"]:
		while row_ids(row).size() > ROW_MAX[row]:
			var id: int = row_ids(row).back()
			var to := ""
			for r in ["中", "守", "攻"]:
				if r != row and row_ids(r).size() < ROW_MAX[r] and (to == "" or row_ids(r).size() < row_ids(to).size()):
					to = r
			for f in save.formation:
				if int(f.id) == id:
					if to == "":
						save.formation.erase(f)
					else:
						f.row = to
					break


## v2 は4x4のマス番号で持っていたので、列に直す（GKが複数なら余りは守へ）
func _migrate_v2(data: Dictionary) -> void:
	var conv := func(list: Array) -> Array:
		var sorted := list.duplicate()
		sorted.sort_custom(func(a, b): return int(a.cell) < int(b.cell))
		var out := []
		var gk := false
		for f in sorted:
			var row := row_of(int(f.cell))
			if row == "GK":
				if gk:
					row = "守"
				gk = true
			out.append({"id": int(f.id), "row": row})
		return out
	data.formation = conv.call(data.formation)
	if data.has("league") and data.league.has("teams"):
		for t in data.league.teams:
			if t.has("members"):
				t.members = conv.call(t.members)
	data.version = 3


func save_game() -> void:
	# いまの編成は、使っているプリセットにそのまま保存する
	if save.presets.size() == PRESET_COUNT:
		save.presets[int(save.preset)] = save.formation.duplicate(true)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(save))
	changed.emit()


func reset_game() -> void:
	var dbg = save.debug.duplicate(true)
	var st = save.settings.duplicate(true)
	save = _default_save()
	save.debug = dbg
	save.settings = st
	new_season(5)
	save_game()


# ---------------------------------------------------------------- ガチャ

func gacha_pool(rarity: int) -> Array:
	var out := []
	for id in chars:
		if chars[id].rarity == rarity and chars[id].source != "scout":
			out.append(id)
	return out


func gacha_cost(n: int, rare := false) -> int:
	return (GACHA_RARE_COST if rare else GACHA_COST) * n


func can_pull(n: int, rare := false) -> bool:
	return int(save.stones) >= gacha_cost(n, rare)


## rare=true は★3以上確定ガチャ（★3と★4を、排出の重みの比で）
func pull(n: int, rare := false) -> Array:
	if not can_pull(n, rare):
		return []
	save.stones = int(save.stones) - gacha_cost(n, rare)
	var results := []
	for i in n:
		results.append(_pull_one(rare))
	save_game()
	return results


func _pull_one(rare := false) -> Dictionary:
	save.pulls = int(save.pulls) + 1
	var rates: Array = save.debug.rates
	var r := _weighted_rarity(rates, 3 if rare else 1)
	var pool := gacha_pool(r)
	while pool.is_empty() and r > 1:
		r -= 1
		pool = gacha_pool(r)
	var res := add_character(pool.pick_random())
	res.rarity = r
	return res


func _weighted_rarity(rates: Array, min_r: int) -> int:
	var total := 0.0
	for i in range(min_r - 1, 4):
		total += float(rates[i])
	if total <= 0.0:
		return min_r
	var x := randf() * total
	for i in range(min_r - 1, 4):
		x -= float(rates[i])
		if x < 0.0:
			return i + 1
	return 4


# ---------------------------------------------------------------- 編成

static func row_of(cell: int) -> String:
	return GRID_ROWS[cell / 4]


func cost_cap() -> int:
	return COST_CAP[division()]


func formation_cost(formation = null) -> int:
	if formation == null:
		formation = save.formation
	var c := 0
	for f in formation:
		c += int(chars[int(f.id)].rarity)
	return c


## その列に並んでいる選手（並び順どおり）
func row_ids(row: String) -> Array:
	return save.formation.filter(func(f): return f.row == row).map(func(f): return int(f.id))


func row_of_id(id: int) -> String:
	for f in save.formation:
		if int(f.id) == id:
			return f.row
	return ""


## 守-中-攻 の人数（例 "2-2-2"）
func formation_name(entries: Array = []) -> String:
	if entries.is_empty():
		entries = formation_entries()
	var n := {"守": 0, "中": 0, "攻": 0}
	for p in entries:
		if n.has(p.row):
			n[p.row] += 1
	return "%d-%d-%d" % [n["守"], n["中"], n["攻"]]


func in_team(id: int) -> bool:
	return save.formation.any(func(f): return int(f.id) == id)


func formation_entries() -> Array:
	var out := []
	for f in save.formation:
		if owned(int(f.id)):
			out.append({"id": int(f.id), "row": f.row, "slv": slv(int(f.id))})
	return out


## 選手を列に置く（replace を指定するとその選手と交代）。置けないときは理由を返す。
## すでに出場中の選手なら列を移動する。GKの枠が埋まっていれば入れ替える。
func place(id: int, row: String, replace := 0) -> String:
	var from := row_of_id(id)
	if from != "" and replace != 0 and row_of_id(replace) != "":
		swap(id, replace)
		return ""
	var next: Array = save.formation.filter(func(f): return int(f.id) != id and int(f.id) != replace)
	var in_row := next.filter(func(f): return f.row == row)
	if in_row.size() >= ROW_MAX[row]:
		if row == "GK":
			# 今のGKは元いた列へ（ベンチからなら外れる）
			var old = in_row[0]
			next.erase(old)
			if from != "":
				next.append({"id": int(old.id), "row": from})
		else:
			return "%sは%d人まで" % [POS_LABEL[row], ROW_MAX[row]]
	next.append({"id": id, "row": row})
	if next.size() > TEAM_SIZE:
		return "出場できるのは%d体まで" % TEAM_SIZE
	if formation_cost(next) > cost_cap():
		return "コスト上限（%d）をこえてしまう" % cost_cap()
	save.formation = next
	save_game()
	return ""


func remove_from_team(id: int) -> void:
	save.formation = save.formation.filter(func(f): return int(f.id) != id)
	save_game()


## 出場中の2人の位置を入れ替える
func swap(a: int, b: int) -> void:
	for f in save.formation:
		if int(f.id) == a:
			f.id = b
		elif int(f.id) == b:
			f.id = a
	save_game()


## コスト上限の中で強そうな7体を、型（攻撃型・バランス・守備型）どおりに自動で並べる
func auto_formation(style := "バランス") -> void:
	var slots := []
	for row in AUTO_ORDER[style]:
		slots.append([row])
	var budget := cost_cap()
	var used := {}
	var out := []
	for i in slots.size():
		var row: String = slots[i][0]
		var remain := slots.size() - i - 1
		var best := 0
		var best_v := -1.0
		for k in save.roster:
			var id := int(k)
			if used.has(id) or chars[id].rarity > budget - remain:
				continue
			var p := {"id": id, "row": row, "slv": slv(id)}
			var v: float = (atk_val(p) if row in ["中", "攻"] else def_val(p)) + chars[id].rarity * 3.0
			if v > best_v:
				best_v = v
				best = id
		if best != 0:
			used[best] = true
			budget -= chars[best].rarity
			out.append({"id": best, "row": row})
	save.formation = out
	save_game()


## はじめの7体を基本の位置に並べる（テストとデバッグ用）
func place_starters() -> void:
	save.formation = []
	for st in STARTERS:
		save.formation.append({"id": st[0], "row": st[1]})
	save_game()


## プリセットを切り替える。空のプリセットは、いまの編成をコピーして始める
func select_preset(i: int) -> void:
	if i == int(save.preset):
		return
	save.presets[int(save.preset)] = save.formation.duplicate(true)
	save.preset = i
	var p: Array = save.presets[i]
	if p.is_empty():
		save.presets[i] = save.formation.duplicate(true)
	else:
		var out := []
		for f in p:
			if owned(int(f.id)) and not out.any(func(o): return o.id == int(f.id)):
				out.append({"id": int(f.id), "row": f.row})
		save.formation = out
		_fit_row_max()
	_lineup_cache.clear()
	save_game()


func preset_title(i: int) -> String:
	return str(save.preset_names[i])


## プリセットの名前を変える（前後の空白は消し、長すぎる分は切る。空なら初期の名前）
func rename_preset(i: int, text: String) -> void:
	var t := text.strip_edges().replace("\n", "")
	if t == "":
		t = "チーム%d" % (i + 1)
	save.preset_names[i] = t.substr(0, PRESET_NAME_MAX)
	save_game()


func preset_name(i: int) -> String:
	var p: Array = save.presets[i]
	if p.is_empty():
		return "－"
	var n := {"守": 0, "中": 0, "攻": 0}
	for f in p:
		if n.has(f.row):
			n[f.row] += 1
	return "%d-%d-%d" % [n["守"], n["中"], n["攻"]]


func active_combos(entries: Array) -> Array:
	var ids := entries.map(func(p): return int(p.id))
	return combos.filter(func(cb): return cb.ids.all(func(i): return i in ids))


# ---------------------------------------------------------------- 能力

static func fit(pos: String, row: String) -> float:
	if pos == row:
		return 1.0
	if pos == "GK" or row == "GK":
		return 0.5
	return 0.8


func _self_mul(p: Dictionary, kind: String) -> float:
	var c = chars[p.id]
	var m: float = fit(c.pos, p.row) * float(p.get("boost", 1.0))
	var s: Dictionary = c.skill
	var v := skill_value(s.base, int(p.get("slv", 1))) / 100.0
	if s.type == "self_" + kind:
		m *= 1.0 + v
	return m


func atk_val(p: Dictionary) -> float:
	var c = chars[p.id]
	return (c.spd + c.pow * 1.2 + c.pas) * _self_mul(p, "atk")


func def_val(p: Dictionary) -> float:
	var c = chars[p.id]
	var v: float = (c.def * 2.0 + c.pow * 0.5 + c.spd * 0.5) * _self_mul(p, "def")
	return v * 1.5 if p.row == "GK" else v


## スキルと連携をまとめた補正値
func team_mods(entries: Array) -> Dictionary:
	var m := {"team_atk": 0.0, "team_def": 0.0, "early_atk": 0.0, "late_atk": 0.0, "comeback": 0.0,
		"finisher": 0.0, "shrink": 0.0, "opp_atk_down": 0.0, "chance": [], "steal": [], "cancel": [], "combos": []}
	var effects := []
	for p in entries:
		var s: Dictionary = chars[p.id].skill
		effects.append({"type": s.type, "v": skill_value(s.base, int(p.get("slv", 1))),
			"name": "%s「%s」" % [chars[p.id].name, s.name]})
	for cb in active_combos(entries):
		m.combos.append(cb.name)
		effects.append({"type": cb.type, "v": float(cb.value), "name": "連携「%s」" % cb.name})
	for e in effects:
		match e.type:
			"team_both":
				m.team_atk += e.v
				m.team_def += e.v
			"chance", "steal", "cancel":
				m[e.type].append(e)
			_:
				if m.has(e.type):
					m[e.type] += e.v
	return m


func team_power(entries: Array) -> Dictionary:
	var m := team_mods(entries)
	var atk := 0.0
	var dfn := 0.0
	var has_gk := false
	for p in entries:
		if p.row in ["中", "攻"]:
			atk += atk_val(p)
		else:
			dfn += def_val(p)
			has_gk = has_gk or p.row == "GK"
	if not has_gk:
		dfn *= 0.6
	return {"raw_atk": atk, "atk": atk * (1.0 + m.team_atk / 100.0), "def": dfn * (1.0 + m.team_def / 100.0), "mods": m}


# ---------------------------------------------------------------- 試合

## 試合を数値判定で決める。イベント列と結果を返す。
func simulate(mine: Array, opp: Array, tactic := "バランス", opp_tactic := "バランス") -> Dictionary:
	var teams := [mine, opp]
	var tac := [tactic, opp_tactic]
	var base := []
	var mods := []
	for t in 2:
		var tp := team_power(teams[t])
		base.append(tp)
		mods.append(tp.mods)
	var chances := [6, 6]
	var def_mul := [1.0, 1.0]
	for t in 2:
		match tac[t]:
			"攻める":
				chances[t] += 2
				chances[1 - t] += 1
				def_mul[t] = 0.9
			"守る":
				chances[t] -= 2
				chances[1 - t] -= 2
				def_mul[t] = 1.1
	var goals := [0, 0]
	var stats := [[], []]
	for t in 2:
		for p in teams[t]:
			stats[t].append({"goals": 0, "rating": (atk_val(p) if p.row in ["中", "攻"] else def_val(p)) * randf_range(0.8, 1.2)})
	var events := []
	for t in 2:
		for cn in mods[t].combos:
			events.append({"min": 0, "team": t, "goal": false, "skill": true, "text": "連携「%s」発動！" % cn})
	var cancel_used := [false, false]
	for half in 2:
		var pw := []
		for t in 2:
			var o := 1 - t
			var am: float = 1.0 + mods[t].team_atk / 100.0
			if half == 0:
				am += mods[t].early_atk / 100.0
			else:
				am += mods[t].late_atk / 100.0
				if goals[t] < goals[o] and mods[t].comeback > 0.0:
					am += mods[t].comeback / 100.0
					events.append({"min": 46, "team": t, "goal": false, "skill": true, "text": "逆転をねらって攻撃力アップ！"})
			var atk: float = base[t].raw_atk * am * (1.0 - mods[o].opp_atk_down / 100.0)
			pw.append({"atk": atk, "def": base[t].def * def_mul[t]})
		for t in 2:
			var o := 1 - t
			var n: int = ceili(chances[t] / 2.0) if half == 0 else chances[t] / 2
			for e in mods[t].chance:
				if randf() * 100.0 < e.v:
					n += 1
					events.append({"min": half * 45 + randi_range(1, 44), "team": t, "goal": false, "skill": true, "kind": "chance", "text": "%s でチャンス！" % e.name})
			for e in mods[o].steal:
				if n > 1 and randf() * 100.0 < e.v:
					n -= 1
					events.append({"min": half * 45 + randi_range(1, 44), "team": o, "goal": false, "skill": true, "kind": "steal", "text": "%s でボール奪取！" % e.name})
			var prob: float = 0.24 * pw[t].atk / maxf(pw[o].def, 1.0)
			prob *= (1.0 + mods[t].finisher / 100.0) * (1.0 - mods[o].shrink / 100.0)
			prob = clampf(prob, 0.04, 0.75)
			for c in maxi(n, 0):
				if randf() >= prob:
					continue
				var minute := half * 45 + randi_range(1, 45)
				if not cancel_used[o] and not mods[o].cancel.is_empty():
					cancel_used[o] = true
					var saved := false
					for e in mods[o].cancel:
						if randf() * 100.0 < e.v:
							saved = true
							events.append({"min": minute, "team": o, "goal": false, "skill": true, "kind": "cancel", "text": "%s で失点を取り消した！" % e.name})
							break
					if saved:
						continue
				var si := _pick_scorer(teams[t])
				goals[t] += 1
				stats[t][si].goals += 1
				stats[t][si].rating += 30.0
				events.append({"min": minute, "team": t, "goal": true, "kind": "goal", "scorer": si, "text": "%s のゴール！" % chars[teams[t][si].id].name})
	events.sort_custom(func(a, b): return a.min < b.min)
	var outcome := "draw"
	if goals[0] > goals[1]:
		outcome = "win"
	elif goals[0] < goals[1]:
		outcome = "lose"
	# 相手のMVPほどスカウトしやすい。ガチャ限定はスカウト不可
	var mvp := 0
	for i in stats[1].size():
		if stats[1][i].rating > stats[1][mvp].rating:
			mvp = i
	var rates := []
	for i in opp.size():
		var c = chars[opp[i].id]
		var r: int = 70 - (c.rarity - 1) * 15
		if stats[1][i].goals > 0:
			r += 15
		if i == mvp:
			r = 100
		rates.append(0 if c.source == "gacha" else clampi(r, 10, 100))
	return {"goals": goals, "events": events, "outcome": outcome, "mvp": mvp, "scout_rates": rates}


func _pick_scorer(team: Array) -> int:
	var weights := []
	var total := 0.0
	for p in team:
		var c = chars[p.id]
		var w := 0.0
		match p.row:
			"攻": w = (c.pow + c.spd) * 3.0
			"中": w = (c.pow + c.spd) * 1.0
			"守": w = 1.0
		weights.append(w)
		total += w
	if total <= 0.0:
		return randi() % team.size()
	var x := randf() * total
	for i in weights.size():
		x -= weights[i]
		if x < 0.0:
			return i
	return weights.size() - 1


func try_scout(member: Dictionary, rate: int) -> Dictionary:
	var res := {"ok": randi_range(1, 100) <= rate}
	if res.ok:
		res.merge(add_character(member.id))
	save_game()
	return res


# ---------------------------------------------------------------- リーグ

func division() -> int:
	return int(save.league.division)


func new_season(div: int) -> void:
	var names := TEAM_NAMES.duplicate()
	names.shuffle()
	var teams := [{"name": "もふもふ蹴球団", "player": true}]
	for i in 5:
		teams.append({"name": names[i], "members": _make_ai_members(div)})
	# 総当たりの組み合わせ（サークル方式）
	var idx := [0, 1, 2, 3, 4, 5]
	var schedule := []
	for r in 5:
		var pairs := []
		for i in 3:
			pairs.append([idx[i], idx[5 - i]])
		schedule.append(pairs)
		idx.insert(1, idx.pop_back())
	var table := []
	for i in 6:
		table.append({"pts": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0})
	var season: int = int(save.league.get("season", 0)) + 1
	save.league = {"division": div, "season": season, "round": 0, "teams": teams, "schedule": schedule, "table": table}
	_lineup_cache.clear()


func _make_ai_members(div: int) -> Array:
	var templates := [[1, 2, 2, 2], [1, 3, 2, 1], [1, 2, 3, 1], [1, 1, 3, 2], [1, 3, 1, 2]]
	var t: Array = templates.pick_random()   # GK, 守, 中, 攻 の人数
	var rows := ["GK", "守", "中", "攻"]
	var slots := []   # [pos]
	for i in 4:
		for n in t[i]:
			slots.append([rows[i]])
	var rar := []
	for s in slots:
		rar.append(1)
	var budget: int = COST_CAP[div] - randi_range(2, 4) - slots.size()
	var max_r := 3 if div <= 2 else 2
	for step in 60:
		if budget <= 0:
			break
		var i := randi() % slots.size()
		if rar[i] < max_r:
			rar[i] += 1
			budget -= 1
	var used := {}
	var out := []
	for i in slots.size():
		var id := _pick_ai_char(slots[i][0], rar[i], used)
		used[id] = true
		out.append({"id": id, "row": slots[i][0]})
	return out


func _pick_ai_char(pos: String, r: int, used: Dictionary) -> int:
	for strict in [true, false]:
		var pool := []
		for id in chars:
			var c = chars[id]
			if used.has(id) or c.rarity != r or c.rarity == 4:
				continue
			if strict and c.pos != pos:
				continue
			pool.append(id)
		if not pool.is_empty():
			return pool.pick_random()
	return _pick_ai_char(pos, r - 1, used) if r > 1 else 1


func ai_slv() -> int:
	return 2 if division() == 1 else 1


## 今節の対戦相手（チーム番号）
func opponent_index(round_i: int = -1) -> int:
	if round_i < 0:
		round_i = int(save.league.round)
	for pair in save.league.schedule[round_i]:
		if int(pair[0]) == 0:
			return int(pair[1])
		if int(pair[1]) == 0:
			return int(pair[0])
	return 1


## 出場メンバー
func lineup(team_i: int) -> Array:
	var key := "%d_%d_%d" % [save.league.season, save.league.round, team_i]
	if _lineup_cache.has(key):
		return _lineup_cache[key]
	var team: Dictionary = save.league.teams[team_i]
	var out := []
	for m in team.members:
		out.append({"id": int(m.id), "row": m.row, "slv": ai_slv(), "boost": DIV_BOOST[division()]})
	_lineup_cache[key] = out
	return out


func season_over() -> bool:
	return int(save.league.round) >= 5


## 自分の試合と、同じ節の他の試合をまとめて行う
## 作戦はなくした（フォーメーションで攻守のバランスが決まる）。相手の作戦はランダム
func play_round() -> Dictionary:
	var L: Dictionary = save.league
	var opp_i := opponent_index()
	var opp := lineup(opp_i)
	var res := simulate(formation_entries(), opp, "バランス", TACTICS.pick_random())
	_record(0, opp_i, res.goals)
	var others := []
	for pair in L.schedule[int(L.round)]:
		var a := int(pair[0])
		var b := int(pair[1])
		if a == 0 or b == 0:
			continue
		var r := simulate(lineup(a), lineup(b))
		_record(a, b, r.goals)
		others.append({"a": a, "b": b, "goals": r.goals})
	var rec: Dictionary = save.record
	var reward := 5
	match res.outcome:
		"win":
			reward = 20 + (5 - division()) * 10
			rec.wins = int(rec.wins) + 1
		"draw":
			reward = 10 + (5 - division()) * 3
			rec.draws = int(rec.draws) + 1
		_:
			rec.losses = int(rec.losses) + 1
	save.stones = int(save.stones) + reward
	L.round = int(L.round) + 1
	save_game()
	res.reward = reward
	res.opp_i = opp_i
	res.opp = opp
	res.opp_name = L.teams[opp_i].name
	res.others = others
	return res


# ---------------------------------------------------------------- フリーマッチ
## 順位に関係なく、好きな強さ（5部〜1部）の相手と戦う。勝てばスカウトでき、ガチャ石も少しもらえる

func free_opponent(div: int, refresh := false) -> Dictionary:
	if refresh or free_opp.is_empty() or int(free_opp.div) != div:
		free_opp = {"div": div, "name": TEAM_NAMES.pick_random(), "members": _make_ai_members(div)}
	return free_opp


func free_lineup() -> Array:
	var div: int = free_opp.div
	return free_opp.members.map(func(m): return {"id": int(m.id), "row": m.row,
		"slv": 2 if div == 1 else 1, "boost": DIV_BOOST[div]})


func play_free() -> Dictionary:
	var opp := free_lineup()
	var div: int = free_opp.div
	var res := simulate(formation_entries(), opp, "バランス", TACTICS.pick_random())
	var reward := 0
	match res.outcome:
		"win": reward = 5 + (5 - div) * 3
		"draw": reward = 2
	save.stones = int(save.stones) + reward
	save_game()
	res.reward = reward
	res.opp = opp
	res.opp_name = free_opp.name
	res.others = []
	res.free = true
	free_opp = {}   # 次は新しい相手
	return res


func _record(a: int, b: int, g: Array) -> void:
	var T: Array = save.league.table
	T[a].gf = int(T[a].gf) + g[0]
	T[a].ga = int(T[a].ga) + g[1]
	T[b].gf = int(T[b].gf) + g[1]
	T[b].ga = int(T[b].ga) + g[0]
	if g[0] > g[1]:
		T[a].w = int(T[a].w) + 1
		T[a].pts = int(T[a].pts) + 3
		T[b].l = int(T[b].l) + 1
	elif g[0] < g[1]:
		T[b].w = int(T[b].w) + 1
		T[b].pts = int(T[b].pts) + 3
		T[a].l = int(T[a].l) + 1
	else:
		for i in [a, b]:
			T[i].d = int(T[i].d) + 1
			T[i].pts = int(T[i].pts) + 1


## 順位順のチーム番号
func standings() -> Array:
	var T: Array = save.league.table
	var order := [0, 1, 2, 3, 4, 5]
	order.sort_custom(func(a, b):
		var ka := [int(T[a].pts), int(T[a].gf) - int(T[a].ga), int(T[a].gf), -a]
		var kb := [int(T[b].pts), int(T[b].gf) - int(T[b].ga), int(T[b].gf), -b]
		return ka > kb)
	return order


## 順位に応じた行き先：up / down / champion / ""
func zone(rank: int) -> String:
	var d := division()
	if rank == 1 and d == 1:
		return "champion"
	if rank <= PROMOTE and d > 1:
		return "up"
	if rank > 6 - RELEGATE and d < 5:
		return "down"
	return ""


## シーズンを締めて、昇格・降格を決め、次のシーズンを始める
func end_season() -> Dictionary:
	var d := division()
	var rank := standings().find(0) + 1
	var z := zone(rank)
	var reward := int(SEASON_REWARD[rank - 1] * (1.0 + (5 - d) * 0.25))
	var next := d
	match z:
		"up": next = d - 1
		"down": next = d + 1
		"champion":
			reward += 500
			save.record.titles = int(save.record.titles) + 1
	save.record.best = mini(int(save.record.best), next)
	save.stones = int(save.stones) + reward
	var summary := {"rank": rank, "zone": z, "reward": reward, "from": d, "to": next}
	new_season(next)
	save_game()
	return summary
