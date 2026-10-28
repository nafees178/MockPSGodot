extends Area2D

# Allows custom text per obstacle directly from the Inspector
@export_multiline var prompt_text: String = "Press Space to jump"

# Assign your PromptUI node in the Inspector
@export var prompt_ui: CanvasLayer

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if prompt_ui and prompt_ui.has_method("show_message"):
			prompt_ui.show_message(prompt_text)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if prompt_ui and prompt_ui.has_method("hide_message"):
			prompt_ui.hide_message()
