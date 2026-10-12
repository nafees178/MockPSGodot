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

func _ready() -> void:
	if victory_panel:
		victory_panel.visible = false
		victory_panel.modulate.a = 0.0

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

func _process(delta: float) -> void:
	if not level_finished:
		elapsed_time += delta
		_update_timer_label()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()

func _update_timer_label() -> void:
	if timer_label:
		var mins = int(elapsed_time) / 60
		var secs = int(elapsed_time) % 60
		var ms = int((elapsed_time - int(elapsed_time)) * 100)
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
		var mins = int(elapsed_time) / 60
		var secs = int(elapsed_time) % 60
		var ms = int((elapsed_time - int(elapsed_time)) * 100)
		final_time_label.text = "Time: %02d:%02d.%02d" % [mins, secs, ms]
	
	if final_gems_label:
		final_gems_label.text = "Gems: %d / %d" % [collected_gems, total_gems]
		
	if final_respawns_label:
		final_respawns_label.text = "Respawns: %d" % respawn_count

	if victory_panel:
		victory_panel.visible = true
		var tween = create_tween()
		tween.tween_property(victory_panel, "modulate:a", 1.0, 0.4)
