extends Control
## チュートリアル用の簡易ネットワーク図：1つのポーズから出る3本の矢印と、重み・確率の関係

const R := 24.0
## [行き先の位置, 名前, 重み, 色]
const LINKS := [
	[Vector2(440, 64), "時計回りの隣", 6, "yu"],
	[Vector2(60, 64), "反時計回りの隣", 2, "yu"],
	[Vector2(250, 168), "反対のエリア", 2, "ha"],
]
const FROM := Vector2(250, 64)


func _init() -> void:
	custom_minimum_size = Vector2(500, 214)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var f := UI.font()
	var total := 0
	for l in LINKS:
		total += l[2]
	for l in LINKS:
		var to: Vector2 = l[0]
		var w: int = l[2]
		var dir := (to - FROM).normalized()
		var a := FROM + dir * (R + 4)
		var b := to - dir * (R + 6)
		var col := UI.C_LINK.lightened(0.15)
		draw_line(a, b - dir * 8, col, 2.0 + w * 1.2, true)
		var n := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([b, b - dir * 14 + n * 9, b - dir * 14 - n * 9]), col)
		# 重みと確率
		var txt := "重み%d → %d%%" % [w, roundi(100.0 * w / total)]
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var mid := (a + b) / 2.0
		var lp := mid + Vector2(-tw / 2.0, -12) if absf(dir.y) < 0.5 else mid + Vector2(14, 5)
		draw_rect(Rect2(lp + Vector2(-4, -15), Vector2(tw + 8, 20)), Color(0.03, 0.06, 0.1, 0.9))
		draw_string(f, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.C_GOLD)
		_node(to, l[1], UI.C_YU if l[3] == "yu" else UI.C_HA, f)
	_node(FROM, "いまいるポーズ", UI.C_YU, f, true)


func _node(c: Vector2, name: String, col: Color, f: Font, here := false) -> void:
	draw_circle(c, R, col.darkened(0.6))
	draw_arc(c, R, 0, TAU, 32, UI.C_GOLD if here else col, 3.0 if here else 2.0, true)
	var nw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var y := c.y + R + 16 if not here else c.y - R - 8
	draw_string(f, Vector2(c.x - nw / 2.0, y), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.C_TEXT)
