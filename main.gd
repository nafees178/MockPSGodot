extends Node2D

@onready var player: Player = $Player
@onready var state_label: Label = %StateLabel
@onready var weapon_label: Label = %WeaponLabel

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

func _ready() -> void:
	if player:
		if state_label:
			player.state_changed.connect(_on_player_state_changed)
		if weapon_label:
			player.weapon_changed.connect(_on_player_weapon_changed)
			_on_player_weapon_changed(player.current_weapon)

func _on_player_state_changed(_old_state: int, new_state: int) -> void:
	if state_label and new_state >= 0 and new_state < STATE_NAMES.size():
		state_label.text = "State: " + STATE_NAMES[new_state]

func _on_player_weapon_changed(new_weapon: int) -> void:
	if weapon_label and new_weapon >= 0 and new_weapon < WEAPON_NAMES.size():
		weapon_label.text = "Weapon: " + WEAPON_NAMES[new_weapon]
