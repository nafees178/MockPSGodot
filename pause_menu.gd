class_name PauseMenu
extends CanvasLayer

@onready var btn_resume: Button = %BtnResume
@onready var btn_restart: Button = %BtnRestart
@onready var btn_menu: Button = %BtnMenu

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var font = load("res://audio/kenvector_future.ttf") as Font
	_style_button(btn_resume, font, true)
	_style_button(btn_restart, font, false)
	_style_button(btn_menu, font, false)
	
	btn_resume.pressed.connect(resume)
	btn_restart.pressed.connect(restart)
	btn_menu.pressed.connect(go_to_menu)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if visible:
				resume()
			else:
				pause()
		elif visible:
			if event.keycode == KEY_M:
				go_to_menu()
			elif event.keycode == KEY_R:
				restart()

func pause() -> void:
	visible = true
	get_tree().paused = true

func resume() -> void:
	visible = false
	get_tree().paused = false

func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _style_button(btn: Button, font: Font, is_primary: bool) -> void:
	if font:
		btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 12)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.32, 0.48, 0.95) if is_primary else Color(0.16, 0.19, 0.25, 0.9)
	sb.border_color = Color(0.42, 0.62, 0.85, 0.9) if is_primary else Color(0.28, 0.34, 0.45, 0.8)
	sb.border_width_left = 3 if is_primary else 2
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	btn.add_theme_stylebox_override("normal", sb)
	
	var sb_hover = StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.26, 0.42, 0.62, 1.0) if is_primary else Color(0.22, 0.26, 0.35, 1.0)
	sb_hover.border_color = Color(0.60, 0.78, 1.0, 1.0) if is_primary else Color(0.42, 0.52, 0.66, 1.0)
	sb_hover.border_width_left = 4 if is_primary else 3
	sb_hover.border_width_top = 1
	sb_hover.border_width_right = 1
	sb_hover.border_width_bottom = 2
	sb_hover.corner_radius_top_left = 4
	sb_hover.corner_radius_bottom_left = 4
	sb_hover.corner_radius_top_right = 4
	sb_hover.corner_radius_bottom_right = 4
	sb_hover.content_margin_left = 16
	sb_hover.content_margin_right = 14
	sb_hover.content_margin_top = 9
	sb_hover.content_margin_bottom = 9
	btn.add_theme_stylebox_override("hover", sb_hover)
