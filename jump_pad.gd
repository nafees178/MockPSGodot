class_name JumpPad
extends Area2D

# Bounce velocity (tunes launch height to ~8-10 tiles, effortlessly clearing high ledges)
@export var bounce_velocity: float = -540.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var bounce_cooldown: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer
	body_entered.connect(_on_body_entered)
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")

func _process(delta: float) -> void:
	bounce_cooldown = max(0.0, bounce_cooldown - delta)

func _on_body_entered(body: Node2D) -> void:
	if bounce_cooldown > 0.0:
		return
	
	if body.has_method("bounce"):
		bounce_cooldown = 0.25
		body.bounce(bounce_velocity)
		_trigger_bounce_effects()
	elif body is CharacterBody2D:
		bounce_cooldown = 0.25
		body.velocity.y = bounce_velocity
		body.position.y -= 4.0
		_trigger_bounce_effects()

func _trigger_bounce_effects() -> void:
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("bounce"):
		animated_sprite.play("bounce")
	
	# Audio cue
	var sfx = load("res://audio/sfx_shieldUp.ogg") as AudioStream
	if sfx:
		var asp = AudioStreamPlayer2D.new()
		asp.stream = sfx
		asp.pitch_scale = 1.35
		asp.volume_db = -3.0
		add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "bounce":
		animated_sprite.play("idle")
