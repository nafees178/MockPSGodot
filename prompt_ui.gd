extends CanvasLayer

@onready var label: Label = $PanelContainer/Label
@onready var panel: PanelContainer = $PanelContainer

var _tween: Tween = null

func _ready() -> void:
	visible = false
	if panel:
		panel.modulate.a = 0.0
		# Style the panel
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.08, 0.14, 0.92)
		sb.border_color = Color(0.3, 0.75, 1.0, 0.6)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		sb.content_margin_left = 24
		sb.content_margin_right = 24
		sb.content_margin_top = 14
		sb.content_margin_bottom = 14
		sb.shadow_color = Color(0.0, 0.5, 1.0, 0.15)
		sb.shadow_size = 8
		panel.add_theme_stylebox_override("panel", sb)
		# Position panel at bottom center
		panel.anchors_preset = 7  # Bottom center
		panel.anchor_left = 0.5
		panel.anchor_top = 1.0
		panel.anchor_right = 0.5
		panel.anchor_bottom = 1.0
		panel.offset_left = -190
		panel.offset_top = -108
		panel.offset_right = 190
		panel.offset_bottom = -40
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	if label:
		var font = load("res://audio/kenvector_future.ttf") as Font
		if font:
			label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 1.0))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func show_message(text: String) -> void:
	if label:
		label.text = text
	visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(panel, "offset_top", -100.0, 0.3).from(-70.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_message() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(panel, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func(): visible = false)
