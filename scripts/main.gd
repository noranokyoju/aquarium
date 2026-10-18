extends Control
## 画面遷移（タイトル・プレイ・エンディング・結果・設定）

const D := preload("res://scripts/data.gd")
const GameScreen := preload("res://scripts/ui/game_screen.gd")
const DebugRelics := preload("res://scripts/ui/debug_relics.gd")

var _title: Control
var _game: GameScreen
var _ending: Control
var _result: Control
var _settings: Control
var _confirm: Control
var _debug: DebugRelics
var _title_msg: Label
var _continue_btn: Button
var _screen := ""
var _focus_lost := false


func _ready() -> void:
	theme = UI.build_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_title = _build_title()
	add_child(_title)
	_game = GameScreen.new()
	_game.open_settings.connect(_open_settings)
	_game.open_debug.connect(func(): _debug.open())
	_game.go_title.connect(func(): _show("title"))
	_game.run_ended.connect(_on_run_ended)
	add_child(_game)
	_ending = Control.new()
	_ending.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ending)
	_result = Control.new()
	_result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_result)
	_settings = _build_settings()
	add_child(_settings)
	_confirm = Control.new()
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_confirm)
	_debug = DebugRelics.new()
	add_child(_debug)
	_show("title")
	Sfx.play_bgm()


func _process(delta: float) -> void:
	if _screen == "game":
		Game.add_play_time(delta)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focus_lost = true
			Game.save_game()
			_update_pause()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focus_lost = false
			_update_pause()
		NOTIFICATION_WM_CLOSE_REQUEST:
			Game.save_game()


func _update_pause() -> void:
	if is_inside_tree():
		get_tree().paused = _focus_lost or (_settings != null and _settings.visible) or (_debug != null and _debug.visible)


func _show(name: String) -> void:
	if _screen == "game":
		Game.save_game()
	_screen = name
	_title.visible = name == "title"
	_game.visible = name == "game"
	_ending.visible = name == "ending"
	_result.visible = name == "result"
	if name == "title":
		_refresh_title()


# ================================================================ タイトル

func _build_title() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = UI.background()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.1, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var ch := TextureRect.new()
	var a := AtlasTexture.new()
	a.atlas = UI.chars()
	a.region = Rect2(120, 36, 400, 400)
	ch.texture = a
	ch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ch.position = Vector2(760, 230)
	ch.size = Vector2(440, 440)
	root.add_child(ch)
	var title := UI.label("ゆらゆらアクアリウム", 64, Color("dff4ff"))
	title.add_theme_color_override("font_outline_color", Color("10304a"))
	title.add_theme_constant_override("outline_size", 12)
	title.position = Vector2(110, 120)
	root.add_child(title)
	var sub := UI.label("サイコロで泳いで、終点を予想する水槽ローグライト", 20, UI.C_YU)
	sub.add_theme_color_override("font_outline_color", Color("10304a"))
	sub.add_theme_constant_override("outline_size", 6)
	sub.position = Vector2(116, 210)
	root.add_child(sub)
	var v := VBoxContainer.new()
	v.position = Vector2(140, 300)
	v.custom_minimum_size = Vector2(280, 0)
	v.add_theme_constant_override("separation", 14)
	root.add_child(v)
	var start := UI.button("はじめる", _on_title_start, 24)
	start.custom_minimum_size = Vector2(280, 56)
	v.add_child(start)
	_continue_btn = UI.button("つづきから", _on_title_continue, 24)
	_continue_btn.custom_minimum_size = Vector2(280, 56)
	v.add_child(_continue_btn)
	var st := UI.button("設定", _open_settings, 24)
	st.custom_minimum_size = Vector2(280, 56)
	v.add_child(st)
	_title_msg = UI.label("", 16, UI.C_GOLD)
	_title_msg.add_theme_color_override("font_outline_color", Color("10304a"))
	_title_msg.add_theme_constant_override("outline_size", 5)
	_title_msg.position = Vector2(140, 530)
	root.add_child(_title_msg)
	var ver := UI.label("仕様 v%s" % D.SPEC_VERSION, 14, UI.C_SUB)
	ver.position = Vector2(16, 690)
	root.add_child(ver)
	return root


func _refresh_title() -> void:
	var s := Game.save_status()
	_continue_btn.disabled = s != "ok"
	if s == "incompatible":
		_title_msg.text = "互換性のない進行データがあります。「はじめる」で新規ランを始めてください。"
	else:
		_title_msg.text = ""


func _on_title_start() -> void:
	if Game.save_status() == "ok":
		_confirm_dialog("新しくはじめる", "進行中のランのデータは消えます。よろしいですか？", _start_new)
	else:
		_start_new()


func _start_new() -> void:
	Game.new_run()
	_show("game")
	_game.enter()


func _on_title_continue() -> void:
	if not Game.load_game():
		_refresh_title()
		return
	if Game.phase() == "ended":
		_show_result()
		return
	_show("game")
	_game.enter()


func _confirm_dialog(title: String, body: String, ok: Callable) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.flat(Color("10203a"), Color("6aa8d0"), 2, 8, 16))
	p.position = Vector2(390, 250)
	p.size = Vector2(500, 200)
	dim.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UI.label(title, 20, UI.C_YU))
	var l := UI.label(body, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(UI.button("はい", func():
		dim.queue_free()
		ok.call()))
	row.add_child(UI.button("いいえ", dim.queue_free))


# ================================================================ 設定

func _build_settings() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.flat(Color("10203a"), Color("6aa8d0"), 2, 8, 20))
	p.position = Vector2(390, 200)
	p.size = Vector2(500, 320)
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(UI.label("設定", 22, UI.C_YU))
	for item in [["master", "マスター音量"], ["bgm", "BGM音量"], ["se", "SE音量"]]:
		var key: String = item[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := UI.label(item[1], 16)
		l.custom_minimum_size = Vector2(130, 0)
		row.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0
		sl.max_value = 10
		sl.step = 1
		sl.custom_minimum_size = Vector2(220, 24)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.name = key
		row.add_child(sl)
		var val := UI.label("", 16)
		val.custom_minimum_size = Vector2(30, 0)
		row.add_child(val)
		sl.value_changed.connect(func(x: float):
			Game.settings[key] = int(x)
			val.text = str(int(x))
			Sfx.apply_volumes())
		sl.drag_ended.connect(func(_c: bool):
			Game.save_settings()
			Sfx.play("click"))
		v.add_child(row)
	var sp := HBoxContainer.new()
	sp.add_theme_constant_override("separation", 12)
	var sl2 := UI.label("演出速度", 16)
	sl2.custom_minimum_size = Vector2(130, 0)
	sp.add_child(sl2)
	for s in [[1, "標準"], [2, "2倍"], [4, "4倍"]]:
		var b := Button.new()
		b.text = s[1]
		b.toggle_mode = true
		b.name = "speed%d" % s[0]
		var spd: int = s[0]
		b.pressed.connect(func():
			Game.settings["speed"] = spd
			Game.save_settings()
			_sync_settings())
		sp.add_child(b)
	sp.name = "speed_row"
	v.add_child(sp)
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	close_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var close_btn := UI.button("とじる", _close_settings)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	close_row.add_child(close_btn)
	v.add_child(close_row)
	return root


func _sync_settings() -> void:
	for key in ["master", "bgm", "se"]:
		var sl := _settings.find_child(key, true, false) as HSlider
		if sl:
			sl.set_value_no_signal(Game.settings[key])
			var val := sl.get_parent().get_child(2) as Label
			val.text = str(Game.settings[key])
	for spd in [1, 2, 4]:
		var b := _settings.find_child("speed%d" % spd, true, false) as Button
		if b:
			b.set_pressed_no_signal(Game.settings["speed"] == spd)
	if _game:
		_game.refresh()


func _open_settings() -> void:
	_sync_settings()
	_settings.visible = true
	_update_pause()


func _close_settings() -> void:
	Game.save_settings()
	_settings.visible = false
	_update_pause()


# ================================================================ エンディング・結果

func _on_run_ended() -> void:
	var e: Dictionary = Game.state["ended"]
	if e.get("cleared", false):
		_play_ending()
	else:
		_show_result()


func _play_ending() -> void:
	for c in _ending.get_children():
		c.queue_free()
	_show("ending")
	Sfx.play("clear")
	var bg := TextureRect.new()
	bg.texture = UI.background()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ending.add_child(bg)
	# 魚が背景を満たす
	var fish_layer := Control.new()
	fish_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fish_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ending.add_child(fish_layer)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var fishes := [UI.misc(7, 0), UI.misc(0, 1), UI.misc(1, 1)]
	for i in 70:
		var f := TextureRect.new()
		f.texture = fishes[i % 3]
		f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var sz := rng.randf_range(28, 56)
		f.size = Vector2(sz, sz)
		var y := rng.randf_range(20, 640)
		var dir := 1 if i % 2 == 0 else -1
		f.flip_h = dir < 0
		f.position = Vector2(-80 if dir > 0 else 1300, y)
		f.modulate.a = 0.0
		fish_layer.add_child(f)
		var tw := f.create_tween()
		tw.tween_interval(i * 0.07)
		tw.tween_property(f, "modulate:a", 1.0, 0.3)
		var target_x := rng.randf_range(60, 1180)
		tw.parallel().tween_property(f, "position:x", target_x, rng.randf_range(1.5, 3.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(f, "position:y", y + rng.randf_range(-12, 12), 1.6).set_trans(Tween.TRANS_SINE)
	var ch := TextureRect.new()
	var a := AtlasTexture.new()
	a.atlas = UI.chars()
	a.region = Rect2(640 + 120, 480 + 36, 400, 400)   # P07 てをふる
	ch.texture = a
	ch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ch.position = Vector2(440, 180)
	ch.size = Vector2(400, 400)
	_ending.add_child(ch)
	var l1 := UI.label("ゆらゆら、きょうもいいひ。", 36, Color("ffffff"))
	var l2 := UI.label("水槽がおさかなでいっぱいになりました。", 24, UI.C_GOLD)
	for l in [l1, l2]:
		l.add_theme_color_override("font_outline_color", Color("10304a"))
		l.add_theme_constant_override("outline_size", 10)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(1280, 50)
		l.modulate.a = 0.0
		_ending.add_child(l)
	l1.position = Vector2(0, 70)
	l2.position = Vector2(0, 600)
	var tw := _ending.create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(l1, "modulate:a", 1.0, 1.0)
	tw.tween_property(l2, "modulate:a", 1.0, 1.0)
	tw.tween_interval(5.0)
	tw.tween_callback(_show_result)
	var click := Button.new()
	click.flat = true
	click.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	click.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	click.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	click.pressed.connect(func():
		tw.kill()
		_show_result())
	_ending.add_child(click)


func _show_result() -> void:
	if _screen == "result":
		return
	for c in _result.get_children():
		c.queue_free()
	_show("result")
	var e: Dictionary = Game.state["ended"]
	var bg := ColorRect.new()
	bg.color = UI.C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result.add_child(bg)
	var p := PanelContainer.new()
	p.position = Vector2(140, 40)
	p.size = Vector2(1000, 640)
	p.add_theme_stylebox_override("panel", UI.flat(Color("10203a"), Color("6aa8d0"), 2, 10, 20))
	_result.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var cleared: bool = e["cleared"]
	v.add_child(UI.label("クリア！" if cleared else "ゲームオーバー", 36, UI.C_GOLD if cleared else UI.C_BAD))
	if not cleared:
		v.add_child(UI.label("ラウンド%d %s の目標に届きませんでした。目標 %s／最終所持 %s（不足 %s）" % [
			e["r"], D.round_name(e["r"]), UI.num(e["target"]), UI.num(e["W"]), UI.num(e["short"])], 17, UI.C_BAD))
	var r := UI.rich(16)
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var s := "[table=4]"
	var rows := [
		["有効プレイ時間", UI.fmt_time(e["play_time"])], ["到達ラウンド", "%d/5" % e["r"]],
		["完了サイクル", "%d" % e["C"]], ["最終おさかな", UI.num(e["W"])],
		["最終アクアマリン", str(e["A"])], ["累計獲得おさかな", UI.num(e["T"])],
		["最高サイクル報酬", UI.num(e["best_F"])], ["最高連続的中", str(e["best_H"])],
	]
	for row in rows:
		s += "[cell][color=%s]%s[/color]　[/cell][cell][b]%s[/b]　　　[/cell]" % [UI.hexc(UI.C_SUB), row[0], row[1]]
	s += "[/table]\n\n[color=%s]所持レリック[/color]\n" % UI.hexc(UI.C_SUB)
	var names := []
	for id in e["relics"]:
		names.append("%s %s" % [id, D.relic_name(id)])
	s += "、".join(names) if not names.is_empty() else "なし"
	s += "\n\n[color=%s]ポーズ（基礎値／強化回数）[/color]\n[table=5]" % UI.hexc(UI.C_SUB)
	for i in D.POSE_COUNT:
		s += "[cell]%s %s／%d　[/cell]" % [D.pose_name(i), Logic.fmt_num(e["B"][i]), e["L"][i]]
	s += "[/table]"
	r.text = s
	v.add_child(r)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	row.add_child(UI.button("  もういちど  ", _start_new, 20))
	row.add_child(UI.button("  タイトルへ  ", func(): _show("title"), 20))
	v.add_child(row)
