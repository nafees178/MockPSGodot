class_name MainMenu
extends Control

# --- Node References ---
@onready var audio_manager: MenuAudio = $MenuAudio
@onready var bg: MenuBackground = $Background
@onready var operative_sprite: AnimatedSprite2D = %OperativeSprite
@onready var operative_stance_label: Label = %OperativeStanceLabel
@onready var showcase_platform: ShowcasePlatform = %ShowcasePlatform
@onready var scenic_backdrop: TextureRect = %ScenicBackdrop

# Level Select Elements
@onready var btn_level_1: Button = %BtnLevel1
@onready var btn_level_2: Button = %BtnLevel2
@onready var btn_level_3: Button = %BtnLevel3
@onready var level_info_label: Label = %LevelInfoLabel

# Transition elements
@onready var transition_layer: CanvasLayer = %TransitionLayer
@onready var shutter_top: ColorRect = %ShutterTop
@onready var shutter_bottom: ColorRect = %ShutterBottom
@onready var shutter_line: ColorRect = %ShutterLine
@onready var transition_content: VBoxContainer = %TransitionContent
@onready var transition_bar: ProgressBar = %TransitionBar
@onready var loading_label: Label = %LoadingLabel

# Modals
@onready var modal_backdrop: ColorRect = %ModalBackdrop
@onready var settings_modal: Control = %SettingsModal
@onready var quit_modal: Control = %QuitModal

# Main Buttons
@onready var btn_deploy: Button = %BtnDeploy
@onready var btn_settings: Button = %BtnSettings
@onready var btn_quit: Button = %BtnQuit

# Settings Controls
@onready var master_slider: HSlider = %MasterSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var master_val_label: Label = %MasterValLabel
@onready var sfx_val_label: Label = %SfxValLabel
@onready var mute_checkbox: CheckBox = %MuteCheckBox
@onready var window_option: OptionButton = %WindowOption
@onready var vsync_check: CheckBox = %VsyncCheck

# Telemetry
@onready var fps_label: Label = %FpsLabel

# State
var is_transitioning: bool = false
var active_modal: Control = null
var current_stance_idx: int = 0
var selected_level_index: int = 0

const LEVEL_SCENES: Array[String] = [
	"res://level1.tscn",
	"res://Level_2.tscn",
	"res://Level 3.tscn"
]

const LEVEL_NAMES: Array[String] = [
	"GRASSLAND",
	"AUTUMN FOREST",
	"WINTER WORLD"
]

const LEVEL_SUBTITLES: Array[String] = [
	"MISSION 01: GRASSLAND FRONTIER",
	"MISSION 02: AUTUMN WOODS & GROVES",
	"MISSION 03: GLACIAL SUMMIT PEAKS"
]

const LEVEL_ACCENTS: Array[Color] = [
	Color(0.35, 0.85, 0.55), # Green
	Color(1.0, 0.65, 0.28),  # Amber
	Color(0.42, 0.80, 1.0)   # Cyan
]

const SCENIC_BG_PATHS: Array[String] = [
	"res://TileMap/Seasonal Tilesets/Seasonal Tilesets/1 - Grassland/Background parts/_Complete_static_BG_(288 x 208).png",
	"res://TileMap/Seasonal Tilesets/Seasonal Tilesets/2 - Autumn Forest/Background parts/_Complete_static_BG_(288 x 208).png",
	"res://TileMap/Seasonal Tilesets/Seasonal Tilesets/4 - Winter World/Background parts/_Complete_static_BG_(288 x 208).png"
]

var scenic_textures: Array[Texture2D] = []

# Grounded stances for preview
const STANCES: Array[String] = [
	"idle",
	"run",
	"katana_run",
	"punch",
	"dash",
	"crouch_idle"
]

# Exact vertical offsets ensuring every animation's shoes rest directly on the platform (y=380.0)
const ANIM_Y_OFFSETS: Dictionary = {
	"idle": 195.0,
	"run": 195.0,
	"katana_run": 195.0,
	"dash": 195.0,
	"crouch_idle": 195.0,
	"katana": 195.0,
	"walk": 241.0,
	"punch": 282.0
}

func _ready() -> void:
	SettingsManager.load_settings()
	_load_scenic_textures()
	
	_setup_styles()
	_setup_settings_ui()
	_connect_signals()
	
	_set_character_animation("idle")
	_select_level(0, false) # Default to Level 1
	
	if transition_layer:
		transition_layer.visible = true
		shutter_top.position = Vector2(0, -362)
		shutter_bottom.position = Vector2(0, 720)
		shutter_line.modulate.a = 0.0
		transition_content.modulate.a = 0.0
	
	_hide_all_modals_instant()

func _load_scenic_textures() -> void:
	scenic_textures.clear()
	for path in SCENIC_BG_PATHS:
		if ResourceLoader.exists(path):
			scenic_textures.append(load(path))
		else:
			scenic_textures.append(null)

func _process(_delta: float) -> void:
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

func _setup_styles() -> void:
	var font = load("res://audio/kenvector_future.ttf") as Font
	var buttons: Array[Button] = [btn_deploy, btn_settings, btn_quit]
	for b in buttons:
		if b == null:
			continue
		_apply_button_theme(b, font, b == btn_deploy)
	
	_update_level_buttons_visuals()

func _apply_button_theme(btn: Button, font: Font, is_primary: bool) -> void:
	if font:
		btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 14 if is_primary else 13)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.20, 0.32, 0.48, 0.95) if is_primary else Color(0.14, 0.16, 0.22, 0.92)
	style_normal.border_color = Color(0.42, 0.62, 0.85, 0.9) if is_primary else Color(0.26, 0.32, 0.42, 0.8)
	style_normal.border_width_left = 3 if is_primary else 2
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 2
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_right = 4
	style_normal.content_margin_left = 18
	style_normal.content_margin_right = 18
	style_normal.content_margin_top = 10
	style_normal.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", style_normal)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.26, 0.42, 0.62, 1.0) if is_primary else Color(0.20, 0.24, 0.32, 0.96)
	style_hover.border_color = Color(0.60, 0.78, 1.0, 1.0) if is_primary else Color(0.42, 0.52, 0.66, 1.0)
	style_hover.border_width_left = 4 if is_primary else 3
	style_hover.border_width_top = 1
	style_hover.border_width_right = 1
	style_hover.border_width_bottom = 2
	style_hover.corner_radius_top_left = 4
	style_hover.corner_radius_bottom_left = 4
	style_hover.corner_radius_top_right = 4
	style_hover.corner_radius_bottom_right = 4
	style_hover.content_margin_left = 22
	style_hover.content_margin_right = 18
	style_hover.content_margin_top = 10
	style_hover.content_margin_bottom = 10
	btn.add_theme_stylebox_override("hover", style_hover)
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.14, 0.24, 0.38, 1.0)
	style_pressed.border_color = Color(0.7, 0.85, 1.0, 1.0)
	style_pressed.border_width_left = 3
	style_pressed.border_width_top = 2
	style_pressed.border_width_right = 1
	style_pressed.border_width_bottom = 1
	style_pressed.content_margin_left = 20
	style_pressed.content_margin_right = 18
	style_pressed.content_margin_top = 10
	style_pressed.content_margin_bottom = 10
	btn.add_theme_stylebox_override("pressed", style_pressed)
	
	var style_focus = StyleBoxFlat.new()
	style_focus.bg_color = Color(0.20, 0.32, 0.48, 0.4)
	style_focus.border_color = Color(0.5, 0.75, 1.0, 1.0)
	style_focus.border_width_left = 2
	style_focus.border_width_top = 2
	style_focus.border_width_right = 2
	style_focus.border_width_bottom = 2
	btn.add_theme_stylebox_override("focus", style_focus)

func _update_level_buttons_visuals() -> void:
	var level_buttons = [btn_level_1, btn_level_2, btn_level_3]
	for i in range(level_buttons.size()):
		var b: Button = level_buttons[i]
		if b == null:
			continue
		var is_selected = (i == selected_level_index)
		var accent: Color = LEVEL_ACCENTS[i]
		
		var s_norm = StyleBoxFlat.new()
		s_norm.corner_radius_top_left = 4
		s_norm.corner_radius_top_right = 4
		s_norm.corner_radius_bottom_right = 4
		s_norm.corner_radius_bottom_left = 4
		s_norm.content_margin_left = 12
		s_norm.content_margin_right = 12
		s_norm.content_margin_top = 8
		s_norm.content_margin_bottom = 8
		
		if is_selected:
			s_norm.bg_color = Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.95)
			s_norm.border_color = accent
			s_norm.border_width_left = 2
			s_norm.border_width_top = 2
			s_norm.border_width_right = 2
			s_norm.border_width_bottom = 3
			s_norm.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
			s_norm.shadow_size = 5
			b.add_theme_color_override("font_color", Color.WHITE)
		else:
			s_norm.bg_color = Color(0.12, 0.14, 0.19, 0.88)
			s_norm.border_color = Color(0.24, 0.28, 0.38, 0.7)
			s_norm.border_width_left = 1
			s_norm.border_width_top = 1
			s_norm.border_width_right = 1
			s_norm.border_width_bottom = 2
			b.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 0.9))
		
		b.add_theme_stylebox_override("normal", s_norm)
		
		var s_hov = s_norm.duplicate() as StyleBoxFlat
		s_hov.bg_color = Color(accent.r * 0.32, accent.g * 0.32, accent.b * 0.32, 0.98)
		s_hov.border_color = accent.lightened(0.2)
		b.add_theme_stylebox_override("hover", s_hov)

func _select_level(idx: int, play_sound: bool = true) -> void:
	if idx < 0 or idx >= LEVEL_SCENES.size():
		return
	selected_level_index = idx
	
	if play_sound:
		audio_manager.play_click()
	
	# 1. Update background theme (parallax layers & weather particles)
	if bg:
		bg.set_level_theme(idx)
	
	# 2. Update character platform theme
	if showcase_platform:
		showcase_platform.set_level_theme(idx)
	
	# 3. Update scenic backdrop in showcase card
	if scenic_backdrop and idx < scenic_textures.size() and scenic_textures[idx] != null:
		scenic_backdrop.texture = scenic_textures[idx]
		var t = create_tween()
		t.tween_property(scenic_backdrop, "modulate:a", 0.15, 0.08)
		t.tween_property(scenic_backdrop, "modulate:a", 0.35, 0.2).set_trans(Tween.TRANS_QUAD)
	
	# 4. Update Deploy Button & Info Label
	if btn_deploy:
		btn_deploy.text = "DEPLOY: " + LEVEL_NAMES[idx]
	
	if level_info_label:
		level_info_label.text = LEVEL_SUBTITLES[idx]
		level_info_label.add_theme_color_override("font_color", LEVEL_ACCENTS[idx])
	
	# 5. Update level buttons appearance
	_update_level_buttons_visuals()

func _setup_settings_ui() -> void:
	if master_slider:
		master_slider.value = SettingsManager.master_volume * 100.0
		master_val_label.text = "%d%%" % int(master_slider.value)
	if sfx_slider:
		sfx_slider.value = SettingsManager.sfx_volume * 100.0
		sfx_val_label.text = "%d%%" % int(sfx_slider.value)
	if mute_checkbox:
		mute_checkbox.button_pressed = SettingsManager.audio_muted
		
	if window_option:
		window_option.clear()
		window_option.add_item("Windowed", 0)
		window_option.add_item("Fullscreen", 2)
		window_option.selected = 1 if SettingsManager.window_mode == 2 else 0
		
	if vsync_check:
		vsync_check.button_pressed = SettingsManager.vsync_enabled

func _connect_signals() -> void:
	btn_deploy.pressed.connect(_on_deploy_pressed)
	btn_settings.pressed.connect(func(): _open_modal(settings_modal))
	btn_quit.pressed.connect(func(): _open_modal(quit_modal))
	
	var btn_configs = [
		{"btn": btn_deploy, "anim": "run"},
		{"btn": btn_settings, "anim": "idle"},
		{"btn": btn_quit, "anim": "crouch_idle"}
	]
	
	for cfg in btn_configs:
		var b: Button = cfg["btn"]
		var anim: String = cfg["anim"]
		if b:
			b.mouse_entered.connect(func(): _on_button_hover(b, anim))
			b.mouse_exited.connect(func(): _on_button_exit(b))
			b.focus_entered.connect(func(): _on_button_hover(b, anim))
			b.focus_exited.connect(func(): _on_button_exit(b))
	
	# Level Select button signals
	var level_buttons = [btn_level_1, btn_level_2, btn_level_3]
	for i in range(level_buttons.size()):
		var lb: Button = level_buttons[i]
		if lb:
			var idx = i
			lb.pressed.connect(func(): _select_level(idx, true))
			lb.mouse_entered.connect(func(): audio_manager.play_hover())
	
	if master_slider:
		master_slider.value_changed.connect(_on_master_slider_changed)
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	if mute_checkbox:
		mute_checkbox.toggled.connect(_on_mute_toggled)
	if window_option:
		window_option.item_selected.connect(_on_window_mode_selected)
	if vsync_check:
		vsync_check.toggled.connect(_on_vsync_toggled)
	
	%BtnCloseSettings.pressed.connect(_close_active_modal)
	%BtnResetSettings.pressed.connect(_reset_settings_defaults)
	%BtnConfirmQuit.pressed.connect(func(): get_tree().quit())
	%BtnCancelQuit.pressed.connect(_close_active_modal)
	
	%BtnCycleStance.pressed.connect(_on_cycle_stance_pressed)
	%BtnCycleStance.mouse_entered.connect(func(): audio_manager.play_hover())

func _set_character_animation(anim_name: String) -> void:
	if operative_sprite == null:
		return
	operative_sprite.play(anim_name)
	var target_y = ANIM_Y_OFFSETS.get(anim_name, 195.0)
	operative_sprite.position = Vector2(440.0, target_y)
	if operative_stance_label:
		operative_stance_label.text = "Animation: %s" % anim_name.capitalize().replace("_", " ")

func _on_button_hover(btn: Button, anim: String) -> void:
	audio_manager.play_hover()
	var t = create_tween()
	t.tween_property(btn, "scale", Vector2(1.025, 1.025), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	if anim != "":
		_set_character_animation(anim)

func _on_button_exit(btn: Button) -> void:
	var t = create_tween()
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var active_stance = STANCES[current_stance_idx]
	_set_character_animation(active_stance)

func _on_deploy_pressed() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	SettingsManager.reset_game_state()
	
	audio_manager.play_deploy()
	
	var target_scene = LEVEL_SCENES[selected_level_index]
	if loading_label:
		loading_label.text = "ENTERING %s..." % LEVEL_NAMES[selected_level_index]
	
	# 1. Ninja dynamic dash across platform to the right
	_set_character_animation("dash")
	if operative_sprite:
		var sprite_tween = create_tween().set_parallel(true)
		sprite_tween.tween_property(operative_sprite, "position:x", 780.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		sprite_tween.tween_property(operative_sprite, "modulate:a", 0.0, 0.42).set_ease(Tween.EASE_IN)
	
	# 2. Main layout smooth fade & slight scale down
	var main_layout = $MainLayout
	var top_header = $TopHeader
	var t = create_tween()
	t.parallel().tween_property(main_layout, "modulate:a", 0.2, 0.4)
	t.parallel().tween_property(main_layout, "scale", Vector2(0.98, 0.98), 0.4)
	t.parallel().tween_property(top_header, "modulate:a", 0.2, 0.4)
	
	# 3. Dual shutter slam wipe with glowing seam line
	t.parallel().tween_property(shutter_top, "position:y", 0.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(shutter_bottom, "position:y", 358.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(shutter_line, "modulate:a", 1.0, 0.25)
	
	# 4. Fade in loading bar
	t.chain().tween_property(transition_content, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(transition_bar, "value", 100.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 5. Scene switch
	t.chain().tween_interval(0.08)
	t.chain().tween_callback(func():
		get_tree().change_scene_to_file(target_scene)
	)

func _open_modal(modal: Control) -> void:
	if modal == null:
		return
	audio_manager.play_open()
	_hide_all_modals_instant()
	
	active_modal = modal
	if modal_backdrop:
		modal_backdrop.visible = true
		modal_backdrop.modulate.a = 0.0
		var bt = create_tween()
		bt.tween_property(modal_backdrop, "modulate:a", 1.0, 0.18)
	
	modal.visible = true
	modal.modulate.a = 0.0
	modal.scale = Vector2(0.97, 0.97)
	modal.pivot_offset = modal.size * 0.5
	
	var t = create_tween().set_parallel(true)
	t.tween_property(modal, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(modal, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _close_active_modal() -> void:
	if active_modal == null:
		return
	audio_manager.play_back()
	
	var m = active_modal
	active_modal = null
	
	var t = create_tween().set_parallel(true)
	t.tween_property(m, "modulate:a", 0.0, 0.12)
	t.tween_property(m, "scale", Vector2(0.97, 0.97), 0.12)
	if modal_backdrop:
		t.tween_property(modal_backdrop, "modulate:a", 0.0, 0.12)
	
	t.chain().tween_callback(func():
		m.visible = false
		if modal_backdrop:
			modal_backdrop.visible = false
	)

func _hide_all_modals_instant() -> void:
	if modal_backdrop:
		modal_backdrop.visible = false
	var modals = [settings_modal, quit_modal]
	for m in modals:
		if m:
			m.visible = false

func _on_cycle_stance_pressed() -> void:
	current_stance_idx = (current_stance_idx + 1) % STANCES.size()
	var stance = STANCES[current_stance_idx]
	_set_character_animation(stance)
	audio_manager.play_click()

func _on_master_slider_changed(val: float) -> void:
	SettingsManager.master_volume = val / 100.0
	master_val_label.text = "%d%%" % int(val)
	SettingsManager.apply_audio_settings()
	SettingsManager.save_settings()

func _on_sfx_slider_changed(val: float) -> void:
	SettingsManager.sfx_volume = val / 100.0
	sfx_val_label.text = "%d%%" % int(val)
	SettingsManager.apply_audio_settings()
	SettingsManager.save_settings()
	audio_manager.play_hover()

func _on_mute_toggled(pressed: bool) -> void:
	SettingsManager.audio_muted = pressed
	SettingsManager.apply_audio_settings()
	SettingsManager.save_settings()

func _on_window_mode_selected(idx: int) -> void:
	SettingsManager.window_mode = 2 if idx == 1 else 0
	SettingsManager.apply_video_settings()
	SettingsManager.save_settings()
	audio_manager.play_click()

func _on_vsync_toggled(pressed: bool) -> void:
	SettingsManager.vsync_enabled = pressed
	SettingsManager.apply_video_settings()
	SettingsManager.save_settings()

func _reset_settings_defaults() -> void:
	SettingsManager.master_volume = 1.0
	SettingsManager.sfx_volume = 0.9
	SettingsManager.audio_muted = false
	SettingsManager.window_mode = 0
	SettingsManager.vsync_enabled = true
	SettingsManager.apply_all_settings()
	SettingsManager.save_settings()
	_setup_settings_ui()
	audio_manager.play_click()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if active_modal != null:
				_close_active_modal()
			else:
				_open_modal(quit_modal)
		elif event.keycode == KEY_F11:
			if SettingsManager.window_mode == 2:
				SettingsManager.window_mode = 0
			else:
				SettingsManager.window_mode = 2
			SettingsManager.apply_video_settings()
			SettingsManager.save_settings()
			if window_option:
				window_option.selected = 1 if SettingsManager.window_mode == 2 else 0
		elif event.keycode == KEY_1:
			_select_level(0)
		elif event.keycode == KEY_2:
			_select_level(1)
		elif event.keycode == KEY_3:
			_select_level(2)
