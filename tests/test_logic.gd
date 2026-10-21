extends SceneTree
## 仕様書 第8.7節・第14節の確認。実行：
## godot --headless --path . -s res://tests/test_logic.gd

const D := preload("res://scripts/data.gd")
const GameScript := preload("res://scripts/game.gd")
const TEST_SETTINGS := "user://test_settings.dat"

var _fail := 0
var _pass := 0


func check(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		printerr("FAIL: ", name)


func bases(v: float = 12.0) -> Array:
	var b := []
	for i in 10:
		b.append(v)
	return b


func cyc(relics: Array, s: int, q: int, marks: Array = [], h: int = 0) -> Dictionary:
	return {"relics": relics, "B": bases(), "s": s, "q": q, "marks": marks, "H": h, "dice": [1], "b": 0,
		"r27": 0, "n0": 0}


## 経路を手で組み立てる
func route(s: int, tos: Array, extra_from: int = 999) -> Dictionary:
	var steps := []
	var cur := s
	for i in tos.size():
		var to: int = tos[i]
		steps.append({"from": cur, "to": to, "cross": D.area_of(cur) != D.area_of(to), "extra": i >= extra_from,
			"r08": false, "r09": false, "forced": false})
		cur = to
	return {"steps": steps, "end": cur, "stop": "normal", "kbase": 0, "extra": 0}


func new_game() -> Node:
	var g = GameScript.new()
	g.settings_path = TEST_SETTINGS
	g.settings = {"version": "4.0", "master": 7, "bgm": 7, "se": 7, "speed": 1, "tut": {"done": true, "mark": true}, "seen": {}}
	g.new_run()
	return g


func _init() -> void:
	test_examples()
	test_weights()
	test_marks()
	test_settlement_cases()
	test_route_cases()
	test_shop()
	test_tutorial()
	test_probability()
	test_fuzz()
	print("passed %d, failed %d" % [_pass, _fail])
	DirAccess.remove_absolute("user://save.dat")
	DirAccess.remove_absolute(TEST_SETTINGS)
	quit(1 if _fail > 0 else 0)


func test_examples() -> void:
	# レリックなし 1歩で的中
	var c := cyc([], 0, 1)
	var r := Logic.compute_settlement(c, route(0, [1]), true)
	check(r["F"] == 24, "8.7 no relic hit F=24")
	# R12 R15 R11 マークのゆったり1歩的中
	c = cyc(["R12", "R15", "R11"], 0, 1, [1])
	r = Logic.compute_settlement(c, route(0, [1]), true)
	check(is_equal_approx(r["visits"][0]["J"], 1.9) and r["M"] == 4 and r["F"] == 91, "8.7 F=91")
	# R25 R26 同じポーズ2連続
	c = cyc(["R25", "R26", "R02"], 0, 0)
	r = Logic.compute_settlement(c, route(0, [0, 0]), false)
	check(is_equal_approx(r["visits"][0]["J"], 1.25) and is_equal_approx(r["visits"][1]["J"], 2.25), "8.7 R25 R26")
	# R14 R28 最初の跨ぎ先がはしゃぎ
	c = cyc(["R14", "R28"], 0, 0)
	r = Logic.compute_settlement(c, route(0, [5]), false)
	check(is_equal_approx(r["visits"][0]["J"], 3.25), "8.7 R14 R28 J=3.25")
	# R38 R12 マークされたゆったり
	c = cyc(["R38", "R12"], 0, 0, [1])
	r = Logic.compute_settlement(c, route(0, [1, 2]), false)
	check(is_equal_approx(r["visits"][0]["J"], 4.4) and r["visits"][1]["V"] == 0.0, "8.7 R38 R12")
	# R11 R37 H=2
	check(Logic.hit_multiplier(["R11", "R37"], 2, true) == 10, "8.7 M=10")
	# R20 R21 マークの q に2回訪問
	c = cyc(["R20", "R21"], 0, 1, [1])
	r = Logic.compute_settlement(c, route(0, [1, 1]), true)
	check(r["growth"][1] == 30.0, "8.7 growth 30 (R21 once per pose)")
	# R39 R40
	c = cyc(["R39", "R40"], 0, 3)
	r = Logic.compute_settlement(c, route(0, [1, 2, 3]), true)
	check(r["G"] == 4 and r["F"] == 0, "8.7 R39 R40 F=0")


func test_weights() -> void:
	var b := bases()
	b[5] = 30.0   # はしゃぎが強い
	var l := Logic.base_links(0, ["R06", "R01"], b)
	check(l[2]["w"] == 8, "R01 weak->strong 8")
	l = Logic.base_links(5, ["R06", "R01"], b)
	check(l[2]["w"] == 2, "R01 strong->weak unchanged, R06 no weight change")
	l = Logic.base_links(0, ["R01"], bases())
	check(l[2]["w"] == 2, "R01 equal no override")
	var opts := Logic.step_options(0, 1, ["R04", "R18", "R02"], bases())
	check(opts.size() == 1 and opts[0]["to"] == 5, "R04 step1 forced cross")
	opts = Logic.step_options(3, 2, ["R04", "R18", "R02"], bases())
	check(opts.size() == 4, "R18 step2 not forced")
	opts = Logic.step_options(3, 3, ["R04", "R18", "R02"], bases())
	check(opts.size() == 1 and opts[0]["to"] == 8, "R18 step3 forced cross")
	opts = Logic.step_options(3, 6, ["R18"], bases())
	check(opts.size() == 1 and opts[0]["to"] == 8, "R18 step6 forced cross")
	opts = Logic.step_options(3, 4, ["R02"], bases())
	check(opts.size() == 4, "R02 step4 has self loop")
	opts = Logic.step_options(3, 3, ["R17"], bases())
	check(opts.size() == 2, "R17 removes ccw")
	# R29：マークされたゆったりだけ跨ぎ0.5（R01より優先）
	l = Logic.base_links(0, ["R29", "R01"], b, [0, 5])
	check(is_equal_approx(l[2]["w"], 0.5), "R29 marked yuttari cross 0.5")
	l = Logic.base_links(1, ["R29", "R01"], b, [0, 5])
	check(l[2]["w"] == 8, "R29 unmarked yuttari keeps R01")
	l = Logic.base_links(5, ["R29"], b, [0, 5])
	check(l[2]["w"] == 2, "R29 marked hashagi unaffected")
	var d := Logic.end_distribution(0, 1, ["R29"], bases(), [0])
	check(is_equal_approx(d[5], 0.5 / 8.5) and is_equal_approx(d[1], 6.0 / 8.5), "R29 dist uses 0.5")


func test_marks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var rel := ["R08", "R15", "R27", "R21", "R05", "R32", "R36", "R38"]
	check(Logic.mark_count(rel, 5) == 10, "mark cap 10")
	check(Logic.mark_count(["R38"], 0) == 2, "R38 marks +2")
	check(Logic.mark_count(["R38", "R15", "R08"], 0) == 3, "R38+R08 marks 3, R15 none")
	check(Logic.mark_count(["R36", "R27", "R23"], 0) == 0 and Logic.mark_count(["R06"], 0) == 2, "R36 R27 R23 no marks, R06 +2")
	check(Logic.mark_count(["R29"], 0) == 1 and Logic.mark_count([], 0, 3) == 3 and Logic.mark_count(["R38"], 0, 9) == 10, "R29 +1, Mnext, cap")
	var m := Logic.draw_marks(10, rel, rng)
	check(m.size() == 10, "all 10 marked")
	for i in 30:
		m = Logic.draw_marks(7, ["R05"], rng)
		var yu := 0
		for p in m:
			if p < 5:
				yu += 1
		check(yu == 5 and m.size() == 7, "R05 m=7")
		m = Logic.draw_marks(3, ["R05"], rng)
		check(m.max() < 5, "R05 m=3 yuttari only")


func test_settlement_cases() -> void:
	# 同じマークへ3回訪問（R08 は訪問ごとの抽選結果の数だけ）
	var c := cyc(["R08", "R21", "R02"], 0, 0, [0])
	var rt := route(0, [0, 0, 0])
	rt["steps"][0]["r08"] = true
	rt["steps"][2]["r08"] = true
	var r := Logic.compute_settlement(c, rt, true)
	var a_r08 := 0
	for it in r["a_items"]:
		if it[0].begins_with("R08"):
			a_r08 += it[1]
	check(a_r08 == 2 and r["growth"][0] == 6.0, "3 visits same mark")
	# R08 の抽選はマーク訪問時だけ
	var rng := RandomNumberGenerator.new()
	var hits := 0
	var tries := 0
	for seed in 300:
		rng.seed = seed
		c = cyc(["R08"], 0, 9, [1, 2])
		c["n0"] = 4
		var gr := Logic.generate_route(c, rng)
		for st in gr["steps"]:
			if st["r08"]:
				hits += 1
				check(st["to"] in [1, 2], "R08 only on marks")
			if st["to"] in [1, 2]:
				tries += 1
	check(hits > tries * 0.15 and hits < tries * 0.35, "R08 about 25%% (%d/%d)" % [hits, tries])
	# n0=0 q=s
	c = cyc(["R20"], 2, 2)
	rt = route(2, [])
	check(Logic.base_hit(c, rt["end"]), "n0=0 q=s hit")
	r = Logic.compute_settlement(c, rt, true)
	check(r["F"] == 0 and r["a_total"] == 1 and r["growth"][2] == 24.0, "n0=0 F=0 A+1 R20")
	# n0=0 q≠s sがマーク R36
	c = cyc(["R36", "R20"], 2, 7, [2])
	check(Logic.base_hit(c, 2), "R36 0 step mark hit")
	r = Logic.compute_settlement(c, rt, true)
	check(r["growth"][7] == 24.0 and r["visits"].is_empty(), "R36 R20 q+24, no visit effect")
	# 0歩ゆったり開始
	c = cyc(["R10", "R24"], 1, 1)
	r = Logic.compute_settlement(c, route(1, []), true)
	check(r["a_total"] == 1 and r["g_items"].is_empty(), "0 step R10 R24 off")
	# 1歩以上ゆったり滞在
	r = Logic.compute_settlement(c, route(1, [2, 3]), false)
	check(r["a_total"] == 2 and r["growth"][4] == 3.0 and r["growth"][5] == 0.0, "stay R10 R24 on +3")
	# R37 H=4 的中
	check(Logic.hit_multiplier(["R37"], 4, true) == 12, "R37 H=4 +10")
	check(Logic.hit_multiplier(["R37"], 9, true) == 12, "R37 cap")
	check(Logic.hit_multiplier(["R37"], 0, false) == 0, "R37 miss 0")
	# R22 跨ぎ
	c = cyc(["R22"], 0, 0)
	r = Logic.compute_settlement(c, route(0, [5, 0]), false)
	check(r["growth"][0] == 6.0 and r["growth"][5] == 6.0, "R22 accumulates +3")
	# R23：同じポーズへの2回目以降の訪問ごとに基礎値+8
	c = cyc(["R23", "R02"], 0, 0)
	r = Logic.compute_settlement(c, route(0, [1, 1, 2, 1, 2, 3]), false)
	check(r["growth"][1] == 16.0 and r["growth"][2] == 8.0 and r["growth"][3] == 0.0 and r["m_next"] == 0, "R23 +8 per revisit")
	r = Logic.compute_settlement(c, route(0, [1, 2, 0]), false)
	check(r["g_items"].is_empty(), "R23 start not counted as visit")
	# R35：前サイクルの最多訪問回数（全レリック共通で記録）
	check(r["max_visits"] == 1 and Logic.compute_settlement(cyc([], 0, 0), route(0, [1, 1, 2, 1]), false)["max_visits"] == 3 \
		and Logic.compute_settlement(cyc([], 0, 0), route(0, []), false)["max_visits"] == 0, "max visits")
	check(Logic.calc_n0({"relics": ["R35"], "dice": [2], "Vprev": 3}, 0) == 5 \
		and Logic.calc_n0({"relics": [], "dice": [2], "Vprev": 3}, 0) == 2, "R35 Vprev steps")
	# R15：的中時のみ次サイクルのマーク+2
	c = cyc(["R15"], 0, 1)
	check(Logic.compute_settlement(c, route(0, [1]), true)["m_next"] == 2 \
		and Logic.compute_settlement(c, route(0, [1]), false)["m_next"] == 0, "R15 next marks on hit")
	# R06：歩数-1、ただし1未満にならない
	check(Logic.calc_n0({"relics": ["R06"], "dice": [3]}, 0) == 2 and Logic.calc_n0({"relics": ["R06"], "dice": [1]}, 0) == 1 \
		and Logic.calc_n0({"relics": ["R06", "R35"], "dice": [1], "Vprev": 2}, 0) == 2, "R06 -1 min 1")
	check(Logic.compute_settlement(cyc(["R06"], 0, 0), route(0, [1, 2]), false)["m_next"] == 0, "R06 no next marks")
	# R13 はしゃぎ訪問 +0.4
	c = cyc(["R13"], 0, 0)
	r = Logic.compute_settlement(c, route(0, [5, 0]), false)
	check(is_equal_approx(r["visits"][0]["J"], 1.4) and is_equal_approx(r["visits"][1]["J"], 1.0), "R13 +0.4 hashagi only")
	# R21 異なるマーク2つ、片方は再訪問
	c = cyc(["R21", "R02"], 0, 0, [1, 2])
	r = Logic.compute_settlement(c, route(0, [1, 2, 2, 1]), false)
	check(r["growth"][1] == 6.0 and r["growth"][2] == 6.0 and r["growth"][0] == 0.0, "R21 +6 per distinct mark")
	# R29：ゆったり滞在で全体倍率+1.0
	c = cyc(["R29"], 0, 0)
	r = Logic.compute_settlement(c, route(0, [1, 2]), false)
	check(r["G"] == 2 and r["F"] == 48 and is_equal_approx(r["visits"][0]["J"], 1.0), "R29 stay G=2")
	r = Logic.compute_settlement(c, route(0, [1, 6, 1]), false)
	check(r["G"] == 1, "R29 left area G=1")
	# R40 1〜3歩目ゼロ
	c = cyc(["R40"], 0, 0)
	r = Logic.compute_settlement(c, route(0, [1, 2, 3, 4]), false)
	check(r["F"] == 36, "R40 4th step only (12*1*G3*M1)")


func test_route_cases() -> void:
	var rng := RandomNumberGenerator.new()
	for seed in 400:
		rng.seed = seed
		# R16
		var c := cyc(["R16", "R34"], 0, 1)
		c["n0"] = 12
		var rt := Logic.generate_route(c, rng)
		var idx := -1
		for i in rt["steps"].size():
			if rt["steps"][i]["to"] == 1:
				idx = i
				break
		if idx >= 0:
			var stop_ok: bool = rt["stop"] == "extra_q" if rt["steps"][idx]["extra"] else rt["stop"] == "r16"
			check(rt["steps"].size() == idx + 1 and stop_ok, "R16 stops")
		# R34
		c = cyc(["R34", "R06", "R01"], 0, 9)
		c["n0"] = 6
		rt = Logic.generate_route(c, rng)
		var normal_cross := 0
		var extra := 0
		for st in rt["steps"]:
			if st["extra"]:
				extra += 1
			elif st["cross"]:
				normal_cross += 1
		if rt["stop"] in ["extra_done", "extra_q", "r34_none"]:
			check(rt["kbase"] == normal_cross and extra <= normal_cross, "R34 kbase")
			if rt["stop"] == "extra_done":
				check(extra == normal_cross, "R34 full extra")
			if rt["stop"] == "extra_q":
				check(rt["end"] == 9, "R34 stops at q")
		if rt["stop"] == "normal":
			check(rt["end"] == 9, "R34 no extra when at q")
		# R39
		c = cyc(["R39", "R34", "R18"], 0, 9)
		c["n0"] = Logic.calc_n0({"relics": ["R39"], "dice": [6]}, 0)
		rt = Logic.generate_route(c, rng)
		check(rt["steps"].size() <= 3 and c["n0"] == 3, "R39 cap 3")
		c["n0"] = 2
		rt = Logic.generate_route(c, rng)
		check(rt["steps"].size() <= 3, "R39 cap with R34")
		# R04/R18 自己ループあり
		c = cyc(["R04", "R18", "R02"], 0, 9)
		c["n0"] = 6
		rt = Logic.generate_route(c, rng)
		for i in rt["steps"].size():
			var t: int = i + 1
			if t == 1 or t % 3 == 0:
				check(rt["steps"][i]["cross"], "forced cross step %d" % t)


func test_shop() -> void:
	var g := new_game()
	# 初回無料（レア A=0）
	g.state["shop"]["relics"][0] = {"id": "R33", "sold": false}
	check(g.can_buy_relic(0), "first rare free")
	g.buy_relic(0)
	check(g.state["relics"] == ["R33"] and g.state["A"] == 0 and not g.state["first_free"], "first free consumed")
	# Bp=18・Lp=1 強化（価格は Lp だけで決まる）
	g.state["B"][3] = 18.0
	g.state["L"][3] = 1
	g.state["W"] = 100
	g.state["shop"]["poses"][0] = {"p": 3, "sold": false}
	g.buy_pose(0)
	check(g.state["W"] == 10 and g.state["B"][3] == 27.0 and g.state["L"][3] == 2, "Bp18 Lp1 upgrade costs 90")
	check(Logic.pose_price(0) == 30 and Logic.pose_price(1) == 90 and Logic.pose_price(2) == 270 \
		and Logic.pose_price(3) == 810 and Logic.pose_price(4) == 2430, "pose price 30*3^Lp")
	# Lp=5 は強化不可・抽選対象外
	g.state["L"][4] = 5
	g.state["W"] = 10000
	g.state["shop"]["poses"][1] = {"p": 4, "sold": false}
	check(not g.can_buy_pose(1), "Lp5 cannot upgrade")
	var lv := [5, 5, 5, 5, 5, 5, 5, 5, 4, 5]
	check(Logic.draw_pose_slots(lv, RandomNumberGenerator.new()) == [8, -1], "Lp5 excluded from draw")
	# ショップに並んだレリックは一覧で既見になり、設定に保存される
	var gs := new_game()
	var shown := []
	for slot in gs.state["shop"]["relics"]:
		if slot["id"] != "":
			shown.append(slot["id"])
	var seen_ok := shown.size() == 3
	for id in D.all_relic_ids():
		seen_ok = seen_ok and gs.relic_seen(id) == shown.has(id)
	check(seen_ok, "shop relics marked seen")
	gs.state["W"] = 10000
	gs.refresh_shop()
	for slot in gs.state["shop"]["relics"]:
		seen_ok = seen_ok and gs.relic_seen(slot["id"])
	var gl = GameScript.new()
	gl.settings_path = TEST_SETTINGS
	gl.load_settings()
	check(seen_ok and gl.settings["seen"] == gs.settings["seen"], "seen relics persist after refresh")
	# 初回更新は無料。初回無料レリック権は更新で消えない
	var gf := new_game()
	check(gf.state["B"] == [12.0, 12.0, 12.0, 12.0, 12.0, 20.0, 20.0, 20.0, 20.0, 20.0], "initial base yuttari 12 hashagi 20")
	# R33 は A5 で的中化。A4 では提示しない
	for a0 in [4, 5]:
		var gr := new_game()
		gr.state["relics"] = ["R33"]
		gr.state["A"] = a0
		gr.start_cycle()
		gr.state["cyc"]["n0"] = 0
		gr.set_guess(5)
		gr.confirm_plan()
		gr.finish_moving()
		if a0 == 4:
			check(gr.phase() != "r33" and gr.state["A"] == 5, "R33 A4 unusable (A +1 after settle)")
		else:
			check(gr.phase() == "r33", "R33 A5 offered")
			gr.r33_choose(true)
			check(gr.state["A"] == 1 and gr.state["H"] == 1, "R33 pays 5, hit")
	# R19⇔R35 入れ替え
	check(D.relic_name("R19") == "ひみつの抜け道" and D.relic_rarity("R19") == D.RARITY_UNCOMMON and D.relic_price("R19") == 5, "R19 secret path uncommon")
	# ID・レアリティの入れ替え（R01⇔R17、R30⇔R32、R05⇔R29、R27⇔R35）
	for it in [["R01", "豊かな潮流", 0], ["R17", "ひとすじの潮", 1], ["R30", "結晶のひと泳ぎ", 1], ["R32", "渡りの星図", 2],
			["R05", "ねむりの星印", 0], ["R27", "星をたどるひれ", 1]]:
		check(D.relic_name(it[0]) == it[1] and D.relic_rarity(it[0]) == it[2], "%s is %s" % [it[0], it[1]])
	# R29⇔R35
	for it in [["R29", "ひといろの夢", 1], ["R35", "ながいしっぽ", 2]]:
		check(D.relic_name(it[0]) == it[1] and D.relic_rarity(it[0]) == it[2], "%s is %s" % [it[0], it[1]])
	# R27：マークを消すたび歩数+1、マークがなくなるまで
	var gm := new_game()
	gm.state["relics"] = ["R27", "R38"]
	gm.start_cycle()
	gm.state["cyc"]["dice"] = [3]
	gm.state["cyc"]["n0"] = Logic.calc_n0(gm.state["cyc"], 0)
	var m0: Array = gm.state["cyc"]["marks"].duplicate()
	gm.trade_mark()
	var m1: Array = gm.state["cyc"]["marks"]
	check(m0.size() == 2 and m1.size() == 1 and m0.has(m1[0]) and gm.state["cyc"]["n0"] == 4, "R27 trade one mark")
	gm.trade_mark()
	check(gm.state["cyc"]["marks"].is_empty() and gm.state["cyc"]["n0"] == 5 and not gm.can_trade_mark(), "R27 until no marks")
	gm.free()
	check(gf.state["free_refresh"] == 1 and gf.state["first_free"], "initial free refresh")
	gf.refresh_shop()
	check(gf.state["free_refresh"] == 0 and gf.state["U"] == 0 and gf.state["W"] == 0 and gf.state["first_free"], "first refresh free, first relic free kept")
	check(Logic.refresh_price(0) == 40 and Logic.refresh_price(1) == 60 and Logic.refresh_price(2) == 90 \
		and Logic.refresh_price(3) == 135 and Logic.refresh_price(4) == 203, "refresh price ceil(40*1.5^U)")
	# U=2 で無料更新
	g.state["U"] = 2
	g.state["free_refresh"] = 1
	g.refresh_shop()
	check(g.state["U"] == 2 and g.refresh_cost() == 90 and g.state["free_refresh"] == 0, "free refresh keeps U")
	g.state["W"] = 90
	g.refresh_shop()
	check(g.state["U"] == 3 and g.state["W"] == 0 and g.refresh_cost() == 135, "paid refresh")
	check(D.round_target(1) == 400 and D.round_target(2) == 1600 and D.round_target(3) == 4500 \
		and D.round_target(4) == 10000 and D.round_target(5) == 20000, "round targets")
	# R30 は A1 で通常歩数+2
	g.state["relics"] = ["R30"]
	g.state["A"] = 3
	g.start_cycle()
	g.state["cyc"]["dice"] = [3]
	g.state["cyc"]["n0"] = Logic.calc_n0(g.state["cyc"], 0)
	g.buy_step()
	check(g.state["A"] == 2 and g.state["cyc"]["b"] == 2 and g.state["cyc"]["n0"] == 5, "R30 +2 steps")
	# 予想は未選択で始まり、選ぶまで確定できない
	check(g.state["cyc"]["q"] == -1 and not g.has_guess(), "guess starts unselected")
	g.confirm_plan()
	check(g.phase() == "plan", "cannot confirm without guess")
	g.set_guess(3)
	g.confirm_plan()
	g.finish_moving()
	if g.phase() == "report":
		g.close_report()
	# R30 + R39：n0=2 なら購入可（1歩分は余剰）、n0=3 なら不可
	g.state["relics"] = ["R30", "R39"]
	g.state["A"] = 3
	g.start_cycle()
	g.state["cyc"]["dice"] = [2]
	g.state["cyc"]["n0"] = Logic.calc_n0(g.state["cyc"], 0)
	check(g.can_buy_step(), "R30 R39 n0=2 can buy")
	g.buy_step()
	check(g.state["cyc"]["n0"] == 3 and not g.can_buy_step(), "R30 R39 capped at 3")
	g.set_guess(0)
	g.confirm_plan()
	g.finish_moving()
	if g.phase() == "report":
		g.close_report()
	# 満杯時の入れ替え
	g.state["relics"] = ["R17", "R02", "R03", "R04"]
	g.state["A"] = 10
	g.state["shop"]["relics"][1] = {"id": "R05", "sold": false}
	g.buy_relic(1)
	check(g.state["pending_swap"] == 1 and g.state["relics"].size() == 4, "swap pending")
	g.cancel_swap()
	check(g.state["A"] == 10 and g.state["pending_swap"] == -1, "swap cancel")
	g.buy_relic(1)
	g.confirm_swap("R02")
	check(g.state["relics"] == ["R17", "R03", "R04", "R05"] and g.state["A"] == 7, "swap confirm")
	# ラウンド判定：最終Wが目標と同額
	g.state["relics"] = []
	g.state["c"] = 9
	g.state["W"] = 500
	g.start_cycle()
	g.state["cyc"]["dice"] = [1]
	g.state["cyc"]["n0"] = 0
	g.set_guess(0)
	g.confirm_plan()
	g.finish_moving()
	check(g.state["r"] == 2 and g.state["c"] == 0 and g.state["free_refresh"] == 1 and g.slots() == 6, "round adv")
	g.close_report()
	# 途中達成後に買い物して最終未達
	g.state["c"] = 9
	g.state["W"] = 1500
	g.start_cycle()
	g.state["cyc"]["n0"] = 0
	g.set_guess(0)
	g.confirm_plan()
	g.finish_moving()
	check(not g.state["ended"].is_empty() and not g.state["ended"]["cleared"], "fail at round end")
	# 保存と再開
	g.new_run()
	g.start_cycle()
	var dice: Array = g.state["cyc"]["dice"].duplicate()
	var marks: Array = g.state["cyc"]["marks"].duplicate()
	var g2 = GameScript.new()
	g2.settings = g.settings
	check(g2.load_game(), "load")
	check(g2.state["cyc"]["dice"] == dice and g2.state["cyc"]["marks"] == marks and g2.phase() == "plan", "resume keeps dice")
	g2.set_guess(0)
	g2.confirm_plan()
	var path: Array = g2.state["cyc"]["route"]["steps"].duplicate(true)
	var g3 = GameScript.new()
	g3.settings = g.settings
	g3.load_game()
	check(g3.state["cyc"]["route"]["steps"] == path, "resume keeps route")
	check(g3.rng.state == g2.rng.state, "rng state restored")
	g.free()
	g2.free()
	g3.free()


func test_tutorial() -> void:
	var g = GameScript.new()
	g.settings_path = TEST_SETTINGS
	g.settings = {"version": "4.0", "master": 7, "bgm": 7, "se": 7, "speed": 1, "tut": {}, "seen": {}}
	g.new_run()
	check(g.tut_step() == "intro", "tutorial starts on first play")
	var rel := []
	for slot in g.state["shop"]["relics"]:
		rel.append(slot["id"])
	var poses := []
	for slot in g.state["shop"]["poses"]:
		poses.append(slot["p"])
	check(rel == D.TUT_SHOP_RELICS and poses == D.TUT_SHOP_POSES, "tutorial shop fixed")
	check(not g.can_roll() and not g.can_buy_relic(0) and not g.can_refresh(), "intro blocks actions")
	g.tut_advance("intro")
	check(g.can_roll() and not g.can_buy_relic(0) and not g.can_buy_pose(0) and not g.can_refresh(), "roll step only rolls")
	g.start_cycle()
	check(g.cyc()["dice"] == D.TUT_DICE and g.tut_step() == "weights", "tutorial dice fixed")
	g.set_guess(1)
	check(g.cyc()["q"] == -1, "guess blocked before guess step")
	g.tut_advance("weights")
	g.tut_advance("prob")
	g.set_guess(9)
	g.confirm_plan()
	check(g.phase() == "plan", "confirm waits for reward explanation")
	g.tut_advance("guess")
	g.confirm_plan()
	var path := []
	for st in g.cyc()["route"]["steps"]:
		path.append(st["to"])
	check(path == D.TUT_PATH and g.tut_step() == "play", "tutorial route fixed")
	g.finish_moving()
	# はずれでも最初のポーズ強化を買える
	check(not g.cyc()["hit"] and g.state["W"] >= Logic.pose_price(0), "first cycle affords pose upgrade")
	g.close_report()
	check(g.tut_step() == "round" and not g.can_roll(), "round explanation after report")
	g.tut_advance("round")
	check(g.can_buy_relic(0) and not g.can_buy_pose(0) and not g.can_refresh() and not g.can_roll(), "relic step")
	g.buy_relic(0)
	check(g.tut_step() == "aqua" and not g.can_buy_relic(1), "aqua after relic")
	g.tut_advance("aqua")
	check(g.can_buy_pose(0) and not g.can_refresh(), "pose step")
	g.buy_pose(0)
	check(g.tut_step() == "refresh" and g.can_refresh() and not g.can_roll(), "refresh step")
	g.refresh_shop()
	check(not g.in_tutorial() and g.tut_seen("done") and g.can_roll(), "tutorial done after refresh")
	g.new_run()
	check(not g.in_tutorial(), "second run has no tutorial")


func test_probability() -> void:
	var d := Logic.end_distribution(0, 1, [], bases())
	check(is_equal_approx(d[1], 0.6) and is_equal_approx(d[4], 0.2) and is_equal_approx(d[5], 0.2), "1 step dist")
	d = Logic.end_distribution(3, 0, [], bases())
	check(d[3] == 1.0, "0 step dist")
	d = Logic.end_distribution(0, 7, ["R02", "R18", "R01"], bases())
	var s := 0.0
	for x in d:
		s += x
	check(is_equal_approx(s, 1.0), "dist sums to 1")
	check(Logic.fmt_prob(0.0) == "0%" and Logic.fmt_prob(0.0004) == "<0.1%" and Logic.fmt_prob(0.1234) == "12.3%", "prob fmt")


## ランダムに買い物しながらランを最後まで進める
func test_fuzz() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var cleared := 0
	var games := 0
	var rounds := []
	for run in 40:
		var g := new_game()
		var guard := 0
		while g.phase() != "ended" and guard < 2000:
			guard += 1
			match g.phase():
				"idle":
					for k in 4:
						var i := r.randi_range(0, 2)
						g.buy_relic(i)
						if g.state["pending_swap"] >= 0:
							g.confirm_swap(g.state["relics"][r.randi_range(0, g.state["relics"].size() - 1)])
					if g.state["W"] > g.target() + 200:
						g.buy_pose(r.randi_range(0, 1))
					g.start_cycle()
				"plan":
					if g.can_reroll() and r.randf() < 0.5:
						g.reroll()
					while g.can_buy_step() and r.randf() < 0.3:
						g.buy_step()
					if g.cyc_has("R19"):
						g.set_start(r.randi_range(0, 9))
					while g.can_trade_mark() and r.randf() < 0.3:
						g.trade_mark()
					var dist := Logic.end_distribution(g.cyc()["s"], g.cyc()["n0"], g.cyc()["relics"], g.cyc()["B"], g.cyc()["marks"])
					var best := 0
					for p in 10:
						if dist[p] > dist[best]:
							best = p
					g.set_guess(best)
					g.confirm_plan()
				"moving":
					g.finish_moving()
				"r33":
					g.r33_choose(r.randf() < 0.5)
				"report":
					check(g.state["W"] >= 0 and g.state["A"] >= 0, "non-negative resources")
					g.close_report()
		check(g.phase() == "ended", "run terminates")
		games += 1
		if g.state["ended"]["cleared"]:
			cleared += 1
		rounds.append(g.state["ended"]["r"])
		g.free()
	print("fuzz: %d runs, %d cleared, rounds reached %s" % [games, cleared, str(rounds)])
