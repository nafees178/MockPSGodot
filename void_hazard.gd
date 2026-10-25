class_name VoidHazard
extends Area2D

signal player_hit

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player or body.has_method("respawn"):
		player_hit.emit()
		
		# Sizzle / Zap death sound
		var sfx = load("res://audio/sfx_zap.ogg") as AudioStream
		if sfx:
			var asp = AudioStreamPlayer2D.new()
			asp.stream = sfx
			asp.volume_db = -2.0
			asp.pitch_scale = 0.8
			get_parent().add_child(asp)
			asp.global_position = body.global_position
			asp.play()
			asp.finished.connect(asp.queue_free)
		
		if body.has_method("respawn"):
			body.respawn()
