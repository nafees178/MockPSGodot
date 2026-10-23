extends Area2D

@export var bounce_velocity: float = -600.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	animated_sprite.play("idle")

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		body.velocity.y = bounce_velocity
		animated_sprite.play("bounce")

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "bounce":
		animated_sprite.play("idle")
