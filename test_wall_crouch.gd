extends SceneTree

func _init() -> void:
	print("=== STARTING TEST ===")
	var root = Node2D.new()
	get_root().add_child(root)

	# Static floor
	var floor_body = StaticBody2D.new()
	var floor_shape = CollisionShape2D.new()
	var floor_box = RectangleShape2D.new()
	floor_box.size = Vector2(200, 20)
	floor_shape.shape = floor_box
	floor_body.position = Vector2(0, 10)
	floor_body.collision_layer = 1
	floor_body.collision_mask = 1
	root.add_child(floor_body)

	# Static vertical wall
	var wall_body = StaticBody2D.new()
	var wall_shape = CollisionShape2D.new()
	var wall_box = RectangleShape2D.new()
	wall_box.size = Vector2(20, 100)
	wall_shape.shape = wall_box
	wall_body.position = Vector2(20, -50)
	wall_body.collision_layer = 1
	wall_body.collision_mask = 1
	root.add_child(wall_body)

	# Load Player
	var player_scene = load("res://player.tscn")
	var player: Player = player_scene.instantiate()
	player.position = Vector2(0, 0)
	player.scale = Vector2(0.8, 0.8)
	root.add_child(player)

	# Run a few physics frames
	for i in range(10):
		player.velocity = Vector2(100, 0)
		player.move_and_slide()

	print("Player pos: ", player.global_position)
	print("Player is_on_wall: ", player.is_on_wall())
	var under_ceil = player.is_under_ceiling()
	print("Player is_under_ceiling against wall: ", under_ceil)

	if under_ceil:
		print("FAIL: Wall was detected as a ceiling!")
		quit(1)
		return

	# Simulate normal movement processing against wall
	# wants_crouch is false
	var wants_crouch = false
	var crouching = (wants_crouch or (player.current_state == Player.State.CROUCH and under_ceil)) and player.is_on_floor()
	print("crouching flag: ", crouching)

	if crouching:
		print("FAIL: Player is marked as crouching against wall!")
		quit(1)
		return

	# Now add an actual low ceiling above player
	var ceil_body = StaticBody2D.new()
	var ceil_shape = CollisionShape2D.new()
	var ceil_box = RectangleShape2D.new()
	ceil_box.size = Vector2(50, 10)
	ceil_shape.shape = ceil_box
	ceil_body.position = Vector2(player.position.x, -20)
	ceil_body.collision_layer = 1
	ceil_body.collision_mask = 1
	root.add_child(ceil_body)

	var under_actual_ceil = player.is_under_ceiling()
	print("Player is_under_ceiling with real ceiling: ", under_actual_ceil)

	if not under_actual_ceil:
		print("FAIL: Real ceiling was NOT detected!")
		quit(1)
		return

	print("=== ALL TESTS PASSED SUCCESSFULLY! ===")
	quit(0)
