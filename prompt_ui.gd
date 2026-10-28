extends CanvasLayer

@onready var label: Label = $PanelContainer/Label

func _ready() -> void:
	hide() # Keep hidden by default

func show_message(text: String) -> void:
	label.text = text
	show()

func hide_message() -> void:
	hide()
