class_name GameData
extends RefCounted
## 静的データ（仕様書 v4.0）

const SPEC_VERSION := "4.0"

const AREA_YUTTARI := 0
const AREA_HASHAGI := 1
const AREA_NAMES := ["ゆったり", "はしゃぎ"]

const POSE_COUNT := 10
## エリア別の初期基礎値（ゆったり, はしゃぎ）
const BASE_INIT := [12.0, 20.0]
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

const TUTORIAL := {
	"t1": "10サイクル後の「所持おさかな」で目標を判定します。\n買い物で使ったおさかなは残高から減るので注意しましょう。",
	"t2": "最初に買うレリック1個は、レアリティによらず無料です。",
	"t3": "サイコロの出目に応じて移動します。\n移動前に、終点になりそうなポーズを予想しましょう。",
	"t4": "確率表示は「通常移動のみ」の終点分布です。\n早期停止・追加移動・的中扱いは含みません。",
	"t5": "通常は的中で報酬2倍。はずれでも訪問した分のおさかなを得ます。",
	"t6": "毎サイクル、アクアマリンを1個得ます。\nレリック購入や、対応レリックの能動効果に使えます。",
	"t7": "共通マークが出現しました。\nマークへの訪問は訪問倍率+0.5です。",
	"t8": "歩数が0以下なので移動しません。\n開始地点を予想すると的中します。ただし訪問報酬は0です。",
	"t9": "ラウンド達成！ レリック枠+2・無料更新権+1を得ました。\n無料更新では、有料更新の価格は上がりません。",
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
