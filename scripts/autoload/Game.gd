extends Node
## ゲーム全体の状態とルール。UIはここを読んで表示し、ここの関数で状態を変える。

signal changed
signal toast(text: String)

const SAVE_PATH := "user://save.json"
const ROWS := ["GK", "守", "中", "攻"]
const HABITATS := ["草原", "森", "海", "雪山", "空", "伝説"]
const TACTICS := ["攻める", "バランス", "守る"]
const TACTIC_DESC := {
	"攻める": "得点しやすいが、失点も増える",
	"バランス": "標準",
	"守る": "失点しにくいが、引き分けが増える",
}
const GACHA_COST := 10
const MAX_LV := 5
const PAGE_REWARD_NORMAL := 200
const PAGE_REWARD_SHINY := 500
const STARTER_IDS := [4, 3, 6, 1, 9, 2, 5]
const STARTER_ROWS := ["GK", "守", "守", "中", "中", "攻", "攻"]

const LEAGUES := [
	{"name": "はらっぱリーグ", "lv": 1, "boost": 0.8, "pool": [1, 4, 5, 6, 7, 11, 14],
		"teams": ["はらっぱFC", "ひだまりユナイテッド", "のんびりSC"], "desc": "草原の仲間たち。まずはここから"},
	{"name": "もりとうみリーグ", "lv": 2, "boost": 1.0, "pool": [1, 2, 3, 8, 9, 10, 13],
		"teams": ["こもれびFC", "しおかぜシティ", "どんぐりローヴァーズ"], "desc": "森と海のチーム。夜は顔ぶれが変わる"},
	{"name": "ゆきやまそらリーグ", "lv": 3, "boost": 1.2, "pool": [3, 7, 9, 11, 12, 14, 15],
		"teams": ["ふぶきアスレチック", "あおぞらウィングス", "かみなりFC"], "desc": "雪山と空の強豪。上級者向け"},
]

var chars := {}          # id -> キャラデータ
var save := {}
var opponents := {}      # リーグ番号 -> {"name", "members": [{id, shiny, lv, row}]}


func _ready() -> void:
	randomize()
	_load_chars()
	load_game()


# ---------------------------------------------------------------- データ

func _load_chars() -> void:
	var f := FileAccess.open("res://data/characters.json", FileAccess.READ)
	var arr: Array = JSON.parse_string(f.get_as_text())
	for c in arr:
		c.id = int(c.id)
		c.rarity = int(c.rarity)
		for s in ["spd", "pow", "pas", "def"]:
			c[s] = int(c[s])
		chars[c.id] = c


func ids_in_habitat(h: String) -> Array:
	var out := []
	for id in chars:
		if chars[id].habitat == h:
			out.append(id)
	out.sort()
	return out


static func key(id: int, shiny: bool) -> String:
	return "%d_%d" % [id, 1 if shiny else 0]


static func parse_key(k: String) -> Dictionary:
	var p := k.split("_")
	return {"id": int(p[0]), "shiny": p[1] == "1"}


func owned(id: int, shiny: bool) -> bool:
	return save.roster.has(key(id, shiny))


func lv_of(k: String) -> int:
	return int(save.roster[k].lv) if save.roster.has(k) else 1


func dex_total() -> int:
	return chars.size() * 2


func dex_count() -> int:
	return save.roster.size()


# ---------------------------------------------------------------- セーブ

func _default_save() -> Dictionary:
	var s := {
		"stones": 300,
		"fragments": 0,
		"pity": 0,
		"pulls": 0,
		"wins": 0, "draws": 0, "losses": 0,
		"roster": {},
		"formation": [],
		"tactic": "バランス",
		"pages": {},
		"debug": {"rates": [60.0, 30.0, 8.0, 2.0], "shiny": 2.0, "pity": 50, "time": "auto"},
	}
	for i in STARTER_IDS.size():
		var k := key(STARTER_IDS[i], false)
		s.roster[k] = {"lv": 1}
		s.formation.append({"k": k, "row": STARTER_ROWS[i]})
	return s


func load_game() -> void:
	save = _default_save()
	if FileAccess.file_exists(SAVE_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if data is Dictionary:
			for k in data:
				save[k] = data[k]
			var d: Dictionary = _default_save().debug
			for k in d:
				if not save.debug.has(k):
					save.debug[k] = d[k]
	opponents.clear()


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(save))
	changed.emit()


func reset_game() -> void:
	var dbg = save.debug.duplicate(true)
	save = _default_save()
	save.debug = dbg
	opponents.clear()
	save_game()


# ---------------------------------------------------------------- 時間

func is_night() -> bool:
	match save.debug.time:
		"day": return false
		"night", "summer_night": return true
	var h: int = Time.get_datetime_dict_from_system().hour
	return h >= 18 or h < 5


func is_summer() -> bool:
	match save.debug.time:
		"summer_night": return true
		"day", "night": return false
	var m: int = Time.get_datetime_dict_from_system().month
	return m >= 6 and m <= 8


func time_text() -> String:
	var t := "夜" if is_night() else "昼"
	if is_summer():
		t = "夏の" + t
	return t


func available(id: int) -> bool:
	match chars[id].limit:
		"night": return is_night()
		"summer_night": return is_night() and is_summer()
	return true


# ---------------------------------------------------------------- 入手・図鑑

## キャラを1体入手する。結果（新規／レベルアップ／かけら）を返す。
func add_character(id: int, shiny: bool) -> Dictionary:
	var k := key(id, shiny)
	var res := {"id": id, "shiny": shiny, "new": false, "lv_up": false, "fragments": 0}
	if not save.roster.has(k):
		save.roster[k] = {"lv": 1}
		res.new = true
		_check_pages()
	elif int(save.roster[k].lv) < MAX_LV:
		save.roster[k].lv = int(save.roster[k].lv) + 1
		res.lv_up = true
	else:
		var n: int = chars[id].rarity * 5
		save.fragments = int(save.fragments) + n
		res.fragments = n
	return res


func page_progress(h: String, shiny: bool) -> Vector2i:
	var ids := ids_in_habitat(h)
	var n := 0
	for id in ids:
		if owned(id, shiny):
			n += 1
	return Vector2i(n, ids.size())


func _check_pages() -> void:
	for h in HABITATS:
		for shiny in [false, true]:
			var pk: String = h + ("_s" if shiny else "_n")
			if save.pages.has(pk):
				continue
			var p := page_progress(h, shiny)
			if p.x == p.y:
				save.pages[pk] = true
				var r := PAGE_REWARD_SHINY if shiny else PAGE_REWARD_NORMAL
				save.stones = int(save.stones) + r
				toast.emit("図鑑「%s」%sコンプリート！ ガチャ石+%d" % [h, "色違い" if shiny else "", r])


# ---------------------------------------------------------------- ガチャ

func gacha_pool(rarity: int) -> Array:
	var out := []
	for id in chars:
		var c = chars[id]
		if c.rarity == rarity and c.source != "scout":
			out.append(id)
	return out


func pity_left() -> int:
	return int(save.debug.pity) - int(save.pity)


func can_pull(n: int) -> bool:
	return int(save.stones) >= GACHA_COST * n


func pull(n: int) -> Array:
	if not can_pull(n):
		return []
	save.stones = int(save.stones) - GACHA_COST * n
	var results := []
	for i in n:
		results.append(_pull_one())
	save_game()
	return results


func _pull_one() -> Dictionary:
	save.pity = int(save.pity) + 1
	save.pulls = int(save.pulls) + 1
	var rates: Array = save.debug.rates
	var r := _weighted_rarity(rates, 1)
	if r < 3 and int(save.pity) >= int(save.debug.pity):
		r = _weighted_rarity(rates, 3)
	if r >= 3:
		save.pity = 0
	var pool := gacha_pool(r)
	while pool.is_empty() and r > 1:
		r -= 1
		pool = gacha_pool(r)
	var id: int = pool.pick_random()
	var shiny := randf() * 100.0 < float(save.debug.shiny)
	var res := add_character(id, shiny)
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

func formation_entries() -> Array:
	var out := []
	for s in save.formation:
		if s.k == "" or not save.roster.has(s.k):
			continue
		var p := parse_key(s.k)
		out.append({"id": p.id, "shiny": p.shiny, "lv": lv_of(s.k), "row": s.row})
	return out


func set_slot(i: int, k: String) -> void:
	while save.formation.size() < 7:
		save.formation.append({"k": "", "row": "中"})
	# 他の枠にいたら入れ替え
	for j in save.formation.size():
		if j != i and save.formation[j].k == k and k != "":
			save.formation[j].k = save.formation[i].k
	save.formation[i].k = k
	if k != "":
		save.formation[i].row = chars[parse_key(k).id].pos
	save_game()


func auto_formation() -> void:
	var want := {"GK": 1, "守": 2, "中": 2, "攻": 2}
	var used := {}
	var slots := []
	for row in ["GK", "守", "中", "攻"]:
		for n in want[row]:
			var best := ""
			var best_v := -1.0
			for k in save.roster:
				if used.has(k):
					continue
				var p := parse_key(k)
				var v := _player_value(p.id, lv_of(k), row)
				if v > best_v:
					best_v = v
					best = k
			if best != "":
				used[best] = true
				slots.append({"k": best, "row": row})
	while slots.size() < 7:
		slots.append({"k": "", "row": "中"})
	save.formation = slots
	save_game()


func _player_value(id: int, lv: int, row: String) -> float:
	var p := {"id": id, "lv": lv, "row": row}
	return atk_val(p) if row in ["中", "攻"] else def_val(p)


# ---------------------------------------------------------------- 試合

static func fit(pos: String, row: String) -> float:
	if pos == row:
		return 1.0
	if pos == "GK" or row == "GK":
		return 0.5
	return 0.8


func _mul(p: Dictionary) -> float:
	return fit(chars[p.id].pos, p.row) * (1.0 + 0.1 * (int(p.lv) - 1)) * float(p.get("boost", 1.0))


func atk_val(p: Dictionary) -> float:
	var c = chars[p.id]
	return (c.spd + c.pow * 1.2 + c.pas) * _mul(p)


func def_val(p: Dictionary) -> float:
	var c = chars[p.id]
	var v: float = (c.def * 2.0 + c.pow * 0.5 + c.spd * 0.5) * _mul(p)
	return v * 1.5 if p.row == "GK" else v


func team_power(entries: Array) -> Dictionary:
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
	return {"atk": atk, "def": dfn}


func get_opponent(league: int, refresh := false) -> Dictionary:
	if refresh or not opponents.has(league):
		opponents[league] = _make_opponent(league)
	return opponents[league]


func _make_opponent(league: int) -> Dictionary:
	var L: Dictionary = LEAGUES[league]
	var pool := []
	for id in L.pool:
		if available(id):
			pool.append(id)
	pool.shuffle()
	var picks := pool.slice(0, 7)
	while picks.size() < 7:
		picks.append(pool.pick_random())
	var members := []
	for id in picks:
		members.append({"id": id, "shiny": randf() * 100.0 < float(save.debug.shiny),
			"lv": clampi(int(L.lv) + randi_range(-1, 1), 1, MAX_LV), "row": chars[id].pos, "boost": L.boost})
	# GKがいなければ守備の一番高い選手をGKに
	var has_gk := members.any(func(m): return m.row == "GK")
	if not has_gk:
		var best = members[0]
		for m in members:
			if chars[m.id].def > chars[best.id].def:
				best = m
		best.row = "GK"
	var order := {"GK": 0, "守": 1, "中": 2, "攻": 3}
	members.sort_custom(func(a, b): return order[a.row] < order[b.row])
	return {"name": L.teams.pick_random(), "members": members}


## 試合を数値判定で決める。イベント列と結果を返す。
func simulate(mine: Array, opp: Array, tactic: String) -> Dictionary:
	var chances := [6, 6]
	var def_mul := [1.0, 1.0]
	match tactic:
		"攻める":
			chances = [8, 7]
			def_mul[0] = 0.9
		"守る":
			chances = [4, 4]
			def_mul[0] = 1.1
	var teams := [mine, opp]
	var goals := [0, 0]
	var stats := [[], []]   # 各選手の {goals, rating}
	for t in 2:
		for p in teams[t]:
			stats[t].append({"goals": 0, "rating": (atk_val(p) if p.row in ["中", "攻"] else def_val(p)) * randf_range(0.8, 1.2)})
	var events := []
	var phoenix_used := [false, false]
	for half in 2:
		var asleep := [{}, {}]
		for t in 2:
			for i in teams[t].size():
				if teams[t][i].id == 1 and randf() < 0.2:
					asleep[t][i] = true
					events.append({"min": 1 + half * 45 + randi_range(0, 10), "team": t, "goal": false,
						"text": "%sが寝てしまった…" % chars[1].name})
		var pw := []
		for t in 2:
			var entries := []
			for i in teams[t].size():
				if asleep[t].has(i):
					continue
				var p: Dictionary = teams[t][i].duplicate()
				if half == 1 and p.id == 7:
					p["tired"] = true
				entries.append(p)
			var tp := team_power(entries)
			if half == 1:
				for p in entries:
					if p.has("tired"):
						tp.atk -= atk_val(p) * 0.5
			tp.def *= def_mul[t]
			pw.append(tp)
		for t in 2:
			var o := 1 - t
			var n: int = ceili(chances[t] / 2.0) if half == 0 else chances[t] / 2
			var prob := clampf(0.24 * pw[t].atk / maxf(pw[o].def, 1.0), 0.04, 0.75)
			if _has_on_field(teams[o], 20, "GK"):
				prob *= 0.85
			for c in n:
				if randf() >= prob:
					continue
				var minute := 1 + half * 45 + randi_range(0, 44)
				if not phoenix_used[o] and _has_on_field(teams[o], 18, "GK"):
					phoenix_used[o] = true
					events.append({"min": minute, "team": o, "goal": false,
						"text": "%sが失点を灰の中からなかったことにした！" % chars[18].name})
					continue
				var si := _pick_scorer(teams[t], asleep[t])
				goals[t] += 1
				stats[t][si].goals += 1
				stats[t][si].rating += 30.0
				events.append({"min": minute, "team": t, "goal": true,
					"text": "%s のゴール！" % chars[teams[t][si].id].name, "shiny": teams[t][si].shiny})
	events.sort_custom(func(a, b): return a.min < b.min)
	var outcome := "draw"
	if goals[0] > goals[1]:
		outcome = "win"
	elif goals[0] < goals[1]:
		outcome = "lose"
	# 相手のMVPほどスカウトしやすい
	var mvp := 0
	for i in stats[1].size():
		if stats[1][i].rating > stats[1][mvp].rating:
			mvp = i
	var rates := []
	for i in opp.size():
		var r: int = 70 - (chars[opp[i].id].rarity - 1) * 15
		if stats[1][i].goals > 0:
			r += 15
		if i == mvp:
			r = 100
		rates.append(clampi(r, 10, 100))
	return {"goals": goals, "events": events, "outcome": outcome, "mvp": mvp, "scout_rates": rates}


func _has_on_field(team: Array, id: int, row: String) -> bool:
	return team.any(func(p): return p.id == id and p.row == row)


func _pick_scorer(team: Array, asleep: Dictionary) -> int:
	var weights := []
	var total := 0.0
	for i in team.size():
		var p = team[i]
		var c = chars[p.id]
		var w := 0.0
		if not asleep.has(i):
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


func finish_match(league: int, outcome: String) -> int:
	var reward := 10
	match outcome:
		"win":
			reward = 30 + int(LEAGUES[league].lv) * 20
			save.wins = int(save.wins) + 1
		"draw":
			reward = 20
			save.draws = int(save.draws) + 1
		_:
			save.losses = int(save.losses) + 1
	save.stones = int(save.stones) + reward
	save_game()
	return reward


func try_scout(member: Dictionary, rate: int) -> Dictionary:
	var ok := randi_range(1, 100) <= rate
	var res := {"ok": ok}
	if ok:
		res.merge(add_character(member.id, member.shiny))
	save_game()
	return res
