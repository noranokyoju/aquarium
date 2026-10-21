extends Node
## ラン状態・操作・保存（Autoload: Game）

signal changed

const D := preload("res://scripts/data.gd")
const SAVE_PATH := "user://save.dat"
const SETTINGS_PATH := "user://settings.dat"

var state: Dictionary = {}
var settings: Dictionary = {}
var settings_path := SETTINGS_PATH   # テストでは差し替えて実際の設定を上書きしない
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	load_settings()


# ---------------------------------------------------------------- ラン

func new_run() -> void:
	rng.randomize()
	var b := []
	var l := []
	for i in D.POSE_COUNT:
		b.append(D.BASE_INIT[D.area_of(i)])
		l.append(0)
	state = {
		"version": D.SPEC_VERSION,
		"W": 0, "A": 0, "T": 0, "r": 1, "c": 0, "C": 0, "cur": 0,
		"B": b, "L": l, "H": 0, "best_H": 0, "best_F": 0, "play_time": 0.0,
		"relics": [], "first_free": true, "U": 0, "free_refresh": 1, "Kprev": 0, "Mnext": 0, "Vprev": 0,
		"shop": {}, "pending_swap": -1, "phase": "idle", "cyc": {}, "report": {}, "ended": {},
		"tut": "" if tut_seen("done") else D.TUT_STEPS[0],
	}
	_draw_shop()
	_commit()


func has_run() -> bool:
	return not state.is_empty()


func phase() -> String:
	return state.get("phase", "")


func target() -> int:
	return D.round_target(state["r"])


func slots() -> int:
	return D.relic_slots(state["r"])


func can_shop() -> bool:
	return phase() == "idle" and state["pending_swap"] < 0


func add_play_time(dt: float) -> void:
	if has_run() and phase() != "ended":
		state["play_time"] += dt


# ---------------------------------------------------------------- ショップ

func _draw_shop() -> void:
	var rel := []
	var ids := []
	var fixed := tut_step() == D.TUT_STEPS[0]   # 初回プレイの初期商品は固定
	for i in 3:
		var id: String = D.TUT_SHOP_RELICS[i] if fixed else Logic.draw_relic(state["relics"], ids, rng)
		if id != "":
			ids.append(id)
		rel.append({"id": id, "sold": false})
	_mark_seen(ids)
	var poses := []
	for p in (D.TUT_SHOP_POSES if fixed else Logic.draw_pose_slots(state["L"], rng)):
		poses.append({"p": p, "sold": false})
	state["shop"] = {"relics": rel, "poses": poses}


func relic_cost(id: String) -> int:
	return 0 if state["first_free"] else D.relic_price(id)


func can_buy_relic(i: int) -> bool:
	var slot: Dictionary = state["shop"]["relics"][i]
	return can_shop() and tut_allows("relic") and slot["id"] != "" and not slot["sold"] and state["A"] >= relic_cost(slot["id"])


## 枠が満杯なら入れ替え選択に入る
func buy_relic(i: int) -> void:
	if not can_buy_relic(i):
		return
	if state["relics"].size() >= slots():
		state["pending_swap"] = i
		_commit()
		return
	_purchase_relic(i)
	_commit()


func confirm_swap(discard_id: String) -> void:
	var i: int = state["pending_swap"]
	if i < 0 or not state["relics"].has(discard_id):
		return
	var slot: Dictionary = state["shop"]["relics"][i]
	if slot["sold"] or state["A"] < relic_cost(slot["id"]):
		cancel_swap()
		return
	state["relics"].erase(discard_id)
	_purchase_relic(i)
	state["pending_swap"] = -1
	_commit()


func cancel_swap() -> void:
	state["pending_swap"] = -1
	_commit()


func _purchase_relic(i: int) -> void:
	var slot: Dictionary = state["shop"]["relics"][i]
	state["A"] -= relic_cost(slot["id"])
	state["first_free"] = false
	state["relics"].append(slot["id"])
	slot["sold"] = true
	_tut_advance("relic")


func can_buy_pose(i: int) -> bool:
	var slot: Dictionary = state["shop"]["poses"][i]
	var p: int = slot["p"]
	return can_shop() and tut_allows("pose") and p >= 0 and not slot["sold"] and state["L"][p] < D.L_MAX \
		and state["W"] >= Logic.pose_price(state["L"][p])


func buy_pose(i: int) -> void:
	if not can_buy_pose(i):
		return
	var slot: Dictionary = state["shop"]["poses"][i]
	var p: int = slot["p"]
	state["W"] -= Logic.pose_price(state["L"][p])
	state["B"][p] *= 1.5
	state["L"][p] += 1
	slot["sold"] = true
	_tut_advance("pose")
	_commit()


func refresh_cost() -> int:
	return Logic.refresh_price(state["U"])


func can_refresh() -> bool:
	return can_shop() and tut_allows("refresh") and (state["free_refresh"] > 0 or state["W"] >= refresh_cost())


func refresh_shop() -> void:
	if not can_refresh():
		return
	if state["free_refresh"] > 0:
		state["free_refresh"] -= 1
	else:
		state["W"] -= refresh_cost()
		state["U"] += 1
	_draw_shop()
	_tut_advance("refresh")
	_commit()


func discard_relic(id: String) -> void:
	if not can_shop() or in_tutorial() or not state["relics"].has(id):
		return
	state["relics"].erase(id)
	_commit()


## デバッグ用：所持レリックを置き換える（枠数などの制限は見ない）
func debug_set_relics(ids: Array) -> void:
	state["relics"] = ids.duplicate()
	_commit()


# ---------------------------------------------------------------- サイクル

func _roll(relics: Array) -> Array:
	var dice := [rng.randi_range(1, 6)]
	if relics.has("R31"):
		for i in int(Logic.val("R31", "dice")):
			dice.append(rng.randi_range(1, 6))
	return dice


func can_roll() -> bool:
	return can_shop() and tut_allows("roll")


func start_cycle() -> void:
	if not can_roll():
		return
	var relics: Array = state["relics"].duplicate()
	var cyc := {
		"W0": state["W"], "B": state["B"].duplicate(), "relics": relics, "H": state["H"],
		"Kprev": state["Kprev"], "Mnext": state.get("Mnext", 0),
		"Vprev": state.get("Vprev", 0), "s": state["cur"], "q": -1,
		"marks": Logic.draw_marks(Logic.mark_count(relics, state["Kprev"], state.get("Mnext", 0)), relics, rng),
		"dice": D.TUT_DICE.duplicate() if in_tutorial() else _roll(relics), "rerolled": false, "b": 0, "r27": 0, "n0": 0, "route": {}, "anim": 0,
		"hit": false, "r33_used": false,
	}
	cyc["n0"] = Logic.calc_n0(cyc, 0)
	state["cyc"] = cyc
	state["phase"] = "plan"
	_tut_advance("roll")
	_commit()


func cyc() -> Dictionary:
	return state.get("cyc", {})


func cyc_has(id: String) -> bool:
	return cyc().get("relics", []).has(id)


func can_reroll() -> bool:
	return phase() == "plan" and cyc_has("R03") and not cyc()["rerolled"]


func reroll() -> void:
	if not can_reroll():
		return
	var c := cyc()
	c["dice"] = _roll(c["relics"])
	c["rerolled"] = true
	c["n0"] = Logic.calc_n0(c, c["b"])
	_commit()


func can_buy_step() -> bool:
	if phase() != "plan" or not cyc_has("R30") or state["A"] < r32_cost():
		return false
	var c := cyc()
	return Logic.calc_n0(c, c["b"] + r32_steps()) > Logic.calc_n0(c, c["b"])


func r32_cost() -> int:
	return int(Logic.val("R30", "cost"))


func r32_steps() -> int:
	return int(Logic.val("R30", "steps"))


func r33_cost() -> int:
	return int(Logic.val("R33", "cost"))


func buy_step() -> void:
	if not can_buy_step():
		return
	var c := cyc()
	state["A"] -= r32_cost()
	c["b"] += r32_steps()
	c["n0"] = Logic.calc_n0(c, c["b"])
	_commit()


func r27_steps() -> int:
	return int(Logic.val("R27", "steps"))


func can_trade_mark() -> bool:
	if phase() != "plan" or not cyc_has("R27"):
		return false
	var c := cyc()
	if c["marks"].is_empty():
		return false
	var c2 := c.duplicate()
	c2["r27"] = c.get("r27", 0) + r27_steps()
	return Logic.calc_n0(c2, c["b"]) > Logic.calc_n0(c, c["b"])


## R27：ランダムな共通マーク1つを消して通常歩数を増やす
func trade_mark() -> void:
	if not can_trade_mark():
		return
	var c := cyc()
	var marks: Array = c["marks"]
	marks.remove_at(rng.randi_range(0, marks.size() - 1))
	c["r27"] = c.get("r27", 0) + r27_steps()
	c["n0"] = Logic.calc_n0(c, c["b"])
	_commit()


func set_start(p: int) -> void:
	if phase() == "plan" and cyc_has("R19"):
		cyc()["s"] = p
		_commit()


func set_guess(p: int) -> void:
	if phase() == "plan" and tut_allows("guess"):
		cyc()["q"] = p
		_commit()


func has_guess() -> bool:
	return phase() == "plan" and int(cyc()["q"]) >= 0


func confirm_plan() -> void:
	if not has_guess() or not tut_allows("reward"):
		return
	var c := cyc()
	c["route"] = Logic.generate_route(c, rng, D.TUT_PATH if in_tutorial() else [])
	_tut_advance("reward")
	c["anim"] = 0
	state["phase"] = "moving"
	_commit()


func set_anim(i: int) -> void:
	if phase() == "moving":
		cyc()["anim"] = i
		save_game()


## 移動演出の終了。R33 の選択が必要なら r33 フェーズへ
func finish_moving() -> void:
	if phase() != "moving":
		return
	var c := cyc()
	c["anim"] = c["route"]["steps"].size()
	c["hit"] = Logic.base_hit(c, c["route"]["end"])
	if not c["hit"] and cyc_has("R33") and state["A"] >= r33_cost():
		state["phase"] = "r33"
		_commit()
	else:
		_settle()


func r33_choose(use: bool) -> void:
	if phase() != "r33":
		return
	var c := cyc()
	if use and state["A"] >= r33_cost():
		state["A"] -= r33_cost()
		c["hit"] = true
		c["r33_used"] = true
	_settle()


func preview_settlement(hit: bool) -> Dictionary:
	var c := cyc()
	return Logic.compute_settlement(c, c["route"], hit)


func _settle() -> void:
	var c := cyc()
	var rep := Logic.compute_settlement(c, c["route"], c["hit"])
	var f: int = rep["F"]
	state["W"] = c["W0"] + f
	state["T"] += f
	state["A"] += rep["a_total"]
	for p in D.POSE_COUNT:
		state["B"][p] += rep["growth"][p]
	if c["hit"]:
		state["H"] += 1
	else:
		state["H"] = 0
	state["best_H"] = maxi(state["best_H"], state["H"])
	state["Kprev"] = rep["crosses"]
	state["Mnext"] = rep["m_next"]
	state["Vprev"] = rep["max_visits"]
	state["cur"] = rep["end"]
	state["c"] += 1
	state["C"] += 1
	state["best_F"] = maxi(state["best_F"], f)
	rep["round_adv"] = false
	rep["r33_used"] = c["r33_used"]
	rep["target"] = target()   # ラウンド遷移前の目標（精算画面のゲージ用）
	if state["c"] >= D.CYCLES_PER_ROUND:
		var r: int = state["r"]
		var tgt := target()
		if state["W"] >= tgt:
			if r >= D.ROUND_COUNT:
				state["ended"] = _result_snapshot(true)
			else:
				state["r"] = r + 1
				state["c"] = 0
				state["free_refresh"] += 1
				rep["round_adv"] = true
		else:
			state["ended"] = _result_snapshot(false)
	state["report"] = rep
	state["phase"] = "report"
	_commit()


func close_report() -> void:
	if phase() != "report":
		return
	state["phase"] = "ended" if not state["ended"].is_empty() else "idle"
	state["cyc"] = {}
	state["report"] = {}
	_tut_advance("play")
	_commit()


func _result_snapshot(cleared: bool) -> Dictionary:
	return {
		"cleared": cleared, "r": state["r"], "target": target(), "W": state["W"],
		"short": maxi(0, target() - state["W"]), "play_time": state["play_time"], "C": state["C"],
		"A": state["A"], "T": state["T"], "best_F": state["best_F"], "best_H": state["best_H"],
		"relics": state["relics"].duplicate(), "B": state["B"].duplicate(), "L": state["L"].duplicate(),
	}


# ---------------------------------------------------------------- 保存

func _commit() -> void:
	save_game()
	changed.emit()


func save_game() -> void:
	if state.is_empty():
		return
	state["rng_state"] = str(rng.state)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(var_to_str(state))
		f.close()


func _read_save() -> Variant:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return null
	var data = str_to_var(f.get_as_text())
	f.close()
	return data


## "none" / "ok" / "incompatible"
func save_status() -> String:
	var data = _read_save()
	if data == null:
		return "none"
	if typeof(data) != TYPE_DICTIONARY or data.get("version", "") != D.SPEC_VERSION:
		return "incompatible"
	return "ok"


func load_game() -> bool:
	var data = _read_save()
	if typeof(data) != TYPE_DICTIONARY or data.get("version", "") != D.SPEC_VERSION:
		return false
	state = data
	rng.state = int(state.get("rng_state", "0"))
	var ids := []
	for slot in state["shop"]["relics"]:
		if slot["id"] != "":
			ids.append(slot["id"])
	_mark_seen(ids)
	changed.emit()
	return true


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# ---------------------------------------------------------------- 設定・既読

func load_settings() -> void:
	settings = {"version": D.SPEC_VERSION, "master": 7, "bgm": 7, "se": 7, "speed": 1, "tut": {}, "seen": {}}
	if not FileAccess.file_exists(settings_path):
		return
	var f := FileAccess.open(settings_path, FileAccess.READ)
	if f == null:
		return
	var data = str_to_var(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	# 対応する項目のみ移行する
	for k in ["master", "bgm", "se"]:
		if typeof(data.get(k)) == TYPE_INT:
			settings[k] = clampi(data[k], 0, 10)
	if data.get("speed") in [1, 2, 4]:
		settings["speed"] = data["speed"]
	if typeof(data.get("tut")) == TYPE_DICTIONARY:
		for k in data["tut"]:
			if D.TUT_FLAGS.has(k):
				settings["tut"][k] = true
	if typeof(data.get("seen")) == TYPE_DICTIONARY:
		var all := D.all_relic_ids()
		for k in data["seen"]:
			if all.has(k):
				settings["seen"][k] = true


func save_settings() -> void:
	var f := FileAccess.open(settings_path, FileAccess.WRITE)
	if f:
		f.store_string(var_to_str(settings))
		f.close()


func tut_seen(key: String) -> bool:
	return settings["tut"].has(key)


func mark_tut(key: String) -> void:
	settings["tut"][key] = true
	save_settings()


# ---------------------------------------------------------------- チュートリアル（初回プレイ）

## 現在の段階（D.TUT_STEPS）。チュートリアル外なら ""
func tut_step() -> String:
	return state.get("tut", "")


func in_tutorial() -> bool:
	return tut_step() != ""


## チュートリアル中はその段階の操作だけ許可する
func tut_allows(step: String) -> bool:
	return not in_tutorial() or tut_step() == step


## step の段階にいれば次へ進める。最後の段階を終えたら完了を記録する
func tut_advance(step: String) -> void:
	_tut_advance(step)
	_commit()


func _tut_advance(step: String) -> void:
	if not in_tutorial() or tut_step() != step:
		return
	var i := D.TUT_STEPS.find(step) + 1
	if i < D.TUT_STEPS.size():
		state["tut"] = D.TUT_STEPS[i]
	else:
		state["tut"] = ""
		mark_tut("done")


## ショップに並んだことがあるか（レリック一覧で説明を見せるかどうか。ランをまたいで記録する）
func relic_seen(id: String) -> bool:
	return settings["seen"].has(id)


func _mark_seen(ids: Array) -> void:
	var added := false
	for id in ids:
		if not settings["seen"].has(id):
			settings["seen"][id] = true
			added = true
	if added:
		save_settings()
