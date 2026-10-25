class_name TreasureChest
extends Area2D

signal chest_opened

@export var give_katana: bool = true
var is_opened: bool = false
var is_player_nearby: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt_label: Label = $PromptLabel
@onready var banner_layer: CanvasLayer = get_node_or_null("BannerLayer")

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt_label:
		prompt_label.modulate.a = 0.0

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		is_player_nearby = true
		if not is_opened:
			if prompt_label:
				var t = create_tween()
				t.tween_property(prompt_label, "modulate:a", 1.0, 0.2)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		is_player_nearby = false
		if prompt_label:
			var t = create_tween()
			t.tween_property(prompt_label, "modulate:a", 0.0, 0.2)

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_nearby or is_opened:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_F:
			open_chest()

func open_chest() -> void:
	if is_opened:
		return
	is_opened = true
	chest_opened.emit()
	
	if prompt_label:
		prompt_label.modulate.a = 0.0
	
	# Open chest sprite frame (Tile (13, 9) in Dungeon Tile Set: Rect2(208, 144, 16, 16))
	if sprite:
		sprite.region_rect = Rect2(208, 144, 16, 16)
		# Small pop bounce
		var st = create_tween()
		st.tween_property(sprite, "scale", Vector2(1.25, 1.25), 0.1)
		st.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Spawn floating katana item reward
	_spawn_katana_drop()

func _spawn_katana_drop() -> void:
	# Audio cue
	var sfx = load("res://audio/sfx_shieldUp.ogg") as AudioStream
	if sfx:
		var asp = AudioStreamPlayer2D.new()
		asp.stream = sfx
		asp.volume_db = -4.0
		add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)
	
	# Floating katana icon
	var katana_node = Node2D.new()
	katana_node.position = Vector2(0, -8)
	add_child(katana_node)
	
	# Glowing aura
	var aura = Polygon2D.new()
	aura.color = Color(1.0, 0.85, 0.2, 0.5)
	aura.polygon = PackedVector2Array([Vector2(-12, -4), Vector2(0, -16), Vector2(12, -4), Vector2(0, 8)])
	katana_node.add_child(aura)
	
	# Katana blade graphic using polygon
	var blade = Polygon2D.new()
	blade.color = Color(0.95, 0.98, 1.0, 1.0)
	blade.polygon = PackedVector2Array([Vector2(-2, 4), Vector2(-1, -18), Vector2(1, -16), Vector2(2, 4)])
	blade.rotation_degrees = 45.0
	katana_node.add_child(blade)
	
	# Handle
	var handle = Polygon2D.new()
	handle.color = Color(0.8, 0.2, 0.2, 1.0)
	handle.polygon = PackedVector2Array([Vector2(-2, 4), Vector2(2, 4), Vector2(1, 10), Vector2(-1, 10)])
	handle.rotation_degrees = 45.0
	katana_node.add_child(handle)
	
	# Float upward animation
	var kt = create_tween()
	kt.parallel().tween_property(katana_node, "position:y", -32.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	kt.parallel().tween_property(katana_node, "scale", Vector2(1.3, 1.3), 0.4)
	kt.chain().tween_property(katana_node, "modulate:a", 0.0, 0.3)
	kt.chain().tween_callback(katana_node.queue_free)
	
	# Unlock player katana!
	var players = get_tree().get_nodes_in_group("player")
	var p: Player = null
	if players.size() > 0:
		p = players[0] as Player
	else:
		# Search parent tree
		var node = get_parent()
		while node != null and p == null:
			p = node.find_child("Player", true, false) as Player
			node = node.get_parent()
	
	if p:
		if p.has_method("unlock_katana"):
			p.unlock_katana()
		else:
			p.current_weapon = Player.WeaponType.KATANA
	
	# Show stylish banner notification
	_show_katana_banner()

func _show_katana_banner() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(container)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 60)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(460, 40)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.20, 0.95)
	sb.border_color = Color(1.0, 0.8, 0.2, 0.9)
	sb.border_width_left = 3
	sb.border_width_top = 2
	sb.border_width_right = 3
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", sb)
	container.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	var font = load("res://audio/kenvector_future.ttf") as Font
	
	var title = Label.new()
	title.text = "KATANA ACQUIRED!"
	if font:
		title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = "Press Attack [J / Click] to slash! Tab to switch."
	if font:
		desc.add_theme_font_override("font", font)
	desc.add_theme_font_size_override("font_size", 9)
	desc.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.9))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)
	
	# Entrance & Exit animation
	panel.scale = Vector2(0.5, 0.5)
	panel.pivot_offset = Vector2(180, 30)
	panel.modulate.a = 0.0
	
	var bt = create_tween()
	bt.parallel().tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bt.parallel().tween_property(panel, "modulate:a", 1.0, 0.25)
	bt.tween_interval(2.5)
	bt.parallel().tween_property(panel, "modulate:a", 0.0, 0.35)
	bt.parallel().tween_property(panel, "position:y", 20.0, 0.35)
	bt.chain().tween_callback(canvas.queue_free)
