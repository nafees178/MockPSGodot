class_name SawSpawner
extends Node2D

@export var spawn_interval: float = 3.2
@export var saw_speed: float = 220.0
@export var saw_direction: float = -1.0
@export var initial_delay: float = 1.0
@export var is_big_saw: bool = false
@export var max_active_saws: int = 4

var saw_scene: PackedScene = preload("res://small_saw.tscn")
var timer: float = 0.0
var spawned_saws: Array[Node2D] = []

func _ready() -> void:
	if is_big_saw:
		saw_scene = preload("res://big_saw.tscn")
	timer = spawn_interval - initial_delay

func _process(delta: float) -> void:
	timer += delta
	if timer >= spawn_interval:
		timer = 0.0
		_spawn_saw()

func _spawn_saw() -> void:
	# Clean up freed saws
	spawned_saws = spawned_saws.filter(func(s): return is_instance_valid(s))
	if spawned_saws.size() >= max_active_saws:
		return
	
	if saw_scene:
		var saw = saw_scene.instantiate() as Area2D
		saw.global_position = global_position
		if "speed" in saw:
			saw.speed = saw_speed
		if "direction" in saw:
			saw.direction = saw_direction
		
		# Add to level tree so saw moves independently
		get_parent().add_child(saw)
		spawned_saws.append(saw)
		
		# Brief launch puff or flash
		var launch_flash = Polygon2D.new()
		launch_flash.polygon = PackedVector2Array([
			Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
		])
		launch_flash.color = Color(1.0, 0.6, 0.2, 0.8)
		add_child(launch_flash)
		var ft = create_tween()
		ft.parallel().tween_property(launch_flash, "scale", Vector2(2.0, 2.0), 0.15)
		ft.parallel().tween_property(launch_flash, "modulate:a", 0.0, 0.15)
		ft.chain().tween_callback(launch_flash.queue_free)
