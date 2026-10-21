extends Node
## 画面確認用：各場面のスクリーンショットを保存する
## godot --path . res://tests/shot.tscn -- <出力先ディレクトリ>

var out := "user://shots"
var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://main.tscn").instantiate()
	add_child(main)
	await _frames(10)
	await _shot("01_title")
	main._start_new()
	await _frames(10)
	await _shot("02_idle_tutorial")
	Game.mark_tut("done")
	Game.mark_tut("mark")
	Game.state["tut"] = ""
	Game.state["relics"] = ["R02", "R15", "R01", "R19", "R30", "R03"]
	Game.state["A"] = 5
	Game.state["W"] = 120
	Game.state["B"][6] = 30.0
	Game.changed.emit()
	await _frames(5)
	main._game._hover(main._game._node_text(0))
	await _shot("03_idle")
	main._game._hover("")
	main._debug.open()
	main._debug._toggle("R31")
	main._debug._info.text = UI.relic_text("R31")
	await _frames(5)
	await _shot("03d_debug")
	main._debug._toggle("R31")
	main._debug.close()
	get_tree().paused = false
	main._game._on_roll()
	await get_tree().create_timer(0.3).timeout
	await _shot("03b_rolling")
	await get_tree().create_timer(0.45).timeout
	await _shot("03c_rolled")
	await get_tree().create_timer(0.45).timeout
	await _shot("04_plan")
	main._game._r35_mode = true
	main._game.refresh()
	await _frames(5)
	await _shot("04b_r19")
	main._game._r35_mode = false
	main._game.refresh()
	main._game.net.hovered = 6
	main._game._on_node_clicked(6)
	await get_tree().create_timer(0.1).timeout
	await _shot("04c_guess")
	main._game.net.hovered = -1
	Game.cyc()["n0"] = 4
	main._game._on_confirm()
	await get_tree().create_timer(1.15).timeout
	await _shot("05_moving")
	await get_tree().create_timer(1.9).timeout
	await _shot("05b_tally")
	main._game._skip = true
	await get_tree().create_timer(1.0).timeout
	await _shot("06_report")
	main._game._close_report()
	await _frames(5)
	Game.state["c"] = 9
	Game.state["W"] = 0
	main._game._on_roll()
	await get_tree().create_timer(1.2).timeout
	Game.set_guess(0)
	main._game._on_confirm()
	main._game._skip = true
	await get_tree().create_timer(1.0).timeout
	main._game._close_report()
	await _frames(10)
	await _shot("07_result_fail")
	Game.state["ended"]["cleared"] = true
	main._play_ending()
	await get_tree().create_timer(4.0).timeout
	await _shot("08_ending")
	main._open_settings()
	await _frames(5)
	await _shot("09_settings")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
