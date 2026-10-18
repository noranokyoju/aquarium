class_name UI
extends RefCounted
## 配色・テクスチャ・部品生成の共通処理

const D := preload("res://scripts/data.gd")

const C_BG := Color("0c1626")
const C_PANEL := Color("13233a")
const C_PANEL2 := Color("1a2d47")
const C_BORDER := Color("3f6488")
const C_TEXT := Color("e6eef7")
const C_SUB := Color("93a9c4")
const C_YU := Color("6cc4e0")
const C_YU_BG := Color("142338")
const C_HA := Color("e88aa8")
const C_HA_BG := Color("211a33")
const C_LINK := Color("a58be0")
const C_GOLD := Color("ffd479")
const C_GOOD := Color("8fe0a0")
const C_BAD := Color("ff8a8a")
const C_AQUA := Color("7fe7e0")
const RARITY_COLORS := [Color("a9c3dc"), Color("8fe0a0"), Color("ffc66b")]

const FONT_PATH := "res://assets/font/DotGothic16-Regular.ttf"

static var _font: Font
static var _misc: Texture2D
static var _relics: Texture2D
static var _items: Texture2D
static var _chars: Texture2D
static var _bg: Texture2D
static var _cache := {}


static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH)
	return _font


## misc.png（64px セル）の一部。inner はセル内の切り出し範囲
static func misc(col: int, row: int, inner := Rect2(12, 12, 40, 40)) -> AtlasTexture:
	var key := "m%d_%d_%s" % [col, row, inner]
	if not _cache.has(key):
		if _misc == null:
			_misc = load("res://assets/image/misc.png")
		var a := AtlasTexture.new()
		a.atlas = _misc
		a.region = Rect2(inner.position + Vector2(col * 64, row * 64), inner.size)
		_cache[key] = a
	return _cache[key]


static func icon_fish() -> Texture2D: return misc(7, 0)
static func icon_aqua() -> Texture2D: return misc(2, 1, Rect2(12, 18, 40, 40))
static func icon_mark() -> Texture2D: return misc(1, 2, Rect2(12, 16, 40, 40))
static func icon_dice(v: int) -> Texture2D: return misc(clampi(v, 1, 6) - 1, 0)
static func icon_dice_roll() -> Texture2D: return misc(6, 0)
static func icon_gear() -> Texture2D: return misc(0, 3)


## relics.png（8×5想定）。足りない分は items.png で補う
static func relic_icon(id: String) -> Texture2D:
	var key := "r" + id
	if _cache.has(key):
		return _cache[key]
	if _relics == null:
		_relics = load("res://assets/image/relics.png")
		_items = load("res://assets/image/items.png")
	var i := D.relic_index(id)
	var cols := int(_relics.get_width()) / 32
	var count := cols * (int(_relics.get_height()) / 32)
	var a := AtlasTexture.new()
	if i < count:
		a.atlas = _relics
		a.region = Rect2((i % cols) * 32, (i / cols) * 32, 32, 32)
	else:
		var j := i - count
		var icols := int(_items.get_width()) / 32
		a.atlas = _items
		a.region = Rect2((j % icols) * 32, (j / icols) * 32, 32, 32)
	_cache[key] = a
	return a


static func chars() -> Texture2D:
	if _chars == null:
		_chars = load("res://assets/image/characters.png")
	return _chars


static func background() -> Texture2D:
	if _bg == null:
		_bg = load("res://assets/image/background.png")
	return _bg


## キャラクターの1セル全体
static func pose_cell(p: int) -> AtlasTexture:
	var key := "c%d" % p
	if not _cache.has(key):
		var a := AtlasTexture.new()
		a.atlas = chars()
		a.region = Rect2((p % 5) * 640, (p / 5) * 480, 640, 480)
		_cache[key] = a
	return _cache[key]


## 人物部分のみ（ノード用）
static func pose_region(p: int) -> Rect2:
	var bb: Rect2 = D.POSE_BBOX[p]
	return Rect2(bb.position + Vector2((p % 5) * 640, (p / 5) * 480), bb.size)


static func area_color(a: int) -> Color:
	return C_YU if a == D.AREA_YUTTARI else C_HA


static func flat(bg: Color, border: Color = C_BORDER, bw: int = 2, radius: int = 6, pad: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 16
	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("default_color", "RichTextLabel", C_TEXT)
	t.set_stylebox("normal", "Button", flat(Color("1d3550"), Color("5f9cc0")))
	t.set_stylebox("hover", "Button", flat(Color("26476a"), Color("8cc8e8")))
	t.set_stylebox("pressed", "Button", flat(Color("173049"), Color("8cc8e8")))
	t.set_stylebox("disabled", "Button", flat(Color("1a2433"), Color("33465c")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", C_YU)
	t.set_color("font_disabled_color", "Button", Color("5d6f85"))
	t.set_stylebox("panel", "PanelContainer", flat(C_PANEL))
	t.set_stylebox("panel", "Panel", flat(C_PANEL))
	t.set_stylebox("slider", "HSlider", flat(Color("0a1420"), Color("33465c"), 1, 3, 2))
	t.set_stylebox("grabber_area", "HSlider", flat(Color("3f8fb5"), Color("3f8fb5"), 0, 3, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(Color("5fb4d8"), Color("5fb4d8"), 0, 3, 2))
	t.set_stylebox("panel", "TooltipPanel", flat(Color("0e1a2b"), C_BORDER))
	t.set_color("font_color", "TooltipLabel", C_TEXT)
	return t


static func label(text: String, size: int = 16, color: Color = C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, cb: Callable, size: int = 16) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b


static func icon_rect(tex: Texture2D, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r


static func rich(size: int = 14) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = false
	r.scroll_active = true
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_override("bold_font", font())
	return r


static func num(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


static func hexc(c: Color) -> String:
	return "#" + c.to_html(false)


## レリック説明（省略不可の注意書きを含む）
static func relic_text(id: String) -> String:
	var r := D.relic_rarity(id)
	var s := "[b][color=%s]%s %s[/color][/b]\n[color=%s]%s・%dA[/color]\n%s" % [
		hexc(RARITY_COLORS[r]), id, D.relic_name(id), hexc(C_SUB), D.RARITY_NAMES[r],
		D.relic_price(id), D.relic_effect(id)]
	var note := D.relic_note(id)
	if note != "":
		s += "\n[color=%s]%s[/color]" % [hexc(C_GOLD if note.begins_with("【") else C_SUB), note]
	if ["R08", "R15", "R35", "R21", "R29", "R30", "R36", "R38"].has(id):
		s += "\n[color=%s]共通マーク：各訪問で訪問倍率+0.5（R38所持時は+%.1fに置換）[/color]" % [hexc(C_SUB), D.relic_value("R38", "mark_bonus")]
	return s


static func fmt_time(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
