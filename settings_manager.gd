class_name SettingsManager
extends RefCounted

const SAVE_PATH: String = "user://game_settings.cfg"

static var master_volume: float = 1.0 # 0.0 to 1.0
static var music_volume: float = 0.8
static var sfx_volume: float = 0.9
static var audio_muted: bool = false

static var window_mode: int = 0 # 0 = Windowed, 1 = Borderless, 2 = Fullscreen
static var vsync_enabled: bool = true
static var target_fps: int = 60 # 0 = unlimited, 60, 120, 144
static var screen_shake: bool = true
static var show_timer: bool = true

# Equipment & Session persistence across levels
static var has_katana: bool = false

static func reset_game_state() -> void:
	has_katana = false

static func load_settings() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(SAVE_PATH)
	if err == OK:
		master_volume = cfg.get_value("audio", "master_volume", 1.0)
		music_volume = cfg.get_value("audio", "music_volume", 0.8)
		sfx_volume = cfg.get_value("audio", "sfx_volume", 0.9)
		audio_muted = cfg.get_value("audio", "audio_muted", false)
		
		window_mode = cfg.get_value("video", "window_mode", 0)
		vsync_enabled = cfg.get_value("video", "vsync_enabled", true)
		target_fps = cfg.get_value("video", "target_fps", 60)
		
		screen_shake = cfg.get_value("gameplay", "screen_shake", true)
		show_timer = cfg.get_value("gameplay", "show_timer", true)
	
	apply_all_settings()

static func save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "audio_muted", audio_muted)
	
	cfg.set_value("video", "window_mode", window_mode)
	cfg.set_value("video", "vsync_enabled", vsync_enabled)
	cfg.set_value("video", "target_fps", target_fps)
	
	cfg.set_value("gameplay", "screen_shake", screen_shake)
	cfg.set_value("gameplay", "show_timer", show_timer)
	
	cfg.save(SAVE_PATH)

static func apply_all_settings() -> void:
	apply_audio_settings()
	apply_video_settings()

static func apply_audio_settings() -> void:
	var master_bus = AudioServer.get_bus_index("Master")
	if master_bus != -1:
		AudioServer.set_bus_mute(master_bus, audio_muted)
		var db = linear_to_db(max(master_volume, 0.0001))
		AudioServer.set_bus_volume_db(master_bus, db)

static func apply_video_settings() -> void:
	match window_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	var mode = DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)
	
	Engine.max_fps = target_fps
