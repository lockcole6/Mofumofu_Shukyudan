extends Node
## 「戻る」の管理。モーダルやサブ画面を開くたびに push し、戻るで閉じる。
## ブラウザの戻る・画面の戻るボタン・Esc・Androidの戻るキーがすべてここに来る。

signal changed

var _stack := []        # [{owner: Node, cb: Callable}]
var _ignore_pop := 0    # こちらから history.back() した分の popstate を無視する
var _js_cb              # JavaScriptBridge のコールバック（参照を保持しておく必要がある）


func _ready() -> void:
	get_tree().quit_on_go_back = false
	if OS.has_feature("web"):
		_js_cb = JavaScriptBridge.create_callback(_on_popstate)
		JavaScriptBridge.get_interface("window").addEventListener("popstate", _js_cb)


## owner が生きている間だけ有効な「戻る」を積む
func push(owner: Node, cb: Callable) -> void:
	_stack.append({"owner": owner, "cb": cb})
	if OS.has_feature("web"):
		JavaScriptBridge.eval("history.pushState({mofu: %d}, '')" % _stack.size(), true)
	changed.emit()


## 画面側のボタンで閉じるとき。戻るを1つ消費して cb を実行する。
func close(owner: Node) -> void:
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i].owner == owner:
			var e: Dictionary = _stack[i]
			_stack.remove_at(i)
			_browser_back()
			e.cb.call()
			changed.emit()
			return
	# 積まれていなければそのまま閉じる扱い
	if is_instance_valid(owner) and owner.has_method("queue_free") and owner.has_meta("layer"):
		owner.queue_free()


func back() -> bool:
	_prune()
	if _stack.is_empty():
		return false
	var e: Dictionary = _stack.pop_back()
	_browser_back()
	e.cb.call()
	changed.emit()
	return true


func has_back() -> bool:
	_prune()
	return not _stack.is_empty()


func clear() -> void:
	_stack.clear()
	changed.emit()


func _browser_back() -> void:
	if OS.has_feature("web"):
		_ignore_pop += 1
		JavaScriptBridge.eval("history.back()", true)


func _on_popstate(_args) -> void:
	if _ignore_pop > 0:
		_ignore_pop -= 1
		return
	_prune()
	if _stack.is_empty():
		return
	var e: Dictionary = _stack.pop_back()
	e.cb.call()
	changed.emit()


func _prune() -> void:
	while not _stack.is_empty():
		var o = _stack.back().owner
		if is_instance_valid(o) and o.is_inside_tree():
			return
		_stack.pop_back()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		back()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()
