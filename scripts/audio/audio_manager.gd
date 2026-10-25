extends Node
## Plays sound effects from a small voice pool and a looping ambient track.
## Buses ("Music", "SFX") are created at runtime so no bus layout file is needed.

const SFX := {
	"tap": preload("res://assets/audio/sfx/tap.wav"),
	"rotate": preload("res://assets/audio/sfx/rotate.wav"),
	"toggle": preload("res://assets/audio/sfx/toggle.wav"),
	"flow": preload("res://assets/audio/sfx/flow.wav"),
	"connect": preload("res://assets/audio/sfx/connect.wav"),
	"bloom": preload("res://assets/audio/sfx/bloom.wav"),
	"complete": preload("res://assets/audio/sfx/complete.wav"),
	"unlock": preload("res://assets/audio/sfx/unlock.wav"),
	"ui_click": preload("res://assets/audio/sfx/ui_click.wav"),
	"ui_back": preload("res://assets/audio/sfx/ui_back.wav"),
	"hint": preload("res://assets/audio/sfx/hint.wav"),
	"drip": preload("res://assets/audio/sfx/drip.wav"),
}
const MUSIC := preload("res://assets/audio/music/verdant_ambience.wav")
const VOICES := 8

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_volume := 0.7
var _sfx_volume := 0.9


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	var stream: AudioStreamWAV = MUSIC
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_music.stream = stream
	add_child(_music)
	apply_volumes(_music_volume, _sfx_volume)


func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func apply_volumes(music: float, sfx: float) -> void:
	_music_volume = music
	_sfx_volume = sfx
	_ensure_buses()
	_set_bus("Music", music)
	_set_bus("SFX", sfx)


func _set_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


func play(sfx_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not SFX.has(sfx_name) or _pool.is_empty():
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = SFX[sfx_name]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func play_music() -> void:
	if _music and not _music.playing:
		_music.volume_db = -30.0
		_music.play()
		create_tween().tween_property(_music, "volume_db", 0.0, 2.5)


func is_music_playing() -> bool:
	return _music != null and _music.playing
