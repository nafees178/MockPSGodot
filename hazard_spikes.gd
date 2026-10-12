extends Area2D

signal player_hit

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_hit.emit()
		if body.has_method("respawn"):
			body.respawn()
