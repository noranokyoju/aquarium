extends Control
## レリック一覧（所持レリック欄の「一覧」で開閉）。ショップに並んだことのあるレリックだけ説明を表示する

const D := preload("res://scripts/data.gd")

var _head: Label
var _info: RichTextLabel
var _cells := {}             # レリックID → [アイコン, 名前ラベル]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.flat(Color("10203a"), Color("6aa8d0"), 2, 8, 16))
	p.position = Vector2(240, 60)
	p.size = Vector2(800, 600)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 12)
	v.add_child(head_row)
	head_row.add_child(UI.label("レリック一覧", 20, UI.C_YU))
	_head = UI.label("", 16, UI.C_SUB)
	_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_row.add_child(_head)
	head_row.add_child(UI.button("とじる", close, 14))
	v.add_child(UI.label("ショップに並んだことのあるレリックの説明を見られます", 14, UI.C_SUB))

	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for id in D.all_relic_ids():
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(70, 64)
		cell.mouse_entered.connect(func(): _info.text = _text(id))
		var bv := VBoxContainer.new()
		bv.alignment = BoxContainer.ALIGNMENT_CENTER
		bv.add_theme_constant_override("separation", 0)
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(bv)
		var icon := UI.icon_rect(UI.relic_icon(id), 32)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(icon)
		var l := UI.label("", 12)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(l)
		grid.add_child(cell)
		_cells[id] = [cell, icon, l]

	var ip := PanelContainer.new()
	ip.add_theme_stylebox_override("panel", UI.flat(Color("0d1a2b"), Color("2a405a"), 2, 6, 8))
	ip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(ip)
	_info = UI.rich(14)
	ip.add_child(_info)


func _unhandled_key_input(ev: InputEvent) -> void:
	if visible and ev.is_pressed() and (ev as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_info.text = "レリックにカーソルを合わせると説明を表示します。"
	_sync()
	visible = true
	get_parent().call("_update_pause")


func close() -> void:
	visible = false
	get_parent().call("_update_pause")


func _text(id: String) -> String:
	return UI.relic_text(id) if Game.relic_seen(id) else "？？？"


func _sync() -> void:
	var n := 0
	for id in _cells:
		var cell: PanelContainer = _cells[id][0]
		var icon: TextureRect = _cells[id][1]
		var l: Label = _cells[id][2]
		var seen := Game.relic_seen(id)
		if seen:
			n += 1
		var rc: Color = UI.RARITY_COLORS[D.relic_rarity(id)]
		cell.add_theme_stylebox_override("panel", UI.flat(Color("1d3550") if seen else Color("0d1a2b"), rc.darkened(0.3) if seen else Color("2a405a"), 2, 6, 2))
		# 未発見はシルエット（アイコンを黒く塗りつぶす）
		icon.modulate = Color.WHITE if seen else Color(0, 0, 0)
		l.text = id if seen else "？？？"
		l.add_theme_color_override("font_color", rc if seen else UI.C_SUB)
	_head.text = "発見 %d / %d" % [n, _cells.size()]
