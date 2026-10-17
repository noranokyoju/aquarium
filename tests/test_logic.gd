extends SceneTree
## 仕様書 第8.7節・第14節の確認。実行：
## godot --headless --path . -s res://tests/test_logic.gd

const D := preload("res://scripts/data.gd")
const GameScript := preload("res://scripts/game.gd")

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
		"Mprev": 0, "n0": 0}


## 経路を手で組み立てる
func route(s: int, tos: Array, extra_from: int = 999) -> Dictionary:
	var steps := []
	var cur := s
	for i in tos.size():
		var to: int = tos[i]
		steps.append({"from": cur, "to": to, "cross": D.area_of(cur) != D.area_of(to), "extra": i >= extra_from,
			"r09": false, "forced": false})
		cur = to
	return {"steps": steps, "end": cur, "stop": "normal", "kbase": 0, "extra": 0}


func new_game() -> Node:
	var g = GameScript.new()
	g.settings = {"version": "4.0", "master": 7, "bgm": 7, "se": 7, "speed": 1, "tut": {}}
	g.new_run()
	return g


func _init() -> void:
	test_examples()
	test_weights()
	test_marks()
	test_settlement_cases()
	test_route_cases()
	test_shop()
	test_probability()
	test_fuzz()
	print("passed %d, failed %d" % [_pass, _fail])
	DirAccess.remove_absolute("user://save.dat")
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
	var l := Logic.base_links(0, ["R06", "R17"], b)
	check(l[2]["w"] == 8, "R06+R17 weak->strong 8")
	l = Logic.base_links(5, ["R06", "R17"], b)
	check(l[2]["w"] == 1, "R06+R17 strong->weak 1")
	l = Logic.base_links(0, ["R17"], bases())
	check(l[2]["w"] == 2, "R17 equal no override")
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
	opts = Logic.step_options(3, 3, ["R01"], bases())
	check(opts.size() == 2, "R01 removes ccw")


func test_marks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var rel := ["R08", "R15", "R35", "R21", "R29", "R30", "R36", "R38"]
	check(Logic.mark_count(rel, 5) == 10, "mark cap 10")
	check(Logic.mark_count(["R38"], 0) == 2, "R38 marks +2")
	check(Logic.mark_count(["R38", "R15", "R08"], 0) == 5, "R38+R15+R08 marks 5")
	var m := Logic.draw_marks(10, rel, rng)
	check(m.size() == 10, "all 10 marked")
	for i in 30:
		m = Logic.draw_marks(7, ["R29"], rng)
		var yu := 0
		for p in m:
			if p < 5:
				yu += 1
		check(yu == 5 and m.size() == 7, "R29 m=7")
		m = Logic.draw_marks(3, ["R29"], rng)
		check(m.max() < 5, "R29 m=3 yuttari only")


func test_settlement_cases() -> void:
	# 同じマークへ3回訪問
	var c := cyc(["R08", "R21", "R02"], 0, 0, [0])
	var r := Logic.compute_settlement(c, route(0, [0, 0, 0]), true)
	var a_r08 := 0
	for it in r["a_items"]:
		if it[0].begins_with("R08"):
			a_r08 += it[1]
	check(a_r08 == 1 and r["mark_distinct"] == 1 and r["growth"][0] == 6.0, "3 visits same mark")
	# n0=0 q=s
	c = cyc(["R20"], 2, 2)
	var rt := route(2, [])
	check(Logic.base_hit(c, rt["end"]), "n0=0 q=s hit")
	r = Logic.compute_settlement(c, rt, true)
	check(r["F"] == 0 and r["a_total"] == 1 and r["growth"][2] == 24.0, "n0=0 F=0 A+1 R20")
	# n0=0 q≠s sがマーク R36
	c = cyc(["R36", "R20"], 2, 7, [2])
	check(Logic.base_hit(c, 2), "R36 0 step mark hit")
	r = Logic.compute_settlement(c, rt, true)
	check(r["growth"][7] == 24.0 and r["mark_distinct"] == 0, "R36 R20 q+24, no visit effect")
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
	# R23
	c = cyc(["R23"], 0, 0)
	r = Logic.compute_settlement(c, route(0, [1, 1, 0]), true)
	check(r["growth"][0] == 12.0 and r["growth"][1] == 12.0, "R23 distinct +12")
	# R13 はしゃぎ訪問 +0.4
	c = cyc(["R13"], 0, 0)
	r = Logic.compute_settlement(c, route(0, [5, 0]), false)
	check(is_equal_approx(r["visits"][0]["J"], 1.4) and is_equal_approx(r["visits"][1]["J"], 1.0), "R13 +0.4 hashagi only")
	# R21 異なるマーク2つ、片方は再訪問
	c = cyc(["R21", "R02"], 0, 0, [1, 2])
	r = Logic.compute_settlement(c, route(0, [1, 2, 2, 1]), false)
	check(r["growth"][1] == 6.0 and r["growth"][2] == 6.0 and r["growth"][0] == 0.0, "R21 +6 per distinct mark")
	# R27 離れたら復活しない
	c = cyc(["R27"], 0, 0)
	r = Logic.compute_settlement(c, route(0, [1, 6, 1]), false)
	check(is_equal_approx(r["visits"][0]["J"], 1.75) and is_equal_approx(r["visits"][2]["J"], 1.0), "R27")
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
		c = cyc(["R34", "R06", "R17"], 0, 9)
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
		c["n0"] = Logic.calc_n0({"relics": ["R39"], "dice": [6], "Mprev": 0}, 0)
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
	check(D.relic_name("R35") == "星をたどるひれ" and D.relic_rarity("R35") == D.RARITY_RARE and D.relic_price("R35") == 7, "R35 star fin rare")
	check(Logic.mark_count(["R35"], 0) == 1 and Logic.mark_count(["R19"], 0) == 0, "R35 mark+1, R19 none")
	check(Logic.calc_n0({"relics": ["R35"], "dice": [2], "Mprev": 3}, 0) == 5 \
		and Logic.calc_n0({"relics": ["R19"], "dice": [2], "Mprev": 3}, 0) == 2, "R35 Mprev steps")
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
	# R32 は A1 で通常歩数+2
	g.state["relics"] = ["R32"]
	g.state["A"] = 3
	g.start_cycle()
	g.state["cyc"]["dice"] = [3]
	g.state["cyc"]["n0"] = Logic.calc_n0(g.state["cyc"], 0)
	g.buy_step()
	check(g.state["A"] == 2 and g.state["cyc"]["b"] == 2 and g.state["cyc"]["n0"] == 5, "R32 +2 steps")
	g.confirm_plan()
	g.finish_moving()
	if g.phase() == "report":
		g.close_report()
	# R32 + R39：n0=2 なら購入可（1歩分は余剰）、n0=3 なら不可
	g.state["relics"] = ["R32", "R39"]
	g.state["A"] = 3
	g.start_cycle()
	g.state["cyc"]["dice"] = [2]
	g.state["cyc"]["n0"] = Logic.calc_n0(g.state["cyc"], 0)
	check(g.can_buy_step(), "R32 R39 n0=2 can buy")
	g.buy_step()
	check(g.state["cyc"]["n0"] == 3 and not g.can_buy_step(), "R32 R39 capped at 3")
	g.confirm_plan()
	g.finish_moving()
	if g.phase() == "report":
		g.close_report()
	# 満杯時の入れ替え
	g.state["relics"] = ["R01", "R02", "R03", "R04"]
	g.state["A"] = 10
	g.state["shop"]["relics"][1] = {"id": "R05", "sold": false}
	g.buy_relic(1)
	check(g.state["pending_swap"] == 1 and g.state["relics"].size() == 4, "swap pending")
	g.cancel_swap()
	check(g.state["A"] == 10 and g.state["pending_swap"] == -1, "swap cancel")
	g.buy_relic(1)
	g.confirm_swap("R02")
	check(g.state["relics"] == ["R01", "R03", "R04", "R05"] and g.state["A"] == 7, "swap confirm")
	# ラウンド判定：最終Wが目標と同額
	g.state["relics"] = []
	g.state["c"] = 9
	g.state["W"] = 500
	g.start_cycle()
	g.state["cyc"]["dice"] = [1]
	g.state["cyc"]["n0"] = 0
	g.confirm_plan()
	g.finish_moving()
	check(g.state["r"] == 2 and g.state["c"] == 0 and g.state["free_refresh"] == 1 and g.slots() == 6, "round adv")
	g.close_report()
	# 途中達成後に買い物して最終未達
	g.state["c"] = 9
	g.state["W"] = 1500
	g.start_cycle()
	g.state["cyc"]["n0"] = 0
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


func test_probability() -> void:
	var d := Logic.end_distribution(0, 1, [], bases())
	check(is_equal_approx(d[1], 0.6) and is_equal_approx(d[4], 0.2) and is_equal_approx(d[5], 0.2), "1 step dist")
	d = Logic.end_distribution(3, 0, [], bases())
	check(d[3] == 1.0, "0 step dist")
	d = Logic.end_distribution(0, 7, ["R02", "R18", "R17"], bases())
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
					var dist := Logic.end_distribution(g.cyc()["s"], g.cyc()["n0"], g.cyc()["relics"], g.cyc()["B"])
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
