extends Control
## デバッグ用：所持レリックを自由に付け外しするパネル（F1 またはプレイ画面の「デバッグ」で開閉）

const D := preload("res://scripts/data.gd")

var _grid: GridContainer
var _head: Label
var _note: Label
var _info: RichTextLabel
var _buttons := {}           # レリックID → ボタン


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.flat(Color("10203a"), Color("e0a050"), 2, 8, 16))
	p.position = Vector2(240, 60)
	p.size = Vector2(800, 600)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 12)
	v.add_child(head_row)
	head_row.add_child(UI.label("デバッグ：所持レリック", 20, UI.C_GOLD))
	_head = UI.label("", 16)
	_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_row.add_child(_head)
	head_row.add_child(UI.button("すべて外す", func(): _set_relics([]), 14))
	head_row.add_child(UI.button("とじる", close, 14))
	v.add_child(UI.label("クリックで付け外し（枠数・同時所持の制限は無視します）", 14, UI.C_SUB))

	_grid = GridContainer.new()
	_grid.columns = 10
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	v.add_child(_grid)
	for id in D.all_relic_ids():
		var b := Button.new()
		b.custom_minimum_size = Vector2(70, 64)
		b.mouse_entered.connect(func(): _info.text = UI.relic_text(id))
		b.pressed.connect(func(): _toggle(id))
		var bv := VBoxContainer.new()
		bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bv.alignment = BoxContainer.ALIGNMENT_CENTER
		bv.add_theme_constant_override("separation", 0)
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bv)
		var icon := UI.icon_rect(UI.relic_icon(id), 32)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(icon)
		var l := UI.label(id, 12, UI.RARITY_COLORS[D.relic_rarity(id)])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(l)
		_grid.add_child(b)
		_buttons[id] = b

	_note = UI.label("", 14, UI.C_GOLD)
	v.add_child(_note)
	var ip := PanelContainer.new()
	ip.add_theme_stylebox_override("panel", UI.flat(Color("0d1a2b"), Color("2a405a"), 2, 6, 8))
	ip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(ip)
	_info = UI.rich(14)
	ip.add_child(_info)
	Game.changed.connect(func(): if visible: _sync())


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev.is_pressed() and not ev.is_echo() and (ev as InputEventKey).keycode == KEY_F1:
		if visible:
			close()
		elif Game.has_run() and get_parent().get("_screen") == "game":
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	if not Game.has_run():
		return
	_info.text = "レリックにカーソルを合わせると説明を表示します。"
	_sync()
	visible = true
	get_parent().call("_update_pause")


func close() -> void:
	visible = false
	get_parent().call("_update_pause")


func _toggle(id: String) -> void:
	Sfx.play("click")
	var rel: Array = Game.state["relics"].duplicate()
	if rel.has(id):
		rel.erase(id)
	else:
		rel.append(id)
	_set_relics(rel)


func _set_relics(ids: Array) -> void:
	Game.debug_set_relics(ids)
	_sync()


func _sync() -> void:
	var owned: Array = Game.state["relics"]
	_head.text = "所持 %d / 枠 %d" % [owned.size(), Game.slots()]
	_head.add_theme_color_override("font_color", UI.C_BAD if owned.size() > Game.slots() else UI.C_TEXT)
	for id in _buttons:
		var b: Button = _buttons[id]
		var on := owned.has(id)
		b.add_theme_stylebox_override("normal", UI.flat(Color("3a3218") if on else Color("1d3550"), UI.C_GOLD if on else Color("5f9cc0"), 3 if on else 2))
		b.add_theme_stylebox_override("hover", UI.flat(Color("4a4020") if on else Color("26476a"), UI.C_GOLD if on else Color("8cc8e8"), 3 if on else 2))
	_note.text = "" if Game.phase() == "idle" else "※サイクル中の変更は、次のサイクルから効果に反映されます。"
