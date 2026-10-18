class_name Logic
extends RefCounted
## ゲームルールの純粋な計算（状態は引数で受け取り、乱数は rng で渡す）

const D := preload("res://scripts/data.gd")

const KIND_CW := "cw"
const KIND_CCW := "ccw"
const KIND_CROSS := "cross"
const KIND_SELF := "self"


static func has(relics: Array, id: String) -> bool:
	return relics.has(id)


## レリックの効果量（res://data/relics/*.tres の values）
static func val(id: String, key: String) -> float:
	return D.relic_value(id, key)


## 訪問倍率などの加算値を 1/100 単位の整数にする
static func val100(id: String, key: String) -> int:
	return roundi(val(id, key) * 100.0)


static func area_sums(bases: Array) -> Array:
	var sums := [0.0, 0.0]
	for p in D.POSE_COUNT:
		sums[D.area_of(p)] += bases[p]
	return sums


## 強制跨ぎの歩か（歩番号は追加移動も含めた通し番号、1始まり）
static func is_forced_step(step: int, relics: Array) -> bool:
	return (has(relics, "R04") and step == 1) or (has(relics, "R18") and step % int(val("R18", "interval")) == 0)


## 第4.3節 1〜4 を適用したリンク一覧（重み0の無効リンクも含む）
static func base_links(node: int, relics: Array, bases: Array) -> Array:
	var cross_w := 2
	if has(relics, "R06"):
		cross_w = int(val("R06", "cross_weight"))
	if has(relics, "R17"):
		var sums := area_sums(bases)
		var a := D.area_of(node)
		if sums[a] < sums[1 - a]:
			cross_w = int(val("R17", "cross_weight"))
	var links := [
		{"to": D.cw_of(node), "w": 6, "kind": KIND_CW},
		{"to": D.ccw_of(node), "w": 0 if has(relics, "R01") else 2, "kind": KIND_CCW},
		{"to": D.cross_of(node), "w": cross_w, "kind": KIND_CROSS},
	]
	if has(relics, "R02"):
		links.append({"to": node, "w": int(val("R02", "weight")), "kind": KIND_SELF})
	return links


## step 歩目に node から出るときの抽選候補（正の重みのみ）
static func step_options(node: int, step: int, relics: Array, bases: Array) -> Array:
	if is_forced_step(step, relics):
		return [{"to": D.cross_of(node), "w": 1, "kind": KIND_CROSS, "forced": true}]
	var out := []
	for l in base_links(node, relics, bases):
		if l["w"] > 0:
			out.append(l)
	return out


static func total_weight(opts: Array) -> int:
	var t := 0
	for o in opts:
		t += o["w"]
	return t


## 通常移動 n0 歩を必ず行ったときの終点分布
static func end_distribution(s: int, n0: int, relics: Array, bases: Array) -> Array:
	var dist := []
	dist.resize(D.POSE_COUNT)
	dist.fill(0.0)
	dist[s] = 1.0
	for t in range(1, n0 + 1):
		var nxt := []
		nxt.resize(D.POSE_COUNT)
		nxt.fill(0.0)
		for x in D.POSE_COUNT:
			if dist[x] <= 0.0:
				continue
			var opts := step_options(x, t, relics, bases)
			var tw := float(total_weight(opts))
			for o in opts:
				nxt[o["to"]] += dist[x] * o["w"] / tw
		dist = nxt
	return dist


static func mark_count(relics: Array, kprev: int) -> int:
	var m := 0
	for id in ["R08", "R15", "R35", "R21", "R29", "R36", "R38"]:
		if has(relics, id): m += int(val(id, "marks"))
	if has(relics, "R30"): m += kprev
	return mini(10, m)


static func shuffled(arr: Array, rng: RandomNumberGenerator) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a


static func draw_marks(m: int, relics: Array, rng: RandomNumberGenerator) -> Array:
	if m <= 0:
		return []
	var out := []
	if has(relics, "R29"):
		var yu := shuffled([0, 1, 2, 3, 4], rng)
		if m <= 5:
			out = yu.slice(0, m)
		else:
			out = yu + shuffled([5, 6, 7, 8, 9], rng).slice(0, m - 5)
	else:
		out = shuffled(range(D.POSE_COUNT), rng).slice(0, m)
	out.sort()
	return out


static func dice_sum(dice: Array) -> int:
	var s := 0
	for v in dice:
		s += v
	return s


## 通常移動予定歩数 n0
static func calc_n0(cyc: Dictionary, b: int) -> int:
	var relics: Array = cyc["relics"]
	var raw := dice_sum(cyc["dice"]) + b
	if has(relics, "R05"): raw += int(val("R05", "steps"))
	if has(relics, "R06"): raw -= int(val("R06", "steps"))
	if has(relics, "R35"): raw += int(cyc["Mprev"])
	var n0 := maxi(0, raw)
	if has(relics, "R39"):
		n0 = mini(int(val("R39", "max_steps")), n0)
	return n0


static func _pick(opts: Array, rng: RandomNumberGenerator) -> Dictionary:
	var tw := total_weight(opts)
	var r := rng.randf() * tw
	var acc := 0.0
	for o in opts:
		acc += o["w"]
		if r < acc:
			return o
	return opts[opts.size() - 1]


## 経路を確定する（第7.3節）。R09 の抽選結果も同時に確定する。
static func generate_route(cyc: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var relics: Array = cyc["relics"]
	var bases: Array = cyc["B"]
	var s: int = cyc["s"]
	var q: int = cyc["q"]
	var n0: int = cyc["n0"]
	var cap := int(val("R39", "max_steps")) if has(relics, "R39") else 1 << 30
	var w := {"steps": [], "cur": s, "t": 0}
	var stop := ""
	var kbase := 0
	var extra_granted := 0

	if n0 == 0:
		stop = "zero"
	else:
		for i in n0:
			if w["t"] >= cap:
				stop = "cap"
				break
			_route_step(w, false, relics, bases, rng)
			if has(relics, "R16") and w["cur"] == q:
				stop = "r16"
				break
		if stop == "":
			if has(relics, "R34") and w["cur"] != q:
				if w["t"] >= cap:
					stop = "cap"
				else:
					for st in w["steps"]:
						if st["cross"]:
							kbase += 1
					extra_granted = kbase
					if kbase == 0:
						stop = "r34_none"
					else:
						for j in kbase:
							if w["t"] >= cap:
								stop = "cap"
								break
							_route_step(w, true, relics, bases, rng)
							if w["cur"] == q:
								stop = "extra_q"
								break
						if stop == "":
							stop = "extra_done"
			else:
				stop = "normal"
	return {"steps": w["steps"], "end": w["cur"], "stop": stop, "kbase": kbase, "extra": extra_granted}


static func _route_step(w: Dictionary, is_extra: bool, relics: Array, bases: Array, rng: RandomNumberGenerator) -> void:
	var cur: int = w["cur"]
	var opts := step_options(cur, w["t"] + 1, relics, bases)
	var o := _pick(opts, rng)
	var to: int = o["to"]
	var cross := D.area_of(cur) != D.area_of(to)
	var r09 := false
	if cross and has(relics, "R09"):
		r09 = rng.randf() < val("R09", "chance") / 100.0
	w["steps"].append({"from": cur, "to": to, "cross": cross, "extra": is_extra, "r09": r09,
		"forced": o.get("forced", false)})
	w["cur"] = to
	w["t"] += 1


static func stop_reason_text(stop: String) -> String:
	match stop:
		"zero": return "歩数0のため移動なし"
		"normal": return "通常移動を終了"
		"r16": return "予想ポーズに到着して停止（R16）"
		"r34_none": return "通常移動を終了（跨ぎ0回のため追加移動なし）"
		"extra_q": return "追加移動中に予想ポーズへ到着して停止（R34）"
		"extra_done": return "追加移動を終了（R34）"
		"cap": return "上限3歩で停止（R39）"
	return ""


## 終点・マークによる的中判定（R33 を除く）
static func base_hit(cyc: Dictionary, e: int) -> bool:
	if e == int(cyc["q"]):
		return true
	return has(cyc["relics"], "R36") and (cyc["marks"] as Array).has(e)


static func hit_multiplier(relics: Array, h: int, hit: bool) -> float:
	if hit:
		var m := 2.0
		if has(relics, "R11"): m += val("R11", "hit_mult")
		if has(relics, "R37"): m += minf(val("R37", "hit_mult") + val("R37", "streak") * h, val("R37", "cap"))
		return m
	return 0.0 if has(relics, "R37") else 1.0


## 精算内容の計算（第8節）。状態は変更しない。
static func compute_settlement(cyc: Dictionary, route: Dictionary, hit: bool) -> Dictionary:
	var relics: Array = cyc["relics"]
	var bases: Array = cyc["B"]
	var marks: Array = cyc["marks"]
	var s: int = cyc["s"]
	var q: int = cyc["q"]
	var steps: Array = route["steps"]
	var e: int = route["end"]
	var n := steps.size()

	var visits := []
	var counts := {}
	var k := 0
	var stay := D.area_of(s) == D.AREA_YUTTARI
	var all_yuttari := true
	var s100 := 0.0
	var marks_visited := {}
	var mark_visit_count := {}
	for i in n:
		var st: Dictionary = steps[i]
		var t := i + 1
		var x: int = st["to"]
		counts[x] = counts.get(x, 0) + 1
		var dt := counts.size()
		var nt: int = counts[x]
		var cross: bool = st["cross"]
		if cross:
			k += 1
		var area := D.area_of(x)
		if area != D.AREA_YUTTARI:
			stay = false
			all_yuttari = false
		var mark := marks.has(x)
		if mark:
			marks_visited[x] = true
			mark_visit_count[x] = mark_visit_count.get(x, 0) + 1
		var j100 := 100
		var parts := []
		if mark:
			if has(relics, "R38"):
				j100 += val100("R38", "mark_bonus")
				parts.append("マーク+%s" % fmt_num(val("R38", "mark_bonus")))
			else:
				j100 += 50
				parts.append("マーク+0.5")
		if has(relics, "R12") and area == D.AREA_YUTTARI:
			j100 += val100("R12", "bonus")
			parts.append("R12+%s" % fmt_num(val("R12", "bonus")))
		if has(relics, "R13") and area == D.AREA_HASHAGI:
			j100 += val100("R13", "bonus")
			parts.append("R13+%s" % fmt_num(val("R13", "bonus")))
		if has(relics, "R14") and cross:
			j100 += val100("R14", "bonus")
			parts.append("R14+%s" % fmt_num(val("R14", "bonus")))
		if has(relics, "R25") and nt >= 2:
			j100 += val100("R25", "bonus")
			parts.append("R25+%s" % fmt_num(val("R25", "bonus")))
		if has(relics, "R26"):
			j100 += val100("R26", "bonus") * dt
			parts.append("R26+%s" % fmt_num(val("R26", "bonus") * dt))
		if has(relics, "R27") and stay:
			j100 += val100("R27", "bonus")
			parts.append("R27+%s" % fmt_num(val("R27", "bonus")))
		if has(relics, "R28") and k >= 1 and area == D.AREA_HASHAGI:
			j100 += val100("R28", "bonus")
			parts.append("R28+%s" % fmt_num(val("R28", "bonus")))
		var zero := []
		if has(relics, "R38") and not mark:
			zero.append("R38:未マーク")
		if has(relics, "R40") and t <= int(val("R40", "zero_steps")):
			zero.append("R40:%d歩目" % t)
		var v100 := 0.0
		if zero.is_empty():
			v100 = float(bases[x]) * j100
		s100 += v100
		visits.append({"t": t, "pose": x, "B": float(bases[x]), "J": j100 / 100.0, "V": v100 / 100.0,
			"zero": ", ".join(zero), "parts": ", ".join(parts), "cross": cross, "mark": mark,
			"extra": st["extra"]})

	var g := 1.0
	if has(relics, "R39"): g += val("R39", "global_mult")
	if has(relics, "R40"): g += val("R40", "global_mult")
	var h: int = cyc["H"]
	var m := hit_multiplier(relics, h, hit)
	var f := int(floor(s100 * g * m / 100.0))

	# アクアマリン
	var a_items := [["基本", 1]]
	if has(relics, "R07") and hit:
		a_items.append(["R07 的中", int(val("R07", "aqua"))])
	if has(relics, "R08") and not marks_visited.is_empty():
		a_items.append(["R08 マーク訪問", int(val("R08", "aqua"))])
	if has(relics, "R09"):
		var c := 0
		for st in steps:
			if st["r09"]:
				c += 1
		if c > 0:
			a_items.append(["R09 跨ぎ抽選", c * int(val("R09", "aqua"))])
	if has(relics, "R10") and D.area_of(s) == D.AREA_YUTTARI and n >= 1 and all_yuttari:
		a_items.append(["R10 ゆったり滞在", int(val("R10", "aqua"))])
	var a_total := 0
	for it in a_items:
		a_total += it[1]

	# 基礎値成長
	var growth := []
	growth.resize(D.POSE_COUNT)
	growth.fill(0.0)
	var g_items := []
	if has(relics, "R20") and hit:
		growth[q] += val("R20", "growth")
		g_items.append(["R20", q, val("R20", "growth")])
	if has(relics, "R21"):
		# 同じポーズへの再訪問では発動しない（訪問した異なるマークごとに1回）
		for p in mark_visit_count:
			growth[p] += val("R21", "growth")
			g_items.append(["R21", p, val("R21", "growth")])
	if has(relics, "R22"):
		var r22 := []
		r22.resize(D.POSE_COUNT)
		r22.fill(0.0)
		for st in steps:
			if st["cross"]:
				r22[st["from"]] += val("R22", "growth")
				r22[st["to"]] += val("R22", "growth")
		for p in D.POSE_COUNT:
			if r22[p] > 0.0:
				growth[p] += r22[p]
				g_items.append(["R22", p, r22[p]])
	if has(relics, "R23") and e == s and n >= 1:
		var ps := counts.keys()
		ps.sort()
		for p in ps:
			growth[p] += val("R23", "growth")
			g_items.append(["R23", p, val("R23", "growth")])
	if has(relics, "R24") and D.area_of(s) == D.AREA_YUTTARI and n >= 1 and all_yuttari:
		for p in 5:
			growth[p] += val("R24", "growth")
			g_items.append(["R24", p, val("R24", "growth")])

	return {
		"visits": visits, "S": s100 / 100.0, "G": g, "M": m, "F": f, "hit": hit,
		"a_items": a_items, "a_total": a_total, "growth": growth, "g_items": g_items,
		"crosses": k, "mark_distinct": marks_visited.size(), "end": e,
	}


## ショップのレリック枠を1つ抽選（候補がなければ ""）
static func draw_relic(owned: Array, exclude: Array, rng: RandomNumberGenerator) -> String:
	var pools := [[], [], []]
	for id in D.all_relic_ids():
		if owned.has(id) or exclude.has(id):
			continue
		pools[D.relic_rarity(id)].append(id)
	var tw := 0
	for r in 3:
		if not pools[r].is_empty():
			tw += D.RARITY_WEIGHTS[r]
	if tw == 0:
		return ""
	var x := rng.randi_range(0, tw - 1)
	for r in 3:
		if pools[r].is_empty():
			continue
		if x < D.RARITY_WEIGHTS[r]:
			var pool: Array = pools[r]
			return pool[rng.randi_range(0, pool.size() - 1)]
		x -= D.RARITY_WEIGHTS[r]
	return ""


## ポーズ強化2枠の抽選。-1 は空欄、-2 は「すべてMAX」
static func draw_pose_slots(levels: Array, rng: RandomNumberGenerator) -> Array:
	var cands := []
	for p in D.POSE_COUNT:
		if levels[p] < D.L_MAX:
			cands.append(p)
	if cands.is_empty():
		return [-2, -2]
	var sh := shuffled(cands, rng)
	if sh.size() == 1:
		return [sh[0], -1]
	return [sh[0], sh[1]]


## ポーズ強化価格：30×3^Lp（基礎値によらない）
static func pose_price(lp: int) -> int:
	return 30 * int(pow(3, lp))


## 有料更新価格：ceil(40×1.5^U)
static func refresh_price(u: int) -> int:
	return int(ceil(40.0 * pow(1.5, u) - 1e-9))


static func fmt_num(v: float) -> String:
	if is_equal_approx(v, round(v)):
		return str(int(round(v)))
	var s := "%.2f" % v
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	return s


static func fmt_prob(p: float) -> String:
	if p <= 0.0:
		return "0%"
	if p < 0.001:
		return "<0.1%"
	return "%.1f%%" % (p * 100.0)
