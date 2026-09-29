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
const BGM_DB := -6.0

var _bgm: Array = []     # クロスフェード用に2つ
var _bgm_cur := 0
var _bgm_name := ""
var _sfx: Array = []
var _sfx_i := 0
var _cache := {}
var _last := {}          # 同じ音が同時にいくつも鳴らないように
## Web版はブラウザの決まりで、画面に触るまで音が出ない。その間にBGMを始めると、
## 最初に触った瞬間にいきなり大きな音で鳴り出すので、触ってから無音からフェードインする
var _unlocked := not OS.has_feature("web")
var _unlock_frame := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# バス（Music / SFX）は default_bus_layout.tres で定義している。
	# Web版は起動後に add_bus したバスが音の出力に反映されず無音になるため、起動時から用意しておく
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
	# 音がまだ出せない間と、音を有効にした最初のタッチでは鳴らさない（いきなり鳴って驚かないように）
	if name == "" or not _unlocked or Engine.get_process_frames() == _unlock_frame:
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
	if not _unlocked:
		return   # 最初に触ったときに始める
	_switch_bgm(name, FADE)


func _switch_bgm(name: String, fade: float) -> void:
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
	cur.volume_db = -60.0
	cur.play()
	create_tween().tween_property(cur, "volume_db", BGM_DB, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _input(e: InputEvent) -> void:
	if _unlocked:
		return
	if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
		_unlocked = true
		_unlock_frame = Engine.get_process_frames()
		if _bgm_name != "":
			_switch_bgm(_bgm_name, 1.5)


## 設定の音量をバスに反映する
func apply_volume() -> void:
	var st: Dictionary = Game.save.get("settings", {})
	_set_bus("Music", float(st.get("bgm", 0.7)))
	_set_bus("SFX", float(st.get("sfx", 0.8)))
	AudioServer.set_bus_mute(0, bool(st.get("mute", false)))


func is_muted() -> bool:
	return bool(Game.save.settings.get("mute", false))


## すべての音のオン/オフ（上のバーのスピーカー）
func toggle_mute() -> void:
	Game.save.settings.mute = not is_muted()
	apply_volume()
	Game.save_game()


func _set_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))
