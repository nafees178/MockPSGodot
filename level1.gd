class_name Level1
extends Node2D

@onready var player: Player = get_node_or_null("Player")

var elapsed_time: float = 0.0
var respawn_count: int = 0
var level_finished: bool = false
var pause_menu: PauseMenu = null

var hud_layer: CanvasLayer = null
var weapon_label: Label = null
var state_label: Label = null
var timer_label: Label = null
var respawn_label: Label = null

const WEAPON_NAMES: Array[String] = [
	"Unarmed (Punch)",
	"Katana",
	"Gun"
]

func _ready() -> void:
	SettingsManager.load_settings()
	
	# Setup Pause Menu
	var pause_scene = load("res://pause_menu.tscn") as PackedScene
	if pause_scene:
		pause_menu = pause_scene.instantiate()
		add_child(pause_menu)
	
	_setup_hud()
	
	if player:
		player.state_changed.connect(_on_player_state_changed)
		player.weapon_changed.connect(_on_player_weapon_changed)
		player.respawned.connect(_on_player_respawned)
		_on_player_weapon_changed(player.current_weapon)
	
	# Smooth entrance curtain
	_setup_entrance_transition()

func _setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 50
	add_child(hud_layer)
	
	var font = load("res://audio/kenvector_future.ttf") as Font
	
	var hud_panel = PanelContainer.new()
	hud_panel.position = Vector2(20, 20)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.18, 0.85)
	sb.border_color = Color(0.3, 0.45, 0.65, 0.8)
	sb.border_width_left = 2
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	hud_panel.add_theme_stylebox_override("panel", sb)
	hud_layer.add_child(hud_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	hud_panel.add_child(vbox)
	
	weapon_label = Label.new()
	weapon_label.text = "Weapon: Unarmed"
	if font:
		weapon_label.add_theme_font_override("font", font)
	weapon_label.add_theme_font_size_override("font_size", 10)
	weapon_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	vbox.add_child(weapon_label)
	
	respawn_label = Label.new()
	respawn_label.text = "Respawns: 0"
	if font:
		respawn_label.add_theme_font_override("font", font)
	respawn_label.add_theme_font_size_override("font_size", 9)
	respawn_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.9))
	vbox.add_child(respawn_label)
	
	timer_label = Label.new()
	timer_label.text = "Time: 00:00.00"
	if font:
		timer_label.add_theme_font_override("font", font)
	timer_label.add_theme_font_size_override("font_size", 9)
	timer_label.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0, 0.9))
	timer_label.visible = SettingsManager.show_timer
	vbox.add_child(timer_label)

func _process(delta: float) -> void:
	if not level_finished and not get_tree().paused:
		elapsed_time += delta
		_update_timer()

func _update_timer() -> void:
	if timer_label and timer_label.visible:
		var total_secs = int(elapsed_time)
		var mins = floori(float(total_secs) / 60.0)
		var secs = total_secs % 60
		var ms = int((elapsed_time - float(total_secs)) * 100.0)
		timer_label.text = "Time: %02d:%02d.%02d" % [mins, secs, ms]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and not get_tree().paused:
			get_tree().reload_current_scene()

func _on_player_weapon_changed(new_weapon: int) -> void:
	if weapon_label and new_weapon >= 0 and new_weapon < WEAPON_NAMES.size():
		weapon_label.text = "Weapon: " + WEAPON_NAMES[new_weapon]
		if new_weapon == Player.WeaponType.KATANA:
			weapon_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
		else:
			weapon_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))

func _on_player_state_changed(_old_state: int, _new_state: int) -> void:
	pass

func _on_player_respawned() -> void:
	respawn_count += 1
	if respawn_label:
		respawn_label.text = "Respawns: %d" % respawn_count

func _setup_entrance_transition() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 120
	add_child(canvas)
	
	var shutter_top = ColorRect.new()
	shutter_top.color = Color(0.08, 0.1, 0.14, 1.0)
	shutter_top.size = Vector2(1280, 362)
	shutter_top.position = Vector2(0, 0)
	canvas.add_child(shutter_top)
	
	var shutter_bottom = ColorRect.new()
	shutter_bottom.color = Color(0.08, 0.1, 0.14, 1.0)
	shutter_bottom.size = Vector2(1280, 362)
	shutter_bottom.position = Vector2(0, 358)
	canvas.add_child(shutter_bottom)
	
	var t = create_tween()
	t.parallel().tween_property(shutter_top, "position:y", -362.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(shutter_bottom, "position:y", 720.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.chain().tween_callback(canvas.queue_free)
