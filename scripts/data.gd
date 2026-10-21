class_name GameData
extends RefCounted
## 静的データ（仕様書 v4.0）

const SPEC_VERSION := "4.0"

const AREA_YUTTARI := 0
const AREA_HASHAGI := 1
const AREA_NAMES := ["ゆったり", "はしゃぎ"]

const POSE_COUNT := 10
## エリア別の初期基礎値（ゆったり, はしゃぎ）
const BASE_INIT := [12.0, 16.0]
const L_MAX := 5

## ID, 名称, エリア, x, y
const POSES := [
	["P01", "ぷかぷか", 0, 0.25, 0.12],
	["P02", "ほおづえ", 0, 0.39, 0.39],
	["P03", "うとうと", 0, 0.34, 0.78],
	["P04", "まるまる", 0, 0.16, 0.78],
	["P05", "おやすみ", 0, 0.11, 0.39],
	["P06", "きょろきょろ", 1, 0.75, 0.12],
	["P07", "てをふる", 1, 0.89, 0.39],
	["P08", "くるり", 1, 0.84, 0.78],
	["P09", "ばんざい", 1, 0.66, 0.78],
	["P10", "ピース", 1, 0.61, 0.39],
]

## characters.png 内の各セル（640×480）での人物の範囲
const POSE_BBOX := [
	Rect2(269, 117, 102, 315), Rect2(247, 207, 145, 225), Rect2(231, 220, 178, 212),
	Rect2(247, 230, 146, 202), Rect2(222, 326, 195, 106), Rect2(267, 112, 106, 320),
	Rect2(263, 111, 114, 321), Rect2(264, 113, 111, 319), Rect2(256, 102, 128, 330),
	Rect2(260, 110, 120, 322),
]

## ラウンド：表示名, 目標W
const ROUNDS := [
	["ちいさな水槽", 400],
	["にぎやかな水槽", 1600],
	["きらめく水槽", 4500],
	["ひろがる水槽", 10000],
	["ゆらゆらアクアリウム", 20000],
]
const ROUND_COUNT := 5
const CYCLES_PER_ROUND := 10

const RARITY_COMMON := 0
const RARITY_UNCOMMON := 1
const RARITY_RARE := 2
const RARITY_NAMES := ["コモン", "アンコモン", "レア"]
const RARITY_WEIGHTS := [60, 30, 10]
const RARITY_PRICES := [3, 5, 7]

## レリックのデータ（名称・レアリティ・効果量・説明文）は res://data/relics/*.tres
const RELIC_DIR := "res://data/relics"

## チュートリアル（初回プレイ）。state["tut"] がこの順に進む。"play" は移動・精算中
const TUT_STEPS := ["intro", "roll", "weights", "prob", "guess", "reward", "play", "round",
	"relic", "aqua", "pose", "refresh"]
## 初回プレイで固定する出目・経路（P01→P06→P07→P02）・ショップの初期商品
const TUT_DICE := [3]
const TUT_PATH := [5, 6, 1]
const TUT_SHOP_RELICS := ["R11", "R05", "R12"]
const TUT_SHOP_POSES := [1, 6]
## 設定に保存する既読フラグ（done：チュートリアル完了、mark：共通マークの説明）
const TUT_FLAGS := ["done", "mark"]

const TUTORIAL := {
	"intro": ["ゆらゆらアクアリウムへようこそ",
		"サイコロを振ってキャラクターを移動させ、[color=#ffd479]移動を終えるポーズを予想する[/color]ゲームです。\n移動するたびにおさかなを獲得し、予想が当たると報酬が増えます。\nおさかなを集めて、ラウンドごとの目標を達成しましょう。"],
	"roll": "まずはサイコロをふってみよう！",
	"weights": ["移動のしくみ",
		"キャラクターは出目の数だけ、矢印に沿ってポーズからポーズへ1歩ずつ移動します。どの矢印に進むかは、1歩ごとにランダムに決まります。\n矢印には「重み」があり、重みが大きい矢印ほど選ばれやすくなります。\n[color=#ffd479]進む確率 ＝ その矢印の重み ÷ 出ている矢印の重みの合計[/color]"],
	"prob": "数字は、%d歩移動し終えたときに各ポーズにいる確率です。\n確率が高いポーズほど当たりやすくなります。\n[color=#93a9c4]ポーズにカーソルを合わせると、出ている矢印の重みと確率も見られます。[/color]",
	"guess": "移動を終えるポーズを予想しよう！\nポーズをクリックして選んでね。",
	"guess_go": "よければ「ここにする」で決定！",
	"reward": ["報酬のしくみ",
		"1歩ごとに、到着したポーズの[color=#ffd479]基礎値[/color]（ポーズの左上の数字）ぶんのおさかなを獲得します。\n移動を終えたポーズが予想どおりなら[color=#ffd479]的中[/color]で、報酬が2倍になります。\nはずれても、訪問した分のおさかなはもらえます。"],
	"round": ["ラウンド",
		"サイコロ→予想→移動→精算 の流れを1サイクルとして、[color=#ffd479]10サイクルで1ラウンド[/color]です。\nラウンド最後のサイクルを終えたとき、所持おさかなが[color=#ffd479]目標額以上[/color]ならラウンド達成。届かなければゲームオーバーです。\nショップで使ったおさかなは減るので、目標とのバランスに気をつけましょう。\nラウンド達成でレリック枠+2・無料更新権+1。全5ラウンドを達成するとクリアです。"],
	"relic": "レリックを買ってみよう！\n持っているだけで効果を発揮します。\n最初の1個は無料です。",
	"aqua": "レリックはアクアマリンで買います。\nアクアマリンは毎サイクル1個もらえるほか、レリックの効果で増えることもあります。",
	"pose": "ポーズ強化を買ってみよう！\nおさかなを使って、ポーズの基礎値を1.5倍にできます。",
	"refresh": "最後にショップを更新してみよう！\n商品がすべて入れ替わります。最初の1回は無料です。",
	"mark": ["共通マーク",
		"マークのついたポーズが[color=#ffd479]共通マーク[/color]です。\nマークのポーズに訪問するたび、その訪問の倍率が+0.5されます。\nマークはサイクルごとに選び直され、レリックの効果で数が増えます。"],
}


static func pose_id(p: int) -> String:
	return POSES[p][0]


static func pose_name(p: int) -> String:
	return POSES[p][1]


static func area_of(p: int) -> int:
	return POSES[p][2]


static func pose_pos(p: int) -> Vector2:
	return Vector2(POSES[p][3], POSES[p][4])


static func cw_of(p: int) -> int:
	var base := (p / 5) * 5
	return base + (p - base + 1) % 5


static func ccw_of(p: int) -> int:
	var base := (p / 5) * 5
	return base + (p - base + 4) % 5


static func cross_of(p: int) -> int:
	return (p + 5) % 10


static var _relics := {}


## 全レリックを読み込む（ID → RelicData）
static func relics() -> Dictionary:
	if _relics.is_empty():
		var files := Array(ResourceLoader.list_directory(RELIC_DIR))
		files.sort()
		for f in files:
			if not f.ends_with(".tres"):
				continue
			var r := load(RELIC_DIR.path_join(f)) as RelicData
			if r == null or r.id == "":
				push_error("レリックを読み込めません：" + f)
				continue
			_relics[r.id] = r
	return _relics


static func relic(id: String) -> RelicData:
	return relics()[id]


static func relic_index(id: String) -> int:
	return int(id.substr(1)) - 1


static func relic_name(id: String) -> String:
	return relic(id).display_name


static func relic_effect(id: String) -> String:
	return relic(id).description_text()


static func relic_note(id: String) -> String:
	return relic(id).note_text()


## 効果量（RelicData.values）
static func relic_value(id: String, key: String) -> float:
	return relic(id).value(key)


static func relic_rarity(id: String) -> int:
	return relic(id).rarity


static func relic_price(id: String) -> int:
	return relic(id).price


static func all_relic_ids() -> Array:
	var ids := relics().keys()
	ids.sort()
	return ids


static func round_name(r: int) -> String:
	return ROUNDS[clampi(r, 1, ROUND_COUNT) - 1][0]


static func round_target(r: int) -> int:
	return ROUNDS[clampi(r, 1, ROUND_COUNT) - 1][1]


static func relic_slots(r: int) -> int:
	return 4 + 2 * (clampi(r, 1, ROUND_COUNT) - 1)
