extends Node
## 移動中にタイトルへ戻り「つづきから」で再開できるかの確認

func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._start_new()
	main._game._tut_queue.clear()
	Game.state["relics"] = ["R33", "R02"]
	Game.state["A"] = 10
	main._game._on_roll()
	await get_tree().create_timer(0.6).timeout
	Game.cyc()["n0"] = 6
	Game.set_guess(0)
	main._game._on_confirm()
	await get_tree().create_timer(1.2).timeout
	var anim: int = Game.cyc()["anim"]
	var path = Game.cyc()["route"]["steps"].duplicate(true)
	main._show("title")
	await get_tree().create_timer(1.5).timeout
	print("anim before title=", anim, " after wait=", Game.cyc()["anim"], " phase=", Game.phase())
	main._on_title_continue()
	print("resumed phase=", Game.phase(), " anim=", Game.cyc()["anim"], " same route=", Game.cyc()["route"]["steps"] == path)
	await get_tree().create_timer(4.0).timeout
	print("final phase=", Game.phase(), " C=", Game.state["C"], " modal=", main._game._modal_kind)
	get_tree().quit()
