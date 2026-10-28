extends CharacterBody2D

signal defeated

@export var max_health: int = 5
var health: int = 5
var is_dead: bool = false
var last_hit_time: float = -1.0

@onready var visual: Node2D = $Visual
@onready var hit_area: Area2D = $HitArea
@onready var hp_bar: ProgressBar = $HPBar

func _ready() -> void:
	health = max_health
	if hit_area:
		hit_area.area_entered.connect(_on_hit_area_entered)
	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = health

func take_damage(amount: int) -> void:
	if is_dead:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_hit_time < 0.08:
		return
	last_hit_time = now

	health -= amount
	if hp_bar:
		hp_bar.value = health
	
	# Dummy Combat Juice: Hit-stop, camera shake, sparks, floating damage number
	JuiceManager.hit_stop(0.04)
	JuiceManager.add_trauma(0.2)
	JuiceManager.spawn_impact_sparks(global_position + Vector2(0, -10), Vector2.UP, Color(1.0, 0.85, 0.3))
	JuiceManager.spawn_damage_number(global_position + Vector2(0, -16), amount, amount >= 2)
	
	# Hit flash & recoil
	var tween = create_tween()
	visual.modulate = Color(3.0, 2.0, 2.0, 1.0)
	tween.tween_property(visual, "position:x", 8.0, 0.05)
	tween.tween_property(visual, "position:x", -4.0, 0.05)
	tween.tween_property(visual, "position:x", 0.0, 0.05)
	tween.tween_property(visual, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	defeated.emit()
	
	# Death Juice
	JuiceManager.hit_stop(0.06)
	JuiceManager.add_trauma(0.35)
	JuiceManager.spawn_death_burst(global_position + Vector2(0, -10), Color(1.0, 0.5, 0.2))
	
	if hit_area:
		hit_area.set_deferred("monitoring", false)
		hit_area.set_deferred("monitorable", false)
	$CollisionShape2D.set_deferred("disabled", true)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector2(1.5, 0.2), 0.2)
	tween.tween_property(visual, "modulate:a", 0.0, 0.2)
	tween.tween_property(hp_bar, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)

func _on_hit_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.name == "AttackArea":
		var dmg = 1
		var player = area.get_parent()
		if player and player is Player and player.current_weapon == Player.WeaponType.KATANA:
			dmg = 2
		take_damage(dmg)
