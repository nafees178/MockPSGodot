extends CharacterBody2D

@export var speed: float = 40.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast: RayCast2D = $RayCast2D

var direction: float = -1.0

func _physics_process(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Turn around if hitting a wall or reaching a ledge
	if is_on_wall() or (is_on_floor() and not ray_cast.is_colliding()):
		direction *= -1.0
		ray_cast.position.x = 8.0 * direction # Shift RayCast to match new direction

	velocity.x = direction * speed
	animated_sprite.flip_h = (direction > 0)
	animated_sprite.play("walk")

	move_and_slide()
