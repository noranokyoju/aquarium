class_name RelicData
extends Resource
## レリック1個分のデータ（res://data/relics/*.tres）
##
## 説明文・注意書きでは `$変数名$` で values の数値を参照できる。
## - `$bonus$`        … values["bonus"] をそのまま表示（0.4 → 0.4、2.0 → 2）
## - `$bonus:1$`      … 小数点以下の桁数を指定（2.0 → 2.0）
## - `$max_steps+1$`  … 変数を使った式も書ける（Godot の Expression で評価）
## values にない名前は、このリソースのプロパティ（price など）を参照する。

@export var id := ""
@export var display_name := ""
@export_enum("コモン", "アンコモン", "レア") var rarity := 0
## 効果量。キーを説明文の `$キー$` から参照する
@export var values: Dictionary[String, float] = {}
@export_multiline var description := ""
## 省略不可の注意書き（「【」で始まるものは警告色で表示）
@export_multiline var note := ""

var price: int:
	get: return GameData.RARITY_PRICES[rarity]

static var _ref_re := RegEx.create_from_string("\\$([^$]+)\\$")


## 効果量。未定義のキーは 0 として扱い、エラーを出す
func value(key: String) -> float:
	if not values.has(key):
		push_error("%s: values に %s がありません" % [id, key])
		return 0.0
	return values[key]


func description_text() -> String:
	return format_text(description)


func note_text() -> String:
	return format_text(note)


func format_text(text: String) -> String:
	var out := ""
	var last := 0
	for m in _ref_re.search_all(text):
		out += text.substr(last, m.get_start() - last) + _eval_ref(m.get_string(1))
		last = m.get_end()
	return out + text.substr(last)


func _eval_ref(ref: String) -> String:
	var expr_text := ref
	var digits := -1
	var colon := ref.rfind(":")
	if colon >= 0 and ref.substr(colon + 1).is_valid_int():
		expr_text = ref.left(colon)
		digits = ref.substr(colon + 1).to_int()
	var v: Variant
	if values.has(expr_text):
		v = values[expr_text]
	else:
		var names := PackedStringArray(values.keys())
		var expr := Expression.new()
		if expr.parse(expr_text, names) != OK:
			push_error("%s: 説明文の $%s$ を解釈できません（%s）" % [id, ref, expr.get_error_text()])
			return "$%s$" % ref
		v = expr.execute(values.values(), self)
		if expr.has_execute_failed() or not (v is float or v is int):
			push_error("%s: 説明文の $%s$ を評価できません" % [id, ref])
			return "$%s$" % ref
	if digits >= 0:
		return ("%." + str(digits) + "f") % float(v)
	return Logic.fmt_num(float(v))
