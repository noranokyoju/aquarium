extends Control
## チュートリアルの吹き出し：対象を光る枠で囲み、しっぽ付きの吹き出しで指す。
## 操作は通す（OK ボタン以外はクリックを受けない）

const GAP := 16.0

var _target: Callable        # 対象の画面上の矩形を返す（Rect2()なら非表示）
var _side := "top"           # 吹き出しを対象のどちら側に出すか（top/bottom/left/right）
var _panel: PanelContainer
var _rect := Rect2()
var _time := 0.0


func _init(text: String, target: Callable, side: String, ok: Callable = Callable()) -> void:
	_target = target
	_side = side
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UI.flat(Color("0c1626", 0.96), UI.C_GOLD, 2, 8, 10))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	var r := UI.rich(15)
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(300, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = text
	v.add_child(r)
	if ok.is_valid():
		var b := UI.button("  OK  ", ok, 15)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		v.add_child(b)


func _process(delta: float) -> void:
	_time += delta
	var r: Rect2 = _target.call()
	_panel.visible = r.has_area()
	if r != _rect or _panel.size != _panel.get_combined_minimum_size():
		_rect = r
		_place()
	queue_redraw()


func _place() -> void:
	_panel.reset_size()
	var s := _panel.size
	var c := _rect.get_center()
	var pos: Vector2
	match _side:
		"bottom": pos = Vector2(c.x - s.x / 2.0, _rect.end.y + GAP)
		"left": pos = Vector2(_rect.position.x - s.x - GAP, c.y - s.y / 2.0)
		"right": pos = Vector2(_rect.end.x + GAP, c.y - s.y / 2.0)
		_: pos = Vector2(c.x - s.x / 2.0, _rect.position.y - s.y - GAP)
	_panel.position = Vector2(clampf(pos.x, 8.0, 1272.0 - s.x), clampf(pos.y, 8.0, 712.0 - s.y))


func _draw() -> void:
	if not _rect.has_area():
		return
	# 対象の光る枠
	var hl := UI.flat(Color(0, 0, 0, 0), UI.C_GOLD, 3, 8, 0)
	hl.draw_center = false
	var a := 0.55 + 0.45 * sin(_time * 5.0)
	draw_style_box(hl, _rect.grow(4))
	draw_rect(_rect.grow(4), Color(UI.C_GOLD, 0.12 * a))
	# しっぽ（吹き出しの辺から対象の辺へ）
	var pr := Rect2(_panel.position, _panel.size)
	var tip: Vector2
	var base: Vector2
	var along: Vector2
	match _side:
		"bottom":
			tip = Vector2(clampf(_rect.get_center().x, pr.position.x + 16, pr.end.x - 16), _rect.end.y + 5)
			base = Vector2(tip.x, pr.position.y + 1)
			along = Vector2(9, 0)
		"left":
			tip = Vector2(_rect.position.x - 5, clampf(_rect.get_center().y, pr.position.y + 16, pr.end.y - 16))
			base = Vector2(pr.end.x - 1, tip.y)
			along = Vector2(0, 9)
		"right":
			tip = Vector2(_rect.end.x + 5, clampf(_rect.get_center().y, pr.position.y + 16, pr.end.y - 16))
			base = Vector2(pr.position.x + 1, tip.y)
			along = Vector2(0, 9)
		_:
			tip = Vector2(clampf(_rect.get_center().x, pr.position.x + 16, pr.end.x - 16), _rect.position.y - 5)
			base = Vector2(tip.x, pr.end.y - 1)
			along = Vector2(9, 0)
	var pts := PackedVector2Array([base - along, tip, base + along])
	draw_colored_polygon(pts, Color("0c1626"))
	draw_polyline(pts, UI.C_GOLD, 2.0, true)
