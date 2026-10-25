class_name WalkingEnemy
extends CharacterBody2D

signal enemy_defeated

@export var speed: float = 40.0
@export var max_health: int = 1

var health: int = 1
var is_dead: bool = false
var direction: float = -1.0
var turn_cooldown: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast: RayCast2D = $RayCast2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox")
@onready var hitbox: Area2D = get_node_or_null("Hitbox")

var wall_ray: RayCast2D = null

func _ready() -> void:
	health = max_health
	
	# Horizontal wall detection raycast for instant wall turns
	wall_ray = RayCast2D.new()
	wall_ray.target_position = Vector2(-10, 0)
	wall_ray.collision_mask = 1
	add_child(wall_ray)
	
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	
	if animated_sprite:
		animated_sprite.play("walk")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	turn_cooldown = max(0.0, turn_cooldown - delta)
	
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Turn around if hitting a wall or reaching a ledge
	var wall_hit = is_on_wall() or (wall_ray and wall_ray.is_colliding())
	var ledge_hit = is_on_floor() and ray_cast and not ray_cast.is_colliding()
	
	if (wall_hit or ledge_hit) and turn_cooldown <= 0.0:
		direction *= -1.0
		turn_cooldown = 0.2
		if ray_cast:
			ray_cast.position.x = 8.0 * direction
		if wall_ray:
			wall_ray.target_position.x = 10.0 * direction
	
	velocity.x = direction * speed
	
	if animated_sprite:
		animated_sprite.flip_h = (direction > 0)
		if is_on_floor() and animated_sprite.animation != "walk":
			animated_sprite.play("walk")
	
	move_and_slide()

# --- Hitbox: Damages player on contact ---
func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead:
		return
	if body is Player or body.has_method("respawn"):
		# If the player is actively attacking (punch or katana), enemy takes damage instead!
		if body is Player and (body.current_state == Player.State.PUNCH or body.current_state == Player.State.KATANA):
			var dmg = 2 if body.current_weapon == Player.WeaponType.KATANA else 1
			take_damage(dmg)
			return
		body.respawn()

# --- Hurtbox: Detects player attacks ---
func _on_hurtbox_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	var p = area.get_parent() as Player
	if p and (p.current_state == Player.State.PUNCH or p.current_state == Player.State.KATANA):
		var dmg = 2 if p.current_weapon == Player.WeaponType.KATANA else 1
		take_damage(dmg)

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	health -= amount
	if health <= 0:
		die()
	else:
		_play_hit_flash()

func _play_hit_flash() -> void:
	if animated_sprite:
		var ft = create_tween()
		ft.tween_property(animated_sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.06)
		ft.tween_property(animated_sprite, "modulate", Color.WHITE, 0.06)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	enemy_defeated.emit()
	
	# Immediately deactivate hitbox so it cannot harm the player
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
	
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
		for child in hurtbox.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Audio cue
	var sfx = load("res://audio/sfx_zap.ogg") as AudioStream
	if sfx:
		var asp = AudioStreamPlayer2D.new()
		asp.stream = sfx
		asp.volume_db = -2.0
		asp.pitch_scale = 1.15
		add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)
	
	# Play defeat animation
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("defeat"):
		animated_sprite.play("defeat")
	
	# Death pop & fade
	var dt = create_tween()
	dt.parallel().tween_property(self, "position:y", position.y - 10.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dt.parallel().tween_property(self, "scale", Vector2(1.25, 0.75), 0.15)
	dt.parallel().tween_property(self, "modulate", Color(1.0, 0.25, 0.25, 0.8), 0.15)
	dt.chain().tween_property(self, "position:y", position.y + 12.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	dt.parallel().tween_property(self, "modulate:a", 0.0, 0.22)
	dt.chain().tween_callback(queue_free)
