extends Control
## プレイ画面（上部ステータス・キャラクター・ネットワーク・ショップ・所持品・説明欄）

signal open_settings
signal go_title
signal run_ended

const D := preload("res://scripts/data.gd")
const NetworkView := preload("res://scripts/ui/network_view.gd")

const NET_RECT := Rect2(330, 44, 946, 456)

var net: NetworkView
var _top: HBoxContainer
var _char_tex: TextureRect
var _char_name: Label
var _char_bg: TextureRect
var _dice_box: HBoxContainer
var _ctrl_info: RichTextLabel
var _ctrl_buttons: HBoxContainer
var _shop_box: HBoxContainer
var _shop_head: HBoxContainer
var _owned_head: Label
var _owned_grid: GridContainer
var _info: RichTextLabel
var _info_actions: HBoxContainer
var _float_layer: Control
var _modal_layer: Control
var _tut_layer: Control

var _selected_relic := ""
var _hover_text := ""
var _r35_mode := false
var _modal_kind := ""
var _tut_queue: Array = []
var _moving_running := false
var _skip := false
var _dice_anim := 0.0
var _shown_w := 0.0
var _w_tween: Tween
var _char_pose := 0
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Game.changed.connect(refresh)


# ================================================================ 構築

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UI.C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 上部
	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(4, 4)
	top_panel.size = Vector2(1272, 36)
	top_panel.add_theme_stylebox_override("panel", UI.flat(UI.C_PANEL, UI.C_BORDER, 2, 6, 4))
	add_child(top_panel)
	var top_row := HBoxContainer.new()
	top_panel.add_child(top_row)
	_top = HBoxContainer.new()
	_top.add_theme_constant_override("separation", 18)
	_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_top)
	top_row.add_child(UI.button("設定", func(): open_settings.emit(), 14))
	top_row.add_child(UI.button("タイトルへ", func(): go_title.emit(), 14))

	# 左：背景とキャラクター
	var cp := Panel.new()
	cp.position = Vector2(4, 44)
	cp.size = Vector2(322, 456)
	cp.clip_contents = true
	cp.add_theme_stylebox_override("panel", UI.flat(Color("0a1220"), UI.C_BORDER, 2, 8, 0))
	add_child(cp)
	_char_bg = TextureRect.new()
	_char_bg.texture = UI.background()
	_char_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_char_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_char_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_char_bg.position = Vector2(2, 2)
	_char_bg.size = Vector2(318, 452)
	cp.add_child(_char_bg)
	_char_tex = TextureRect.new()
	_char_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_char_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_char_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_char_tex.size = Vector2(330, 330)
	_char_tex.position = Vector2(-4, 60)
	cp.add_child(_char_tex)
	_char_name = UI.label("", 18)
	_char_name.position = Vector2(0, 420)
	_char_name.size = Vector2(322, 24)
	_char_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_name.add_theme_color_override("font_outline_color", Color("0a1220"))
	_char_name.add_theme_constant_override("outline_size", 6)
	cp.add_child(_char_name)
	_dice_box = HBoxContainer.new()
	_dice_box.position = Vector2(10, 10)
	_dice_box.add_theme_constant_override("separation", 4)
	cp.add_child(_dice_box)

	# 右：ネットワーク
	net = NetworkView.new()
	net.position = NET_RECT.position
	net.size = NET_RECT.size
	net.node_clicked.connect(_on_node_clicked)
	net.node_hovered.connect(_on_node_hovered)
	add_child(net)

	var ctrl := VBoxContainer.new()
	ctrl.position = NET_RECT.position + Vector2(12, 352)
	ctrl.size = Vector2(NET_RECT.size.x - 24, 100)
	ctrl.add_theme_constant_override("separation", 2)
	add_child(ctrl)
	_ctrl_info = UI.rich(14)
	_ctrl_info.custom_minimum_size = Vector2(0, 60)
	_ctrl_info.scroll_active = false
	_ctrl_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(_ctrl_info)
	_ctrl_buttons = HBoxContainer.new()
	_ctrl_buttons.add_theme_constant_override("separation", 8)
	_ctrl_buttons.alignment = BoxContainer.ALIGNMENT_END
	ctrl.add_child(_ctrl_buttons)

	# 下：ショップ
	var shop := PanelContainer.new()
	shop.position = Vector2(4, 504)
	shop.size = Vector2(700, 212)
	add_child(shop)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	shop.add_child(sv)
	_shop_head = HBoxContainer.new()
	_shop_head.add_theme_constant_override("separation", 10)
	sv.add_child(_shop_head)
	_shop_box = HBoxContainer.new()
	_shop_box.add_theme_constant_override("separation", 6)
	sv.add_child(_shop_box)

	# 下：所持レリック
	var owned := PanelContainer.new()
	owned.position = Vector2(708, 504)
	owned.size = Vector2(278, 212)
	add_child(owned)
	var ov := VBoxContainer.new()
	owned.add_child(ov)
	_owned_head = UI.label("", 15)
	ov.add_child(_owned_head)
	_owned_grid = GridContainer.new()
	_owned_grid.columns = 6
	_owned_grid.add_theme_constant_override("h_separation", 4)
	_owned_grid.add_theme_constant_override("v_separation", 4)
	ov.add_child(_owned_grid)

	# 下：説明欄
	var info := PanelContainer.new()
	info.position = Vector2(990, 504)
	info.size = Vector2(286, 212)
	add_child(info)
	var iv := VBoxContainer.new()
	info.add_child(iv)
	_info = UI.rich(14)
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	iv.add_child(_info)
	_info_actions = HBoxContainer.new()
	_info_actions.alignment = BoxContainer.ALIGNMENT_END
	iv.add_child(_info_actions)

	_float_layer = Control.new()
	_float_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_float_layer)
	_modal_layer = Control.new()
	_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_modal_layer)
	_tut_layer = Control.new()
	_tut_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tut_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tut_layer)


## ラン開始・再開時に呼ぶ
func enter() -> void:
	_modal_kind = ""
	_selected_relic = ""
	_r35_mode = false
	_skip = false
	_dice_anim = 0.0
	for c in _modal_layer.get_children():
		c.queue_free()
	_shown_w = Game.state["W"]
	var st := Game.state
	_char_pose = st["cur"]
	var ph := Game.phase()
	if ph == "moving" or ph == "r33" or ph == "report":
		_char_pose = _anim_pos()
	refresh()
	if ph == "idle":
		_queue_tut("t1")
		_queue_tut("t2")
	elif ph == "plan":
		_plan_tutorials()
	elif ph == "moving":
		_start_moving()


func _process(delta: float) -> void:
	_time += delta
	if _dice_anim > 0.0:
		_dice_anim -= delta
		if _dice_anim <= 0.0:
			refresh()
	# ゆらゆら
	_char_tex.position.y = 74 + sin(_time * 1.6) * 4.0
	if Game.has_run() and absf(_shown_w - Game.state["W"]) > 0.5 and (_w_tween == null or not _w_tween.is_running()):
		_shown_w = Game.state["W"]
		_refresh_top()


# ================================================================ 更新

func refresh() -> void:
	if not Game.has_run() or not is_visible_in_tree():
		return
	_refresh_top()
	_refresh_char()
	_refresh_net()
	_refresh_controls()
	_refresh_shop()
	_refresh_owned()
	_refresh_info()
	_refresh_modal()


func _speed() -> float:
	return float(Game.settings["speed"])


func _refresh_top() -> void:
	for c in _top.get_children():
		c.queue_free()
	var st := Game.state
	var tgt := Game.target()
	var w := int(_shown_w)
	_top.add_child(_icon_text(UI.icon_fish(), "おさかな %s" % UI.num(w), UI.C_GOLD))
	var short: int = tgt - st["W"]
	var t := "目標 %s" % UI.num(tgt)
	t += "（不足 %s）" % UI.num(short) if short > 0 else "（達成中）"
	_top.add_child(UI.label(t, 15, UI.C_BAD if short > 0 else UI.C_GOOD))
	_top.add_child(_icon_text(UI.icon_aqua(), "アクアマリン %d" % st["A"], UI.C_AQUA))
	_top.add_child(UI.label("ラウンド %d/5 %s" % [st["r"], D.round_name(st["r"])], 15))
	_top.add_child(UI.label("サイクル %d/10（残り%d）" % [st["c"], 10 - st["c"]], 15))
	_top.add_child(UI.label("連続的中 %d" % st["H"], 15, UI.C_GOLD if st["H"] > 0 else UI.C_TEXT))


func _icon_text(tex: Texture2D, text: String, col: Color, size: int = 15) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.add_child(UI.icon_rect(tex, 20))
	h.add_child(UI.label(text, size, col))
	return h


func _anim_pos() -> int:
	var c := Game.cyc()
	if c.is_empty() or c["route"].is_empty():
		return Game.state["cur"]
	var i: int = c["anim"]
	if i <= 0:
		return c["s"]
	return c["route"]["steps"][i - 1]["to"]


func _refresh_char() -> void:
	var p := _char_pose
	_char_tex.texture = _char_atlas(p)
	_char_name.text = "%s（%s）" % [D.pose_name(p), D.AREA_NAMES[D.area_of(p)]]
	_char_name.add_theme_color_override("font_color", UI.area_color(D.area_of(p)))
	for ch in _dice_box.get_children():
		ch.queue_free()
	var c := Game.cyc()
	if c.is_empty():
		return
	for v in c["dice"]:
		var tex := UI.icon_dice_roll() if _dice_anim > 0.0 else UI.icon_dice(v)
		_dice_box.add_child(UI.icon_rect(tex, 48))
	if _dice_anim <= 0.0:
		var l := UI.label("出目 %d" % Logic.dice_sum(c["dice"]), 18)
		l.add_theme_color_override("font_outline_color", Color("0a1220"))
		l.add_theme_constant_override("outline_size", 6)
		_dice_box.add_child(l)


var _char_atlas_cache := {}
func _char_atlas(p: int) -> AtlasTexture:
	if not _char_atlas_cache.has(p):
		var a := AtlasTexture.new()
		a.atlas = UI.chars()
		a.region = Rect2((p % 5) * 640 + 120, (p / 5) * 480 + 36, 400, 400)
		_char_atlas_cache[p] = a
	return _char_atlas_cache[p]


func _refresh_net() -> void:
	var st := Game.state
	var ph := Game.phase()
	var c := Game.cyc()
	net.bases = st["B"]
	net.levels = st["L"]
	if c.is_empty():
		net.relics = st["relics"]
		net.link_bases = st["B"]
		net.next_step = 1
		net.cur = st["cur"]
		net.start = -1
		net.guess = -1
		net.marks = []
		net.probs = []
		net.show_forced = false
	else:
		net.relics = c["relics"]
		net.link_bases = c["B"]
		net.start = c["s"]
		net.guess = c["q"]
		net.marks = c["marks"]
		net.show_forced = true
		if ph == "plan":
			net.next_step = 1
			net.cur = st["cur"]
			net.probs = Logic.end_distribution(c["s"], c["n0"], c["relics"], c["B"]) if _dice_anim <= 0.0 else []
		else:
			net.next_step = int(c["anim"]) + 1
			net.cur = _anim_pos()
			net.probs = []
			if ph != "moving":
				net.show_forced = false
	net.interactive = ph == "plan"
	net.queue_redraw()


# ---------------------------------------------------------------- 操作欄

func _refresh_controls() -> void:
	for c in _ctrl_buttons.get_children():
		c.queue_free()
	var ph := Game.phase()
	var st := Game.state
	var cyc := Game.cyc()
	var info := ""
	match ph:
		"idle":
			if st["pending_swap"] >= 0:
				info = "入れ替えるレリックを選んでください。"
			else:
				info = "待機中：買い物・ポーズ強化・更新・破棄ができます。\n[color=%s]終点確率：サイコロ後に表示[/color]" % UI.hexc(UI.C_SUB)
			var b := UI.button("  サイコロをふる  ", _on_roll, 18)
			b.disabled = not Game.can_shop()
			_ctrl_buttons.add_child(b)
		"plan":
			info = _plan_info(cyc)
			if _dice_anim <= 0.0:
				_add_plan_buttons(cyc)
		"moving", "r33", "report":
			info = _moving_info(cyc)
			if ph == "moving":
				var sk := UI.button("結果までスキップ", func(): _skip = true)
				sk.disabled = _skip
				_ctrl_buttons.add_child(sk)
	if ph in ["idle", "moving"]:
		_ctrl_buttons.add_child(UI.button("速度 %s" % _speed_name(), _cycle_speed))
	_ctrl_info.text = info


func _speed_name() -> String:
	match int(Game.settings["speed"]):
		2: return "2倍"
		4: return "4倍"
	return "標準"


func _cycle_speed() -> void:
	var s: int = Game.settings["speed"]
	Game.settings["speed"] = {1: 2, 2: 4, 4: 1}[s]
	Game.save_settings()
	_refresh_controls()


func _dice_text(dice: Array) -> String:
	var parts := []
	for v in dice:
		parts.append(str(v))
	return "+".join(parts)


func _plan_info(cyc: Dictionary) -> String:
	if _dice_anim > 0.0:
		return "サイコロを振っています…"
	var rel: Array = cyc["relics"]
	var mods := []
	if rel.has("R05"): mods.append("R05 +1")
	if rel.has("R06"): mods.append("R06 -1")
	if rel.has("R35"): mods.append("R35 +%d" % cyc["Mprev"])
	if cyc["b"] > 0: mods.append("R32 +%d" % cyc["b"])
	if rel.has("R39"): mods.append("R39 上限3")
	var s := "出目 [b]%s[/b]" % _dice_text(cyc["dice"])
	if not mods.is_empty():
		s += "（%s）" % "、".join(mods)
	s += " → 通常予定 [color=%s][b]%d歩[/b][/color]　開始 %s　予想 [color=%s]%s[/color]" % [
		UI.hexc(UI.C_GOLD), cyc["n0"], D.pose_name(cyc["s"]), UI.hexc(UI.C_GOLD), D.pose_name(cyc["q"])]
	if Logic.is_forced_step(1, rel) and cyc["n0"] > 0:
		s += "　[color=%s]1歩目は強制跨ぎ[/color]" % UI.hexc(UI.C_GOLD)
	var note := "※確率は通常移動のみの終点分布（早期停止・追加移動・的中扱いを含まない）"
	if rel.has("R16") or rel.has("R34") or rel.has("R33") or rel.has("R36"):
		note += "。表示値は最終的中率ではありません"
	s += "\n[color=%s]%s[/color]" % [UI.hexc(UI.C_SUB), note]
	return s


func _add_plan_buttons(cyc: Dictionary) -> void:
	var rel: Array = cyc["relics"]
	_ctrl_buttons.alignment = BoxContainer.ALIGNMENT_END
	if rel.has("R03"):
		var b := UI.button("ふりなおす（残り%d）" % (0 if cyc["rerolled"] else 1), _on_reroll, 14)
		b.disabled = not Game.can_reroll()
		_ctrl_buttons.add_child(b)
	if rel.has("R32"):
		var b := UI.button("歩数+2（A1）追加%d歩" % cyc["b"], func():
			Game.buy_step()
			Sfx.play("buy"), 14)
		b.disabled = not Game.can_buy_step()
		if rel.has("R39"):
			b.tooltip_text = "R39所持中は上限3歩。上限を超えた分（振り直し後を含む）は返金されません。"
		_ctrl_buttons.add_child(b)
	if rel.has("R19"):
		var b := UI.button("開始地をえらぶ" if not _r35_mode else "開始地をクリック…", func():
			_r35_mode = not _r35_mode
			refresh(), 14)
		_ctrl_buttons.add_child(b)
	var go := UI.button("  ここにする  ", _on_confirm, 18)
	_ctrl_buttons.add_child(go)


func _moving_info(cyc: Dictionary) -> String:
	if cyc.is_empty() or cyc["route"].is_empty():
		return ""
	var steps: Array = cyc["route"]["steps"]
	var anim: int = cyc["anim"]
	var normal_done := 0
	var extra_done := 0
	var extra_total := 0
	for i in steps.size():
		if steps[i]["extra"]:
			extra_total += 1
			if i < anim:
				extra_done += 1
		elif i < anim:
			normal_done += 1
	var n0: int = cyc["n0"]
	var s := "通常予定 %d歩・移動済み %d歩・残り %d歩" % [n0, normal_done, maxi(0, n0 - normal_done)]
	var kbase: int = cyc["route"]["kbase"]
	if kbase > 0 and (extra_total > 0 or anim >= steps.size()):
		s += "　[color=%s]追加移動 %d/%d歩（R34）[/color]" % [UI.hexc(UI.C_LINK), extra_done, kbase]
	if anim < steps.size() and Logic.is_forced_step(anim + 1, cyc["relics"]):
		s += "　[color=%s]次の歩は強制跨ぎ[/color]" % UI.hexc(UI.C_GOLD)
	if anim >= steps.size():
		s += "\n[color=%s]%s[/color]" % [UI.hexc(UI.C_SUB), Logic.stop_reason_text(cyc["route"]["stop"])]
	else:
		s += "\n[color=%s]途中の報酬は仮表示です（精算で確定）[/color]" % UI.hexc(UI.C_SUB)
	return s


# ---------------------------------------------------------------- ショップ

func _refresh_shop() -> void:
	for c in _shop_head.get_children():
		c.queue_free()
	for c in _shop_box.get_children():
		c.queue_free()
	var st := Game.state
	_shop_head.add_child(UI.label("ショップ", 16, UI.C_YU))
	var hint := UI.label("最初のレリック1個は無料" if st["first_free"] else "", 14, UI.C_GOLD)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_head.add_child(hint)
	_shop_head.add_child(UI.label("無料更新権 %d・次回有料 %s" % [st["free_refresh"], UI.num(Game.refresh_cost())], 14, UI.C_SUB))
	var rb_text := "無料で更新" if st["free_refresh"] > 0 else "更新（%s）" % UI.num(Game.refresh_cost())
	var rb := UI.button(rb_text, func():
		Game.refresh_shop()
		Sfx.play("dice"), 14)
	rb.disabled = not Game.can_refresh()
	rb.mouse_entered.connect(func(): _hover(_refresh_text()))
	rb.mouse_exited.connect(func(): _hover(""))
	_shop_head.add_child(rb)

	for i in 3:
		_shop_box.add_child(_relic_card(i))
	for i in 2:
		_shop_box.add_child(_pose_card(i))


func _refresh_text() -> String:
	var st := Game.state
	var s := "[b]ショップ更新[/b]\n売り切れを含む全5枠を再抽選します。未購入品は消えます。\n"
	if st["free_refresh"] > 0:
		s += "無料更新権を1回使います（有料価格は上がりません）。"
	else:
		var after: int = st["W"] - Game.refresh_cost()
		s += "価格 %s おさかな（使うたび+30）。\n購入後 %s" % [UI.num(Game.refresh_cost()), UI.num(after)]
		if after < Game.target():
			s += "\n[color=%s]目標まで不足 %s[/color]" % [UI.hexc(UI.C_BAD), UI.num(Game.target() - after)]
	return s


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(132, 162)
	p.add_theme_stylebox_override("panel", UI.flat(UI.C_PANEL2, Color("2f4c6c"), 2, 6, 5))
	return p


func _relic_card(i: int) -> Control:
	var card := _card()
	var slot: Dictionary = Game.state["shop"]["relics"][i]
	var id: String = slot["id"]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	if id == "":
		var l := UI.label("（なし）", 14, UI.C_SUB)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		return card
	var rar := D.relic_rarity(id)
	card.add_theme_stylebox_override("panel", UI.flat(UI.C_PANEL2, UI.RARITY_COLORS[rar].darkened(0.4), 2, 6, 5))
	var ic := UI.icon_rect(UI.relic_icon(id), 44)
	if slot["sold"]:
		ic.modulate = Color(1, 1, 1, 0.3)
	v.add_child(ic)
	var n := UI.label(D.relic_name(id), 14)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	n.custom_minimum_size = Vector2(120, 0)
	v.add_child(n)
	var r := UI.label("%s %s" % [id, D.RARITY_NAMES[rar]], 12, UI.RARITY_COLORS[rar])
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(r)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	if slot["sold"]:
		var so := UI.label("売り切れ", 15, UI.C_SUB)
		so.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(so)
	else:
		var cost := Game.relic_cost(id)
		var price := _icon_text(UI.icon_aqua(), "無料" if cost == 0 else "%d" % cost, UI.C_AQUA, 14)
		price.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(price)
		var b := UI.button("かう", func(): _on_buy_relic(i), 14)
		b.disabled = not Game.can_buy_relic(i)
		v.add_child(b)
	var txt := UI.relic_text(id)
	if not slot["sold"] and Game.state["first_free"]:
		txt += "\n[color=%s]初回無料で購入できます[/color]" % UI.hexc(UI.C_GOLD)
	txt += _combo_warning(id)
	_hoverable(card, txt)
	return card


func _combo_warning(id: String) -> String:
	var owned: Array = Game.state["relics"]
	if (id == "R39" and owned.has("R40")) or (id == "R40" and owned.has("R39")):
		return "\n[color=%s]【注意】R39とR40を併用すると、最大3歩で全訪問がゼロ報酬となり、おさかな報酬は常に0です（G=4）。[/color]" % UI.hexc(UI.C_BAD)
	return ""


func _pose_card(i: int) -> Control:
	var card := _card()
	var slot: Dictionary = Game.state["shop"]["poses"][i]
	var p: int = slot["p"]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	if p < 0:
		var l := UI.label("すべてMAX" if p == -2 else "（なし）", 14, UI.C_SUB)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		return card
	var st := Game.state
	var bp: float = st["B"][p]
	card.add_theme_stylebox_override("panel", UI.flat(UI.C_PANEL2, UI.area_color(D.area_of(p)).darkened(0.45), 2, 6, 5))
	var pic := TextureRect.new()
	var a := AtlasTexture.new()
	a.atlas = UI.chars()
	var reg := UI.pose_region(p)
	var side := maxf(reg.size.x, reg.size.y)
	a.region = Rect2(reg.get_center() - Vector2(side, side) / 2.0, Vector2(side, side))
	pic.texture = a
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(44, 44)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if slot["sold"]:
		pic.modulate = Color(1, 1, 1, 0.3)
	v.add_child(pic)
	var n := UI.label("%s 強化" % D.pose_name(p), 14, UI.area_color(D.area_of(p)))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var info := UI.label("基礎 %s→%s\n強化 %d/%d" % [Logic.fmt_num(bp), Logic.fmt_num(bp * 1.5), st["L"][p], D.L_MAX], 12, UI.C_SUB)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var price := Logic.pose_price(st["L"][p])
	if slot["sold"]:
		var so := UI.label("売り切れ", 15, UI.C_SUB)
		so.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(so)
	else:
		var after: int = st["W"] - price
		var pr := _icon_text(UI.icon_fish(), UI.num(price), UI.C_GOLD, 14)
		pr.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(pr)
		var b := UI.button("かう", func():
			Game.buy_pose(i)
			Sfx.play("buy"), 14)
		b.disabled = not Game.can_buy_pose(i)
		v.add_child(b)
		if after >= 0 and after < Game.target():
			b.tooltip_text = "購入後 %s（目標まで不足 %s）" % [UI.num(after), UI.num(Game.target() - after)]
	var txt := _pose_text(p)
	if not slot["sold"]:
		txt += "\n\n[b]ショップ強化[/b]：基礎値×1.5、強化回数+1\n基礎 %s → %s\n価格 %s おさかな（30×3^強化回数）" % [
			Logic.fmt_num(bp), Logic.fmt_num(bp * 1.5), UI.num(price)]
		var after: int = st["W"] - price
		txt += "\n購入後の残高 %s" % UI.num(after)
		if after < Game.target():
			txt += "\n[color=%s]目標まで不足 %s[/color]" % [UI.hexc(UI.C_BAD), UI.num(Game.target() - after)]
	_hoverable(card, txt)
	return card


func _pose_text(p: int) -> String:
	var st := Game.state
	var a := D.area_of(p)
	var s := "[b][color=%s]%s %s[/color][/b]\nエリア：%s\n基礎値：%s\nショップ強化：%d/%d" % [
		UI.hexc(UI.area_color(a)), D.POSES[p][0], D.pose_name(p), D.AREA_NAMES[a],
		Logic.fmt_num(st["B"][p]), st["L"][p], D.L_MAX]
	return s


# ---------------------------------------------------------------- 所持品

func _refresh_owned() -> void:
	for c in _owned_grid.get_children():
		c.queue_free()
	var st := Game.state
	var owned: Array = st["relics"]
	_owned_head.text = "レリック %d/%d" % [owned.size(), Game.slots()]
	for i in Game.slots():
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(40, 40)
		var sel: bool = i < owned.size() and owned[i] == _selected_relic
		slot.add_theme_stylebox_override("panel", UI.flat(Color("0d1a2b"), UI.C_GOLD if sel else Color("2a405a"), 2, 4, 2))
		if i < owned.size():
			var id: String = owned[i]
			slot.add_child(UI.icon_rect(UI.relic_icon(id), 32))
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					Sfx.play("click")
					_selected_relic = "" if _selected_relic == id else id
					refresh())
			_hoverable(slot, UI.relic_text(id))
		_owned_grid.add_child(slot)


# ---------------------------------------------------------------- 説明欄

func _hoverable(c: Control, text: String) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_entered.connect(func(): _hover(text))
	c.mouse_exited.connect(func(): _hover(""))


func _hover(text: String) -> void:
	_hover_text = text
	_refresh_info()


func _refresh_info() -> void:
	for c in _info_actions.get_children():
		c.queue_free()
	if _hover_text != "":
		_info.text = _hover_text
		return
	if _selected_relic != "" and Game.state["relics"].has(_selected_relic):
		_info.text = UI.relic_text(_selected_relic)
		var id := _selected_relic
		var b := UI.button("すてる", func(): _confirm_discard(id), 14)
		b.disabled = not Game.can_shop()
		_info_actions.add_child(b)
		return
	_info.text = _default_info()


func _default_info() -> String:
	var ph := Game.phase()
	var sub := UI.hexc(UI.C_SUB)
	match ph:
		"idle":
			return "[b]待機中[/b]\nレリック購入・ポーズ強化・更新・レリック破棄ができます。\n準備ができたら「サイコロをふる」。\n\n[color=%s]カードやポーズにカーソルを合わせると説明が出ます。所持レリックをクリックで選択・破棄。[/color]" % sub
		"plan":
			var s := "[b]作戦フェーズ[/b]\nポーズをクリックして終点を予想。確率0のポーズも選べます。"
			if _r35_mode:
				s += "\n[color=%s]開始地にするポーズをクリックしてください。[/color]" % UI.hexc(UI.C_GOLD)
			s += "\n\n" + _mark_text()
			return s
		"moving":
			return "[b]移動中[/b]\n" + _mark_text()
	return ""


func _mark_text() -> String:
	var c := Game.cyc()
	if c.is_empty() or c["marks"].is_empty():
		return "[color=%s]今回の共通マーク：なし[/color]" % UI.hexc(UI.C_SUB)
	var names := []
	for p in c["marks"]:
		names.append(D.pose_name(p))
	var rel: Array = c["relics"]
	var s := "[color=%s]共通マーク（%d）[/color]：%s\n訪問ごとに訪問倍率%s" % [UI.hexc(UI.C_GOLD), names.size(), "、".join(names),
		"+3.0（R38で置換）" if rel.has("R38") else "+0.5"]
	var extra := []
	if rel.has("R08"): extra.append("R08：1回以上訪問でA+1")
	if rel.has("R35"): extra.append("R35：訪問した異なるマーク数だけ次回歩数+")
	if rel.has("R21"): extra.append("R21：訪問したマークのポーズ基礎+6（再訪問は対象外）")
	if rel.has("R36"): extra.append("R36：マークで移動を終えたら的中扱い")
	if rel.has("R38"): extra.append("R38：未マークへの訪問報酬は0")
	if not extra.is_empty():
		s += "\n" + "\n".join(extra)
	return s


func _node_text(p: int) -> String:
	var s := _pose_text(p)
	var c := Game.cyc()
	var relics: Array = Game.state["relics"] if c.is_empty() else c["relics"]
	var bases: Array = Game.state["B"] if c.is_empty() else c["B"]
	var step := 1 if c.is_empty() or Game.phase() == "plan" else int(c["anim"]) + 1
	var opts := Logic.step_options(p, step, relics, bases)
	var tw := Logic.total_weight(opts)
	var parts := []
	var kinds := {"cw": "時計回り", "ccw": "反時計回り", "cross": "跨ぎ", "self": "自己ループ"}
	for o in opts:
		parts.append("%s→%s %s(%d%%)" % [kinds[o["kind"]], D.pose_name(o["to"]),
			"強制" if o.get("forced", false) else "重み%d" % o["w"], roundi(100.0 * o["w"] / tw)])
	s += "\n[color=%s]%d歩目の出口：\n%s[/color]" % [UI.hexc(UI.C_SUB), step, "\n".join(parts)]
	if not c.is_empty() and c["marks"].has(p):
		s += "\n[color=%s]★共通マーク[/color]" % UI.hexc(UI.C_GOLD)
	return s


# ================================================================ 操作

func _on_node_hovered(p: int) -> void:
	_hover(_node_text(p) if p >= 0 else "")


func _on_node_clicked(p: int) -> void:
	if Game.phase() != "plan" or _dice_anim > 0.0:
		return
	Sfx.play("click")
	if _r35_mode:
		_r35_mode = false
		Game.set_start(p)
	else:
		Game.set_guess(p)


func _on_roll() -> void:
	Game.start_cycle()
	Sfx.play("dice")
	_dice_anim = 0.5 / _speed()
	_char_pose = Game.state["cur"]
	refresh()
	_plan_tutorials()


func _on_reroll() -> void:
	Game.reroll()
	Sfx.play("dice")
	_dice_anim = 0.5 / _speed()
	refresh()
	if Game.cyc()["n0"] == 0:
		_queue_tut("t8")


func _plan_tutorials() -> void:
	_queue_tut("t3")
	_queue_tut("t4")
	var c := Game.cyc()
	if not c["marks"].is_empty():
		_queue_tut("t7")
	if c["n0"] == 0:
		_queue_tut("t8")


func _on_buy_relic(i: int) -> void:
	var id: String = Game.state["shop"]["relics"][i]["id"]
	var full: bool = Game.state["relics"].size() >= Game.slots()
	var warn := _combo_warning(id)
	if warn != "" and not full:
		_dialog("組み合わせの確認", warn.strip_edges(), [
			["購入する", func():
				Game.buy_relic(i)
				Sfx.play("buy")],
			["やめる", func(): pass]])
		return
	Game.buy_relic(i)
	if not full:
		Sfx.play("buy")


func _confirm_discard(id: String) -> void:
	_dialog("レリックをすてる", "%s を破棄しますか？\n無料ですが返金はありません。\n既に得た成長・資源は失いません。" % D.relic_name(id), [
		["すてる", func():
			_selected_relic = ""
			Game.discard_relic(id)],
		["やめる", func(): pass]])


func _on_confirm() -> void:
	_r35_mode = false
	Game.confirm_plan()
	_start_moving()


# ================================================================ 移動演出

func _start_moving() -> void:
	if _moving_running:
		return
	_moving_running = true
	_skip = false
	var c := Game.cyc()
	var steps: Array = c["route"]["steps"]
	var preview := Game.preview_settlement(false)
	var visits: Array = preview["visits"]
	var i: int = c["anim"]
	_char_pose = _anim_pos()
	refresh()
	while i < steps.size():
		if not _skip:
			await get_tree().create_timer(0.5 / _speed(), false).timeout
			if not is_visible_in_tree() or Game.phase() != "moving":
				_moving_running = false
				return
		var st: Dictionary = steps[i]
		_char_pose = st["to"]
		i += 1
		Game.set_anim(i)
		if not _skip:
			Sfx.play("step")
			_float_reward(visits[i - 1])
		refresh()
	_moving_running = false
	if not _skip:
		await get_tree().create_timer(0.3 / _speed(), false).timeout
	Game.finish_moving()
	if Game.phase() == "report":
		_on_settled()


func _float_reward(v: Dictionary) -> void:
	var p: int = v["pose"]
	var l := UI.label("", 16)
	if v["zero"] != "":
		l.text = "0（%s）" % v["zero"]
		l.add_theme_color_override("font_color", UI.C_SUB)
	else:
		l.text = "+%s" % Logic.fmt_num(snappedf(v["V"], 0.01))
		l.add_theme_color_override("font_color", UI.C_GOLD)
	l.add_theme_color_override("font_outline_color", Color("0a1220"))
	l.add_theme_constant_override("outline_size", 5)
	l.position = net.position + net.node_center(p) + Vector2(-20, -50)
	_float_layer.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 30, 2.0 / _speed())
	tw.tween_property(l, "modulate:a", 0.0, 2.0 / _speed()).set_delay(1.0 / _speed())
	tw.chain().tween_callback(l.queue_free)


func _on_settled() -> void:
	var rep: Dictionary = Game.state["report"]
	Sfx.play("hit" if rep["hit"] else "miss")
	if _w_tween:
		_w_tween.kill()
	_w_tween = create_tween()
	_w_tween.tween_method(func(v: float):
		_shown_w = v
		_refresh_top(), float(Game.cyc()["W0"]), float(Game.state["W"]), 0.8 / _speed())
	refresh()


# ================================================================ モーダル

func _refresh_modal() -> void:
	var ph := Game.phase()
	var kind := ""
	if ph == "idle" and Game.state["pending_swap"] >= 0:
		kind = "swap"
	elif ph == "r33":
		kind = "r33"
	elif ph == "report":
		kind = "report"
	if kind == _modal_kind:
		return
	_modal_kind = kind
	for c in _modal_layer.get_children():
		c.queue_free()
	match kind:
		"swap": _build_swap()
		"r33": _build_r33()
		"report": _build_report()


func _modal_frame(parent: Control, title: String, w: float, h: float) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.flat(Color("10203a"), Color("6aa8d0"), 2, 8, 14))
	p.position = Vector2((1280 - w) / 2.0, (720 - h) / 2.0)
	p.size = Vector2(w, h)
	dim.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UI.label(title, 20, UI.C_YU))
	return v


func _dialog(title: String, body: String, buttons: Array, parent: Control = null) -> Control:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(parent if parent else _tut_layer).add_child(host)
	var v := _modal_frame(host, title, 560, 260)
	var r := UI.rich(16)
	r.text = body
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(r)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	for b in buttons:
		var cb: Callable = b[1]
		row.add_child(UI.button(b[0], func():
			host.queue_free()
			cb.call()))
	return host


func _build_swap() -> void:
	var i: int = Game.state["pending_swap"]
	var id: String = Game.state["shop"]["relics"][i]["id"]
	var v := _modal_frame(_modal_layer, "レリック枠が満杯です", 640, 400)
	var r := UI.rich(15)
	r.custom_minimum_size = Vector2(0, 110)
	var t := "購入：" + UI.relic_text(id).replace("\n", "　", ) + "\n入れ替えて破棄するレリックを選んでください（購入と同時に確定、返金なし）。"
	if id in ["R39", "R40"] or Game.state["relics"].has("R39") or Game.state["relics"].has("R40"):
		t += "\n[color=%s]R39とR40を併用すると、おさかな報酬は常に0になります（G=4）。[/color]" % UI.hexc(UI.C_BAD)
	r.text = t
	v.add_child(r)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for oid in Game.state["relics"]:
		var b := UI.button("%s %s" % [oid, D.relic_name(oid)], func():
			Game.confirm_swap(oid)
			Sfx.play("buy"), 13)
		b.icon = UI.relic_icon(oid)
		b.custom_minimum_size = Vector2(196, 36)
		b.tooltip_text = D.relic_effect(oid)
		grid.add_child(b)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UI.button("キャンセル", Game.cancel_swap))
	v.add_child(row)


func _build_r33() -> void:
	var c := Game.cyc()
	var miss := Game.preview_settlement(false)
	var hit := Game.preview_settlement(true)
	var v := _modal_frame(_modal_layer, "運命の結晶（R33）", 560, 300)
	var r := UI.rich(16)
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.text = "終点：[b]%s[/b]　予想：%s\n現在の結果：[color=%s]はずれ[/color]\n\nアクアマリンを [b]%d個[/b] 支払って的中扱いにできます（所持 %d → %d）。\n終点・経路は変わりません。\n\nおさかな報酬：はずれのまま %s ／ 的中化後 [color=%s]%s[/color]" % [
		D.pose_name(c["route"]["end"]), D.pose_name(c["q"]), UI.hexc(UI.C_BAD), D.R33_COST, Game.state["A"], Game.state["A"] - D.R33_COST,
		UI.num(miss["F"]), UI.hexc(UI.C_GOLD), UI.num(hit["F"])]
	v.add_child(r)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	row.add_child(UI.button("使う（A%d）" % D.R33_COST, func():
		Game.r33_choose(true)
		_on_settled()))
	row.add_child(UI.button("使わない", func():
		Game.r33_choose(false)
		_on_settled()))
	v.add_child(row)


func _build_report() -> void:
	var st := Game.state
	var rep: Dictionary = st["report"]
	var c := Game.cyc()
	var v := _modal_frame(_modal_layer, "精算　サイクル %d" % st["C"], 760, 560)
	var r := UI.rich(14)
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.text = _report_text(rep, c)
	v.add_child(r)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UI.button("  つぎへ  ", _close_report, 18))
	v.add_child(row)
	_queue_tut("t5")
	_queue_tut("t6")


func _report_text(rep: Dictionary, c: Dictionary) -> String:
	var gold := UI.hexc(UI.C_GOLD)
	var sub := UI.hexc(UI.C_SUB)
	var s := ""
	var res := "[color=%s]的中！[/color]" % gold if rep["hit"] else "[color=%s]はずれ[/color]" % UI.hexc(UI.C_BAD)
	if rep.get("r33_used", false):
		res += "（R33で的中化）"
	s += "[b]%s[/b]　開始 %s → 終点 %s　予想 %s\n" % [res, D.pose_name(c["s"]), D.pose_name(rep["end"]), D.pose_name(c["q"])]
	var path := [D.pose_name(c["s"])]
	for st in c["route"]["steps"]:
		path.append(("[color=%s]" % UI.hexc(UI.C_LINK) + D.pose_name(st["to"]) + "[/color]") if st["extra"] else D.pose_name(st["to"]))
	s += "[color=%s]経路：%s\n%s[/color]\n\n" % [sub, " → ".join(path), Logic.stop_reason_text(c["route"]["stop"])]
	if not rep["visits"].is_empty():
		s += "[table=6][cell][b]歩[/b]  [/cell][cell][b]ポーズ[/b]  [/cell][cell][b]基礎[/b]  [/cell][cell][b]倍率J[/b]  [/cell][cell][b]報酬V[/b]  [/cell][cell][b]内訳・ゼロ化理由[/b][/cell]"
		for vi in rep["visits"]:
			var note: String = vi["parts"]
			if vi["zero"] != "":
				note = "[color=%s]0：%s[/color]" % [UI.hexc(UI.C_BAD), vi["zero"]]
			var tag := "追%d" % vi["t"] if vi["extra"] else str(vi["t"])
			s += "[cell]%s  [/cell][cell]%s%s  [/cell][cell]%s  [/cell][cell]%s  [/cell][cell]%s  [/cell][cell]%s[/cell]" % [
				tag, D.pose_name(vi["pose"]), "★" if vi["mark"] else "", Logic.fmt_num(vi["B"]), Logic.fmt_num(vi["J"]),
				Logic.fmt_num(snappedf(vi["V"], 0.01)), note]
		s += "[/table]\n"
	else:
		s += "移動なし（訪問報酬 0）\n"
	s += "\nS=%s　G=%d　M=%d　→　F=floor(S×G×M)=[color=%s][b]%s[/b][/color]\n" % [
		Logic.fmt_num(snappedf(rep["S"], 0.01)), rep["G"], rep["M"], gold, UI.num(rep["F"])]
	s += "おさかな %s → %s\n" % [UI.num(c["W0"]), UI.num(c["W0"] + rep["F"])]
	var a_parts := []
	for it in rep["a_items"]:
		a_parts.append("%s +%d" % [it[0], it[1]])
	s += "アクアマリン +%d（%s）\n" % [rep["a_total"], "、".join(a_parts)]
	if rep["g_items"].is_empty():
		s += "[color=%s]基礎値成長：なし[/color]\n" % sub
	else:
		var g_parts := []
		for it in rep["g_items"]:
			g_parts.append("%s %s+%s" % [it[0], D.pose_name(it[1]), Logic.fmt_num(it[2])])
		s += "基礎値成長：%s\n" % "、".join(g_parts)
	s += "[color=%s]次サイクル：跨ぎ回数Kprev=%d、マーク訪問数Mprev=%d[/color]\n" % [sub, rep["crosses"], rep["mark_distinct"]]
	var ended: Dictionary = Game.state["ended"]
	if rep.get("round_adv", false):
		s += "\n[color=%s][b]ラウンド達成！[/b] 次は %s（目標 %s）。レリック枠+2、無料更新権+1。[/color]" % [
			gold, D.round_name(Game.state["r"]), UI.num(Game.target())]
	elif not ended.is_empty():
		if ended["cleared"]:
			s += "\n[color=%s][b]最終ラウンド達成！[/b][/color]" % gold
		else:
			s += "\n[color=%s][b]目標未達…[/b] 目標 %s／所持 %s（不足 %s）[/color]" % [
				UI.hexc(UI.C_BAD), UI.num(ended["target"]), UI.num(ended["W"]), UI.num(ended["short"])]
	return s


func _close_report() -> void:
	var adv: bool = Game.state["report"].get("round_adv", false)
	Game.close_report()
	_char_pose = Game.state["cur"]
	if Game.phase() == "ended":
		run_ended.emit()
		return
	if adv:
		Sfx.play("clear")
		if Game.tut_seen("t9"):
			_dialog("ラウンド %d" % Game.state["r"], "[b]%s[/b]\n目標：%s おさかな\nレリック枠 %d・無料更新権 %d" % [
				D.round_name(Game.state["r"]), UI.num(Game.target()), Game.slots(), Game.state["free_refresh"]], [["OK", func(): pass]])
		else:
			_queue_tut("t9")
	refresh()


# ---------------------------------------------------------------- チュートリアル

func _queue_tut(key: String) -> void:
	if Game.tut_seen(key) or _tut_queue.has(key):
		return
	_tut_queue.append(key)
	if _tut_queue.size() == 1:
		_show_next_tut()


func _show_next_tut() -> void:
	if _tut_queue.is_empty():
		return
	var key: String = _tut_queue[0]
	var text: String = D.TUTORIAL[key]
	var rel: Array = Game.state["relics"]
	if key == "t5":
		var zs := []
		if rel.has("R37"): zs.append("R37：はずれ時のおさかな報酬は0")
		if rel.has("R38"): zs.append("R38：未マークへの訪問報酬は0")
		if rel.has("R39"): zs.append("R39：全移動の上限は3歩")
		if rel.has("R40"): zs.append("R40：1〜3歩目の訪問報酬は0")
		if not zs.is_empty():
			text += "\n[color=%s]所持中のゼロ報酬条件：\n%s[/color]" % [UI.hexc(UI.C_BAD), "\n".join(zs)]
	if key == "t7" and rel.has("R38"):
		text += "\n[color=%s]R38所持中は+0.5ではなく+3.0に置換されます（未マークは報酬0）。[/color]" % UI.hexc(UI.C_GOLD)
	_dialog("チュートリアル", text, [["OK", func():
		Game.mark_tut(key)
		_tut_queue.pop_front()
		_show_next_tut()]])
