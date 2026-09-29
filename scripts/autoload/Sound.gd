extends Node
## 音の再生（BGM と効果音）。素材は tools/gen_audio.py で作った仮の音。
## assets/audio/ の同じ名前のファイルを差し替えれば、そのまま本番の音になる。
## 音量は設定画面から変えられ、セーブに保存される（Game.save.settings.bgm / sfx、0〜1）。

const DIR := "res://assets/audio/"
const FADE := 0.6
## 効果音ごとの音量の差（dB）。よく鳴る操作音は小さめ、ゴールやファンファーレは大きめ
const SFX_DB := {
	"tap": -14.0, "open": -10.0, "close": -12.0, "toast": -8.0, "error": -12.0,
	"lift": -8.0, "drop": -8.0, "remove": -6.0, "coin": -10.0, "levelup": -7.0,
	"whistle": -14.0, "whistle_end": -14.0, "skill": -9.0, "save": -4.0,
	"goal": 0.0, "opp_goal": -5.0, "win": -3.0, "draw": -5.0, "lose": -5.0,
	"promote": -2.0, "champion": -2.0, "door_shake": -6.0, "door_open": -8.0,
	"reveal1": -11.0, "reveal2": -6.0, "reveal3": -3.0, "reveal4": -2.0, "new": -8.0,
	"scout_ok": -7.0, "scout_ng": -9.0,
}
const BGM_DB := -12.0

var _bgm: Array = []     # クロスフェード用に2つ
var _bgm_cur := 0
var _bgm_name := ""
var _sfx: Array = []
var _sfx_i := 0
var _cache := {}
var _last := {}          # 同じ音が同時にいくつも鳴らないように


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		p.finished.connect(p.play)   # ループ情報が読めなかったときの保険
		add_child(p)
		_bgm.append(p)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx.append(p)
	apply_volume()


func _stream(name: String) -> AudioStream:
	if not _cache.has(name):
		var path := DIR + name + ".wav"
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


## 効果音を鳴らす
func play(name: String) -> void:
	if name == "":
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name, -1000)) < 40:
		return
	_last[name] = now
	var s := _stream("sfx_" + name)
	if s == null:
		return
	var p: AudioStreamPlayer = _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = s
	p.volume_db = SFX_DB.get(name, -6.0)
	p.play()


## BGM を切り替える（同じ曲なら何もしない）。"" で止める
func bgm(name: String) -> void:
	if name == _bgm_name:
		return
	_bgm_name = name
	var old: AudioStreamPlayer = _bgm[_bgm_cur]
	_bgm_cur = 1 - _bgm_cur
	var cur: AudioStreamPlayer = _bgm[_bgm_cur]
	var tw := create_tween().set_parallel()
	tw.tween_property(old, "volume_db", -80.0, FADE)
	tw.chain().tween_callback(old.stop)
	if name == "":
		return
	cur.stream = _stream("bgm_" + name)
	if cur.stream == null:
		return
	cur.volume_db = -40.0
	cur.play()
	create_tween().tween_property(cur, "volume_db", BGM_DB, FADE)


## 設定の音量をバスに反映する
func apply_volume() -> void:
	var st: Dictionary = Game.save.get("settings", {})
	_set_bus("Music", float(st.get("bgm", 0.7)))
	_set_bus("SFX", float(st.get("sfx", 0.8)))


func _set_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))
