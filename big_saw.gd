class_name BigSaw
extends Area2D

# Controlled speed for big saw
@export var speed: float = 75.0

# Expanded range for big saw: 9 units (144 pixels)
@export var patrol_units: float = 9.0

@export var rotation_speed: float = 10.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var origin_x: float = 0.0
var move_direction: float = -1.0 # Moves left initially
var max_travel_dist: float = 144.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer
	body_entered.connect(_on_body_entered)
	
	origin_x = position.x
	max_travel_dist = patrol_units * 16.0 # 16px per unit
	
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("default"):
			animated_sprite.play("default")

func _process(delta: float) -> void:
	if animated_sprite:
		animated_sprite.rotation += rotation_speed * delta
	
	position.x += speed * move_direction * delta
	
	if move_direction < 0.0 and position.x <= origin_x - max_travel_dist:
		position.x = origin_x - max_travel_dist
		move_direction = 1.0 # Reverse to move right
	elif move_direction > 0.0 and position.x >= origin_x:
		position.x = origin_x
		move_direction = -1.0 # Reverse to move left

func _on_body_entered(body: Node2D) -> void:
	if body is Player or body.has_method("respawn"):
		body.respawn()
	elif body.has_method("die"):
		body.die()
	elif body.has_method("take_damage"):
		body.take_damage()
