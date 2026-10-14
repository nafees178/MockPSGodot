class_name MenuAudio
extends Node

static var instance: MenuAudio

var sfx_hover: AudioStream
var sfx_click: AudioStream
var sfx_open: AudioStream
var sfx_back: AudioStream
var sfx_deploy: AudioStream

var audio_player_pool: Array[AudioStreamPlayer] = []

func _ready() -> void:
	instance = self
	
	sfx_hover = load("res://audio/sfx_laser1.ogg")
	sfx_click = load("res://audio/sfx_twoTone.ogg")
	sfx_open = load("res://audio/sfx_shieldUp.ogg")
	sfx_back = load("res://audio/sfx_shieldDown.ogg")
	sfx_deploy = load("res://audio/sfx_zap.ogg")
	
	for i in range(6):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		audio_player_pool.append(p)

func play_sfx(stream: AudioStream, pitch_scale: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if stream == null or SettingsManager.audio_muted:
		return
	
	for p in audio_player_pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch_scale
			var base_vol = linear_to_db(max(SettingsManager.sfx_volume, 0.0001))
			p.volume_db = base_vol + volume_offset_db
			p.play()
			return
	
	var fallback = audio_player_pool[0]
	fallback.stream = stream
	fallback.pitch_scale = pitch_scale
	fallback.volume_db = linear_to_db(max(SettingsManager.sfx_volume, 0.0001)) + volume_offset_db
	fallback.play()

func play_hover() -> void:
	play_sfx(sfx_hover, 1.8, -12.0)

func play_click() -> void:
	play_sfx(sfx_click, 1.0, -6.0)

func play_open() -> void:
	play_sfx(sfx_open, 1.2, -6.0)

func play_back() -> void:
	play_sfx(sfx_back, 1.0, -6.0)

func play_deploy() -> void:
	play_sfx(sfx_deploy, 1.0, -3.0)
