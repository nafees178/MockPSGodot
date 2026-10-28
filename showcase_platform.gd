class_name ShowcasePlatform
extends Control

enum LevelTheme {
	GRASSLAND = 0,
	AUTUMN = 1,
	WINTER = 2
}

var current_level_theme: int = LevelTheme.GRASSLAND

var terrain_textures: Dictionary = {}
var props_textures: Dictionary = {}

const TERRAIN_PATHS: Dictionary = {
	LevelTheme.GRASSLAND: "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/1 - Grassland/Terrain (16 x 16).png",
	LevelTheme.AUTUMN: "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/2 - Autumn Forest/Terrain (16 x 16).png",
	LevelTheme.WINTER: "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/4 - Winter World/Terrain (16 x 16).png"
}

const PROPS_PATHS: Dictionary = {
	LevelTheme.GRASSLAND: "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/1 - Grassland/Grassland_entities (16 x 16).png",
	LevelTheme.AUTUMN: "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/2 - Autumn Forest/Autumn_entities (16 x 16).png",
	LevelTheme.WINTER: "res://TileMap/Seasonal Tilesets/Seasonal Tilesets/4 - Winter World/Winter_entities (16 x 16).png"
}

# Platform geometry
# Shoe resting line is y = 380.0
# Character center is x = 440.0
const SURFACE_Y: float = 380.0
const TILE_PX: float = 16.0
const SCALE_FACTOR: float = 2.0
const TILE_DRAW_SIZE: float = 32.0 # 16 * 2
const TILE_COUNT_X: int = 18 # 18 * 32 = 576px wide
const START_X: float = 152.0 # 440 - (576 / 2) = 152.0
const ROWS_COUNT: int = 3 # 3 rows: surface grass, middle dirt, bottom dirt

var anim_scale: float = 1.0
var anim_offset_y: float = 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_load_assets()

func _load_assets() -> void:
	for t in TERRAIN_PATHS.keys():
		var path = TERRAIN_PATHS[t]
		if ResourceLoader.exists(path):
			terrain_textures[t] = load(path)
	
	for t in PROPS_PATHS.keys():
		var path = PROPS_PATHS[t]
		if ResourceLoader.exists(path):
			props_textures[t] = load(path)

func set_level_theme(new_theme: int) -> void:
	if new_theme == current_level_theme and terrain_textures.has(new_theme):
		return
	current_level_theme = new_theme
	
	# Small juicy bounce on platform when changing themes
	var t = create_tween()
	t.tween_property(self, "anim_offset_y", 4.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "anim_offset_y", 0.0, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	queue_redraw()

func _draw() -> void:
	var terrain_tex: Texture2D = terrain_textures.get(current_level_theme)
	if terrain_tex == null:
		return
	
	var base_y = SURFACE_Y + anim_offset_y
	
	# 1. Soft grounded shadow directly underneath the character's feet
	var shadow_center = Vector2(440.0, base_y + 1.0)
	var shadow_rect = Rect2(shadow_center.x - 38.0, shadow_center.y - 3.0, 76.0, 6.0)
	draw_rect(shadow_rect, Color(0.04, 0.06, 0.10, 0.55), true)
	var inner_shadow = Rect2(shadow_center.x - 24.0, shadow_center.y - 2.0, 48.0, 4.0)
	draw_rect(inner_shadow, Color(0.02, 0.03, 0.06, 0.75), true)
	
	# 2. Draw 3-row pixel art terrain platform using level's Terrain (16 x 16).png
	for col in range(TILE_COUNT_X):
		var draw_x = START_X + float(col) * TILE_DRAW_SIZE
		
		var tile_type_x: float = 64.0 # default center
		if col == 0:
			tile_type_x = 48.0 # left cap
		elif col == TILE_COUNT_X - 1:
			tile_type_x = 80.0 # right cap
		
		# Row 0: Top grass / snow / autumn turf
		var src_rect_top = Rect2(tile_type_x, 16.0, 16.0, 16.0)
		var dest_rect_top = Rect2(draw_x, base_y, TILE_DRAW_SIZE, TILE_DRAW_SIZE)
		draw_texture_rect_region(terrain_tex, dest_rect_top, src_rect_top)
		
		# Row 1: Mid dirt fill
		var src_rect_mid = Rect2(tile_type_x, 32.0, 16.0, 16.0)
		var dest_rect_mid = Rect2(draw_x, base_y + TILE_DRAW_SIZE, TILE_DRAW_SIZE, TILE_DRAW_SIZE)
		draw_texture_rect_region(terrain_tex, dest_rect_mid, src_rect_mid)
		
		# Row 2: Bottom dirt edge
		var src_rect_bot = Rect2(tile_type_x, 48.0, 16.0, 16.0)
		var dest_rect_bot = Rect2(draw_x, base_y + TILE_DRAW_SIZE * 2.0, TILE_DRAW_SIZE, TILE_DRAW_SIZE)
		draw_texture_rect_region(terrain_tex, dest_rect_bot, src_rect_bot)
	
	# 3. Floating under-platform shadow for depth
	var bot_y = base_y + TILE_DRAW_SIZE * 3.0
	draw_rect(Rect2(START_X + 8.0, bot_y, TILE_COUNT_X * TILE_DRAW_SIZE - 16.0, 4.0), Color(0.04, 0.05, 0.09, 0.35))
	
	# 4. Level-specific decorative props on the platform
	var props_tex: Texture2D = props_textures.get(current_level_theme)
	if props_tex != null:
		_draw_theme_props(props_tex, base_y)

func _draw_theme_props(props_tex: Texture2D, base_y: float) -> void:
	match current_level_theme:
		LevelTheme.GRASSLAND:
			var src1 = Rect2(16.0, 16.0, 16.0, 16.0)
			var dest1 = Rect2(200.0, base_y - 26.0, 28.0, 28.0)
			draw_texture_rect_region(props_tex, dest1, src1)
			
			var src2 = Rect2(32.0, 16.0, 16.0, 16.0)
			var dest2 = Rect2(650.0, base_y - 26.0, 28.0, 28.0)
			draw_texture_rect_region(props_tex, dest2, src2)
			
		LevelTheme.AUTUMN:
			var src1 = Rect2(16.0, 16.0, 16.0, 16.0)
			var dest1 = Rect2(205.0, base_y - 26.0, 28.0, 28.0)
			draw_texture_rect_region(props_tex, dest1, src1)
			
			var src2 = Rect2(48.0, 16.0, 16.0, 16.0)
			var dest2 = Rect2(645.0, base_y - 26.0, 28.0, 28.0)
			draw_texture_rect_region(props_tex, dest2, src2)
			
		LevelTheme.WINTER:
			var src1 = Rect2(16.0, 16.0, 16.0, 16.0)
			var dest1 = Rect2(200.0, base_y - 26.0, 28.0, 28.0)
			draw_texture_rect_region(props_tex, dest1, src1)
			
			var src2 = Rect2(32.0, 16.0, 16.0, 16.0)
			var dest2 = Rect2(650.0, base_y - 26.0, 28.0, 28.0)
			draw_texture_rect_region(props_tex, dest2, src2)
