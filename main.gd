extends Node2D

@onready var player: Player = $Player
@onready var state_label: Label = %StateLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var gem_label: Label = %GemLabel
@onready var timer_label: Label = %TimerLabel
@onready var goal_gate: Node2D = get_node_or_null("GoalGate")
@onready var victory_panel: Control = %VictoryPanel
@onready var final_time_label: Label = %FinalTimeLabel
@onready var final_gems_label: Label = %FinalGemsLabel
@onready var final_respawns_label: Label = %FinalRespawnsLabel

const STATE_NAMES: Array[String] = [
	"IDLE",
	"RUN",
	"JUMP",
	"FALL",
	"LAND",
	"DASH",
	"PUNCH",
	"KATANA",
	"CROUCH"
]

const WEAPON_NAMES: Array[String] = [
	"Unarmed (Punch)",
	"Katana",
	"Gun"
]

var total_gems: int = 0
var collected_gems: int = 0
var elapsed_time: float = 0.0
var respawn_count: int = 0
var level_finished: bool = false

var pause_menu: PauseMenu

func _ready() -> void:
	SettingsManager.load_settings()
	if timer_label:
		timer_label.visible = SettingsManager.show_timer

	if victory_panel:
		victory_panel.visible = false
		victory_panel.modulate.a = 0.0
		_setup_victory_menu_button()

	# Setup Player signals
	if player:
		player.state_changed.connect(_on_player_state_changed)
		player.weapon_changed.connect(_on_player_weapon_changed)
		player.respawned.connect(_on_player_respawned)
		_on_player_weapon_changed(player.current_weapon)
		_on_player_state_changed(0, player.current_state)

	# Connect all Gems in the level
	var gems = get_tree().get_nodes_in_group("gems")
	total_gems = gems.size()
	for g in gems:
		if g.has_signal("collected"):
			g.collected.connect(_on_gem_collected)
	_update_gem_label()

	# Connect Goal Gate
	if goal_gate and goal_gate.has_signal("reached"):
		goal_gate.reached.connect(_on_level_completed)

	# Setup modular Pause Menu
	var pause_scene = load("res://pause_menu.tscn") as PackedScene
	if pause_scene:
		pause_menu = pause_scene.instantiate()
		add_child(pause_menu)

	# Smooth entrance transition revealing the stage
	_setup_entrance_transition()

func _setup_entrance_transition() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 120
	add_child(canvas)
	
	var shutter_top = ColorRect.new()
	shutter_top.color = Color(0.09, 0.11, 0.15, 1.0)
	shutter_top.size = Vector2(1280, 362)
	shutter_top.position = Vector2(0, 0)
	canvas.add_child(shutter_top)
	
	var shutter_bottom = ColorRect.new()
	shutter_bottom.color = Color(0.09, 0.11, 0.15, 1.0)
	shutter_bottom.size = Vector2(1280, 362)
	shutter_bottom.position = Vector2(0, 358)
	canvas.add_child(shutter_bottom)
	
	var seam_line = ColorRect.new()
	seam_line.color = Color(0.38, 0.62, 0.95, 1.0)
	seam_line.size = Vector2(1280, 2)
	seam_line.position = Vector2(0, 359)
	canvas.add_child(seam_line)
	
	var t = create_tween()
	t.parallel().tween_property(shutter_top, "position:y", -362.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(shutter_bottom, "position:y", 720.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(seam_line, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(func():
		canvas.queue_free()
	)

func _process(delta: float) -> void:
	if not level_finished and not get_tree().paused:
		elapsed_time += delta
		_update_timer_label()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and not get_tree().paused:
			get_tree().reload_current_scene()
		elif event.keycode == KEY_M and level_finished:
			get_tree().change_scene_to_file("res://main_menu.tscn")

func _setup_victory_menu_button() -> void:
	if victory_panel:
		var card_vbox = victory_panel.find_child("VBox", true, false)
		if card_vbox:
			var font = load("res://audio/kenvector_future.ttf") as Font
			var btn_menu = Button.new()
			btn_menu.text = "MAIN MENU [M]"
			if font:
				btn_menu.add_theme_font_override("font", font)
			btn_menu.add_theme_font_size_override("font_size", 12)
			
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(0.20, 0.32, 0.48, 0.95)
			sb.border_color = Color(0.42, 0.62, 0.85, 0.9)
			sb.border_width_left = 3
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 2
			sb.corner_radius_top_left = 4
			sb.corner_radius_bottom_left = 4
			sb.corner_radius_top_right = 4
			sb.corner_radius_bottom_right = 4
			sb.content_margin_left = 12
			sb.content_margin_right = 12
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
			btn_menu.add_theme_stylebox_override("normal", sb)
			
			btn_menu.pressed.connect(func():
				get_tree().change_scene_to_file("res://main_menu.tscn")
			)
			card_vbox.add_child(btn_menu)

func _update_timer_label() -> void:
	if timer_label:
		var total_secs = int(elapsed_time)
		var mins = floori(float(total_secs) / 60.0)
		var secs = total_secs % 60
		var ms = int((elapsed_time - float(total_secs)) * 100.0)
		timer_label.text = "Time: %02d:%02d.%02d" % [mins, secs, ms]

func _update_gem_label() -> void:
	if gem_label:
		gem_label.text = "Gems: %d / %d" % [collected_gems, total_gems]

func _on_gem_collected(val: int) -> void:
	collected_gems += val
	_update_gem_label()

func _on_player_respawned() -> void:
	respawn_count += 1

func _on_player_state_changed(_old_state: int, new_state: int) -> void:
	if state_label and new_state >= 0 and new_state < STATE_NAMES.size():
		state_label.text = "State: " + STATE_NAMES[new_state]

func _on_player_weapon_changed(new_weapon: int) -> void:
	if weapon_label and new_weapon >= 0 and new_weapon < WEAPON_NAMES.size():
		weapon_label.text = "Weapon: " + WEAPON_NAMES[new_weapon]

func _on_level_completed() -> void:
	if level_finished:
		return
	level_finished = true
	
	if final_time_label:
		var total_secs = int(elapsed_time)
		var mins = floori(float(total_secs) / 60.0)
		var secs = total_secs % 60
		var ms = int((elapsed_time - float(total_secs)) * 100.0)
		final_time_label.text = "Time: %02d:%02d.%02d" % [mins, secs, ms]
	
	if final_gems_label:
		final_gems_label.text = "Gems: %d / %d" % [collected_gems, total_gems]
		
	if final_respawns_label:
		final_respawns_label.text = "Respawns: %d" % respawn_count

	if victory_panel:
		victory_panel.visible = true
		var tween = create_tween()
		tween.tween_property(victory_panel, "modulate:a", 1.0, 0.4)
