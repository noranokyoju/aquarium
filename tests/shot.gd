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
	for k in ["t1", "t2", "t3", "t4", "t5", "t6", "t7", "t8", "t9"]:
		Game.mark_tut(k)
	main._game._tut_queue.clear()
	for c in main._game._tut_layer.get_children():
		c.queue_free()
	Game.state["relics"] = ["R02", "R15", "R17", "R19", "R32", "R03"]
	Game.state["A"] = 5
	Game.state["W"] = 120
	Game.state["B"][6] = 30.0
	Game.changed.emit()
	await _frames(5)
	main._game._hover(main._game._node_text(0))
	await _shot("03_idle")
	main._game._hover("")
	main._game._on_roll()
	await get_tree().create_timer(0.7).timeout
	await _shot("04_plan")
	main._game._on_confirm()
	await get_tree().create_timer(1.3).timeout
	await _shot("05_moving")
	main._game._skip = true
	await get_tree().create_timer(1.0).timeout
	await _shot("06_report")
	main._game._close_report()
	await _frames(5)
	Game.state["c"] = 9
	Game.state["W"] = 0
	main._game._on_roll()
	await get_tree().create_timer(0.7).timeout
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
