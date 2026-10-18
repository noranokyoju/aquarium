extends Node
## 効果音・BGM（素材がないため簡易的に合成）。Autoload: Sfx

const RATE := 22050

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _bgm: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("BGM") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "BGM")
	if AudioServer.get_bus_index("SE") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SE")
	_sounds["click"] = _tone([880.0], 0.06, 0.25)
	_sounds["dice"] = _noise(0.25, 0.2)
	_sounds["step"] = _tone([660.0, 990.0], 0.09, 0.2)
	_sounds["coin"] = _tone([988.0, 1319.0], 0.18, 0.25)
	_sounds["buy"] = _tone([523.0, 659.0, 784.0], 0.24, 0.25)
	_sounds["hit"] = _tone([784.0, 988.0, 1175.0, 1568.0], 0.5, 0.25)
	_sounds["miss"] = _tone([392.0, 330.0], 0.3, 0.2)
	_sounds["clear"] = _tone([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.9, 0.25)
	_sounds["relic"] = _tone([1319.0, 1760.0], 0.14, 0.2)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SE"
		add_child(p)
		_players.append(p)
	_bgm = AudioStreamPlayer.new()
	_bgm.bus = "BGM"
	_bgm.stream = _make_bgm()
	add_child(_bgm)
	apply_volumes()


func apply_volumes() -> void:
	var s: Dictionary = Game.settings
	_set_bus("Master", s["master"])
	_set_bus("BGM", s["bgm"])
	_set_bus("SE", s["se"])


func _set_bus(name: String, v: int) -> void:
	var idx := AudioServer.get_bus_index(name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, v <= 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001) / 10.0))


func play(name: String) -> void:
	if not _sounds.has(name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _sounds[name]
			p.play()
			return


func play_bgm() -> void:
	if not _bgm.playing:
		_bgm.play()


func _wav(data: PackedByteArray, loop: bool = false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = data.size() / 2
	return w


## 音程を順に鳴らす短いアルペジオ
func _tone(freqs: Array, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var seg := n / freqs.size()
	for i in n:
		var k := mini(i / maxi(seg, 1), freqs.size() - 1)
		var t := float(i) / RATE
		var local := float(i - k * seg) / maxf(seg, 1)
		var env := (1.0 - local) * minf(1.0, local * 40.0)
		var v := sin(TAU * freqs[k] * t) * 0.7 + sin(TAU * freqs[k] * 2.0 * t) * 0.15
		data.encode_s16(i * 2, int(clampf(v * env * vol, -1.0, 1.0) * 32767))
	return _wav(data)


func _noise(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var prev := 0.0
	for i in n:
		var env := 1.0 - float(i) / n
		# ころころ転がる感じのクリック列
		var click := 1.0 if (i % 900) < 120 else 0.25
		prev = prev * 0.6 + r.randf_range(-1, 1) * 0.4
		data.encode_s16(i * 2, int(clampf(prev * env * click * vol * 2.0, -1, 1) * 32767))
	return _wav(data)


## ゆったりしたペンタトニックのループ
func _make_bgm() -> AudioStreamWAV:
	var notes := [0, 4, 7, 9, 12, 9, 7, 4, 2, 7, 9, 14, 12, 9, 7, 2]
	var bass := [0, 0, -3, -3, -5, -5, -7, -5]
	var beat := 0.5
	var total := notes.size() * beat
	var n := int(total * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for k in notes.size():
		var f := 261.63 * pow(2.0, notes[k] / 12.0)
		var start := int(k * beat * RATE)
		var len := int(beat * 2.2 * RATE)
		for i in len:
			var idx := (start + i) % n
			var t := float(i) / RATE
			var env := exp(-t * 2.2) * minf(1.0, t * 60.0)
			buf[idx] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * env * 0.12
	for k in bass.size():
		var f := 130.81 * pow(2.0, bass[k] / 12.0)
		var start := int(k * beat * 2 * RATE)
		var len := int(beat * 2 * RATE)
		for i in len:
			var t := float(i) / RATE
			var env := sin(PI * float(i) / len)
			buf[(start + i) % n] += sin(TAU * f * t) * env * 0.08
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1, 1) * 32767))
	return _wav(data, true)
