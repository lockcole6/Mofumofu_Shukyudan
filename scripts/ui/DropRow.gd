extends PanelContainer
## 編成の1列。選手をドロップするとこの列へ移動する。

var row := ""
var on_drop := Callable()   # (選手id, 列)


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("id")


func _drop_data(_at: Vector2, data: Variant) -> void:
	on_drop.call(int(data.id), row)
