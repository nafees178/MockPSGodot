extends StaticBody2D

signal destroyed

@export var max_health: int = 2
var current_health: int = 2
var is_broken: bool = false
var last_hit_time: float = -1.0

@onready var hit_area: Area2D = $HitArea
@onready var visual: Node2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hp_label: Label = $HPLabel

func _ready() -> void:
	current_health = max_health
	if hit_area:
		hit_area.area_entered.connect(_on_hit_area_entered)
	_update_label()

func take_damage(amount: int, _weapon_name: String = "") -> void:
	if is_broken:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_hit_time < 0.08:
		return # Debounce duplicate detection in same physics tick
	last_hit_time = now

	current_health -= amount
	_update_label()
	
	# Hit flash & recoil shake
	var tween = create_tween()
	visual.modulate = Color(2.5, 1.5, 1.5, 1.0)
	tween.tween_property(visual, "position:x", 5.0, 0.04)
	tween.tween_property(visual, "position:x", -5.0, 0.04)
	tween.tween_property(visual, "position:x", 0.0, 0.04)
	tween.tween_property(visual, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

	if current_health <= 0:
		break_crate()

func break_crate() -> void:
	is_broken = true
	destroyed.emit()
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if hit_area:
		hit_area.set_deferred("monitoring", false)
		hit_area.set_deferred("monitorable", false)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(visual, "modulate:a", 0.0, 0.15)
	if hp_label:
		tween.tween_property(hp_label, "modulate:a", 0.0, 0.1)
	tween.chain().tween_callback(queue_free)

func _on_hit_area_entered(area: Area2D) -> void:
	if is_broken:
		return
	if area.name == "AttackArea":
		var dmg = 1
		var player = area.get_parent()
		if player and player is Player and player.current_weapon == Player.WeaponType.KATANA:
			dmg = 2
		take_damage(dmg)

func _update_label() -> void:
	if hp_label:
		hp_label.text = "HP: %d" % max(0, current_health)
