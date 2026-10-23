extends Area2D

# Small saw speed (faster than the Big Saw's 200.0)
@export var speed: float = 300.0

# Direction: -1 moves LEFT (towards player), 1 moves RIGHT
@export var direction: float = -1.0

# Faster rotation speed because it's smaller
@export var rotation_speed: float = 20.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

func _ready() -> void:
	# Automatically handle deleting when off-screen and collisions with player
	notifier.screen_exited.connect(_on_screen_exited)
	body_entered.connect(_on_body_entered)
	
	if animated_sprite.sprite_frames:
		animated_sprite.play("default")

func _process(delta: float) -> void:
	# Move horizontally across the screen faster
	position.x += speed * direction * delta
	
	# Spin the saw blade visually
	animated_sprite.rotation += rotation_speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Check if it hits the player
	if body.is_in_group("player") or body.has_method("take_damage") or body.has_method("die"):
		if body.has_method("take_damage"):
			body.take_damage()
		elif body.has_method("die"):
			body.die()

func _on_screen_exited() -> void:
	# Automatically free memory once it goes off-screen
	queue_free()
