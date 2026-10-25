class_name VendingMachine
extends Area2D

@onready var prompt_label: Label = $PromptLabel
@onready var message_label: Label = $MessageLabel

var is_player_nearby: bool = false
var can_interact: bool = true

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt_label:
		prompt_label.modulate.a = 0.0
	if message_label:
		message_label.modulate.a = 0.0

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		is_player_nearby = true
		if prompt_label:
			var t = create_tween()
			t.tween_property(prompt_label, "modulate:a", 1.0, 0.2)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		is_player_nearby = false
		if prompt_label:
			var t = create_tween()
			t.tween_property(prompt_label, "modulate:a", 0.0, 0.2)

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_nearby or not can_interact:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_F:
			trigger_interaction()

func trigger_interaction() -> void:
	can_interact = false
	
	# Audio cue
	var sfx = load("res://audio/sfx_laser2.ogg") as AudioStream
	if sfx:
		var asp = AudioStreamPlayer2D.new()
		asp.stream = sfx
		asp.volume_db = -8.0
		add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)
	
	if message_label:
		message_label.text = "OUT OF ORDER\nExtra Heart coming soon!"
		var t = create_tween()
		t.tween_property(message_label, "modulate:a", 1.0, 0.15)
		t.tween_property(message_label, "position:y", -50.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(1.5)
		t.tween_property(message_label, "modulate:a", 0.0, 0.3)
		t.chain().tween_callback(func():
			can_interact = true
			if message_label:
				message_label.position.y = -35.0
		)
