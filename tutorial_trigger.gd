extends Area2D

# Allows custom text per trigger directly from the Inspector
@export_multiline var prompt_text: String = "Press Space to jump"

# Optional: action name to auto-dismiss when the player performs it
@export var dismiss_on_action: String = ""

# If true, only show the tutorial once (won't re-trigger after dismissal)
@export var show_once: bool = true

# Assign your PromptUI node in the Inspector
@export var prompt_ui: CanvasLayer

var _player_inside: bool = false
var _was_shown: bool = false
var _dismissed: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(_delta: float) -> void:
	if _player_inside and not _dismissed and dismiss_on_action != "":
		var action_triggered = Input.is_action_just_pressed(dismiss_on_action)
		if not action_triggered and (dismiss_on_action == "move_right" or dismiss_on_action == "move_left"):
			if abs(Input.get_axis("move_left", "move_right")) > 0.35:
				action_triggered = true
		
		if action_triggered:
			_dismissed = true
			if prompt_ui and prompt_ui.has_method("hide_message"):
				prompt_ui.hide_message()

func _is_player(body: Node2D) -> bool:
	return body.is_in_group("player") or body.is_in_group("Player") or body is CharacterBody2D

func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		if show_once and _dismissed:
			return
		_player_inside = true
		_was_shown = true
		if prompt_ui and prompt_ui.has_method("show_message"):
			prompt_ui.show_message(prompt_text)

func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		_player_inside = false
		if _was_shown:
			if prompt_ui and prompt_ui.has_method("hide_message"):
				prompt_ui.hide_message()
