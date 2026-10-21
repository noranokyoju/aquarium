extends Control
## ポーズのネットワーク表示（有向リンク・確率・マーク・開始地・予想）

signal node_clicked(p: int)
signal node_hovered(p: int)

const D := preload("res://scripts/data.gd")
const R := 27.0
const MARK_SIZE := 24.0
## 共通マークが回る間隔と、1回転にかける秒数
const MARK_SPIN_EVERY := 3.0
const MARK_SPIN_TIME := 0.6
const PAIR_OFFSET := 5.0
## 跨ぎリンクの曲がり（P01↔P06 … P05↔P10、正規化y方向）
const CROSS_BEND := [-0.16, -0.21, -0.16, 0.22, 0.26]
## 自己ループを出す向き（度、右=0・下=正）。左上は基礎値の丸枠と重ならないよう避ける
const LOOP_ANGLE := [180.0, 170.0, 45.0, 160.0, 160.0, 0.0, -31.0, -31.0, -31.0, 180.0]

var bases: Array = []
var levels: Array = []
var relics: Array = []
var link_bases: Array = []   # 重み計算用の基礎値（作戦中は固定値）
var next_step := 1
var cur := 0
var start := -1
var guess := -1
var marks: Array = []
var probs: Array = []        # 空なら非表示
var interactive := false
var show_forced := true
var hovered := -1
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func area_rect() -> Rect2:
	return Rect2(0, 56, size.x, 330)


## ネットワーク図の中央（ボタン配置用）
func center_point() -> Vector2:
	var a := area_rect()
	return a.position + Vector2(a.size.x * 0.5, a.size.y * 0.60)


func node_center(p: int) -> Vector2:
	var a := area_rect()
	var n := D.pose_pos(p)
	return a.position + Vector2(n.x * a.size.x, n.y * a.size.y)


func node_at(pos: Vector2) -> int:
	for p in D.POSE_COUNT:
		if pos.distance_to(node_center(p)) <= R + 4:
			return p
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var p := node_at(event.position)
		if p != hovered:
			hovered = p
			node_hovered.emit(p)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive and p >= 0 else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := node_at(event.position)
		if p >= 0:
			node_clicked.emit(p)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hovered != -1:
		hovered = -1
		node_hovered.emit(-1)


# ---------------------------------------------------------------- 描画

func _draw() -> void:
	if bases.is_empty():
		return
	var f := UI.font()
	var half := size.x / 2.0
	draw_style_box(UI.flat(UI.C_YU_BG, Color("2c4a68"), 2, 8), Rect2(0, 0, half - 4, size.y))
	draw_style_box(UI.flat(UI.C_HA_BG, Color("4b3963"), 2, 8), Rect2(half + 4, 0, half - 4, size.y))
	draw_string(f, Vector2(12, 22), "ゆったり", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.C_YU)
	draw_string(f, Vector2(half + 16, 22), "はしゃぎ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.C_HA)

	var forced := show_forced and Logic.is_forced_step(next_step, relics)
	for p in D.POSE_COUNT:
		var links := Logic.base_links(p, relics, link_bases, marks)
		var tw := 0.0
		for l in links:
			tw += l["w"]
		for l in links:
			var prob := float(l["w"]) / tw if tw > 0 else 0.0
			_draw_link(p, l, prob, forced)

	for p in D.POSE_COUNT:
		_draw_node(p, f)
	if interactive and hovered >= 0:
		_draw_click_hint(hovered, f)


func _link_color(p: int, kind: String) -> Color:
	if kind == Logic.KIND_CROSS:
		return UI.C_LINK
	return UI.area_color(D.area_of(p)).lerp(Color.WHITE, 0.1)


func _draw_link(p: int, l: Dictionary, prob: float, forced: bool) -> void:
	var to: int = l["to"]
	var kind: String = l["kind"]
	var col := _link_color(p, kind)
	var disabled: bool = l["w"] <= 0 or (forced and kind != Logic.KIND_CROSS)
	if kind == Logic.KIND_SELF:
		_draw_self_loop(p, col, prob, disabled)
		return
	var pts := _link_points(p, to, kind)
	if pts.size() < 2:
		return
	if disabled:
		col = Color(col, 0.35)
		_dashed(pts, col, 1.5)
		_arrow_head(pts, col, 7.0)
		return
	var w := 1.5 + 5.0 * prob
	if forced:
		col = UI.C_GOLD
	col.a = 0.55 + 0.45 * prob
	draw_polyline(pts, col, w, true)
	_arrow_head(pts, col, 7.0 + w)


## リンクの描画点列。逆向きリンクは進行方向右へずらし、平行に並べる
func _link_points(from: int, to: int, kind: String) -> PackedVector2Array:
	var a := node_center(from)
	var b := node_center(to)
	var raw := PackedVector2Array()
	if kind == Logic.KIND_CROSS:
		var lo := mini(from, to)
		var bend: float = CROSS_BEND[lo] * area_rect().size.y
		var ctrl := (a + b) / 2.0 + Vector2(0, bend * 2.0)
		for i in 33:
			var t := i / 32.0
			raw.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	else:
		for i in 9:
			raw.append(a.lerp(b, i / 8.0))
	# 平行オフセット
	var out := PackedVector2Array()
	for i in raw.size():
		var d: Vector2
		if i == 0:
			d = raw[1] - raw[0]
		elif i == raw.size() - 1:
			d = raw[i] - raw[i - 1]
		else:
			d = raw[i + 1] - raw[i - 1]
		var nrm := Vector2(-d.y, d.x).normalized()
		out.append(raw[i] + nrm * PAIR_OFFSET)
	# ノードの円の外側だけ残す
	var trimmed := PackedVector2Array()
	for pt in out:
		if pt.distance_to(a) > R + 3 and pt.distance_to(b) > R + 6:
			trimmed.append(pt)
	return trimmed


func _arrow_head(pts: PackedVector2Array, col: Color, sz: float) -> void:
	var tip := pts[pts.size() - 1]
	var dir := (tip - pts[pts.size() - 2]).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([tip + dir * 3, tip - dir * sz + nrm * sz * 0.5,
		tip - dir * sz - nrm * sz * 0.5]), col)


func _dashed(pts: PackedVector2Array, col: Color, w: float) -> void:
	var on := true
	var acc := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var len := a.distance_to(b)
		var pos := 0.0
		while pos < len:
			var step := minf(5.0 - acc, len - pos)
			if on:
				draw_line(a.lerp(b, pos / len), a.lerp(b, (pos + step) / len), col, w)
			pos += step
			acc += step
			if acc >= 5.0:
				acc = 0.0
				on = not on


func _draw_self_loop(p: int, col: Color, prob: float, disabled: bool) -> void:
	var c := node_center(p)
	var out_dir := Vector2.from_angle(deg_to_rad(LOOP_ANGLE[p]))
	var lc := c + out_dir * (R + 9)
	var w := 1.5 + 5.0 * prob
	if disabled:
		col = Color(col, 0.35)
		w = 1.5
	else:
		col.a = 0.55 + 0.45 * prob
	var start_ang := out_dir.angle() + PI * 0.75
	draw_arc(lc, 10, start_ang, start_ang + PI * 1.5, 18, col, w, true)
	var end_pt := lc + Vector2.from_angle(start_ang + PI * 1.5) * 10
	var tangent := Vector2.from_angle(start_ang + PI * 1.5 + PI / 2)
	var nrm := Vector2(-tangent.y, tangent.x)
	draw_colored_polygon(PackedVector2Array([end_pt + tangent * 4, end_pt - tangent * 5 + nrm * 4,
		end_pt - tangent * 5 - nrm * 4]), col)


## 共通マーク：上下にゆれ、光がふくらみ、ときどきくるりと回る
func _draw_mark(pos: Vector2, p: int) -> void:
	var t := _time + p * 0.37
	pos.y -= 3.0 * (0.5 + 0.5 * sin(t * 3.0))
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	draw_circle(pos, 10.0 + 3.0 * pulse, Color(UI.C_GOLD, 0.12 + 0.12 * pulse))
	var spin := fmod(t, MARK_SPIN_EVERY) / MARK_SPIN_TIME
	var sx := cos(spin * TAU) if spin < 1.0 else 1.0
	var sz := MARK_SIZE * (1.0 + 0.06 * pulse)
	draw_set_transform(pos, 0.0, Vector2(sx, 1.0))
	draw_texture_rect(UI.icon_mark(), Rect2(-sz / 2.0, -sz / 2.0, sz, sz), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_node(p: int, f: Font) -> void:
	var c := node_center(p)
	var area := D.area_of(p)
	var ac := UI.area_color(area)
	# 現在地のきらめき（黄色）
	if p == cur:
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		draw_circle(c, R + 8 + pulse * 3, Color(UI.C_GOLD, 0.18 + 0.12 * pulse))
	draw_circle(c, R, Color("0e1828") if area == 0 else Color("1b1428"))
	var ring := ac
	var rw := 3.0
	if p == guess:
		ring = UI.C_GOLD
		rw = 4.0
	if p == hovered:
		ring = ring.lightened(0.3)
	draw_arc(c, R, 0, TAU, 40, ring, rw, true)
	# 人物
	var src := UI.pose_region(p)
	var box := R * 1.6
	var sc := minf(box / src.size.x, box / src.size.y)
	var dst := Rect2(c - src.size * sc / 2.0, src.size * sc)
	draw_texture_rect_region(UI.chars(), dst, src)
	# マーク（真上）
	if marks.has(p):
		_draw_mark(c + Vector2(0, -R - 14), p)
	# 基礎値（左上の丸枠数字。小数第1位で四捨五入）
	var btxt := Logic.fmt_num(round(bases[p] * 10.0) / 10.0)
	var bw := f.get_string_size(btxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var bc := c + Vector2(-R, -R) * 0.72
	var br := maxf(10.0, bw / 2.0 + 4.0)
	draw_circle(bc, br, Color("0b1422"))
	draw_arc(bc, br, 0, TAU, 28, ac, 1.5, true)
	draw_string(f, bc + Vector2(-bw / 2.0, 5), btxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.C_TEXT)
	# 名前（開始地・予想バッジを左に並べる）
	var badges := []
	if p == start:
		badges.append(["開始", UI.C_YU if area == 0 else UI.C_HA])
	if p == guess:
		badges.append(["予想", UI.C_GOLD])
	var pname := D.pose_name(p)
	var nw := f.get_string_size(pname, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var total := nw
	for b in badges:
		total += _badge_width(b[0], f) + 3
	var x := c.x - total / 2.0
	var ly := c.y + R + 16
	for b in badges:
		_badge(Vector2(x, ly - 12), b[0], b[1], f)
		x += _badge_width(b[0], f) + 3
	draw_rect(Rect2(Vector2(x - 4, ly - 13), Vector2(nw + 8, 17)), Color(0.03, 0.06, 0.1, 0.85))
	draw_string(f, Vector2(x, ly), pname, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.C_TEXT)
	# 確率
	if not probs.is_empty():
		var pr: float = probs[p]
		var ptxt := Logic.fmt_prob(pr)
		var col := UI.C_GOLD if pr > 0.0 else Color("6d7d92")
		var pw := f.get_string_size(ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var pp := c + Vector2(R + 6, 6)
		if D.pose_pos(p).x > 0.85:
			pp = c + Vector2(-R - 6 - pw, 6)
		draw_rect(Rect2(pp + Vector2(-3, -14), Vector2(pw + 6, 18)), Color(0.03, 0.06, 0.1, 0.85))
		draw_string(f, pp, ptxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)


## 選択できるポーズの上に「クリックで選択」を出す（マークがあればその上）
func _draw_click_hint(p: int, f: Font) -> void:
	var txt := "クリックで選択"
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var c := node_center(p)
	var by := c.y - R - (34.0 if marks.has(p) else 10.0)
	var x := clampf(c.x - tw / 2.0, 6.0, size.x - tw - 6.0)
	var bob := 2.0 * sin(_time * 5.0)
	var rect := Rect2(Vector2(x - 5, by - 14 + bob), Vector2(tw + 10, 19))
	draw_style_box(UI.flat(Color(0.05, 0.08, 0.13, 0.92), UI.C_GOLD, 1, 4, 0), rect)
	draw_string(f, Vector2(x, by + bob), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.C_GOLD)


func _badge_width(txt: String, f: Font) -> float:
	return f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 6


func _badge(pos: Vector2, txt: String, col: Color, f: Font) -> void:
	var w := _badge_width(txt, f)
	draw_rect(Rect2(pos, Vector2(w, 15)), col.darkened(0.55))
	draw_rect(Rect2(pos, Vector2(w, 15)), col, false, 1.0)
	draw_string(f, pos + Vector2(3, 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col.lightened(0.3))
