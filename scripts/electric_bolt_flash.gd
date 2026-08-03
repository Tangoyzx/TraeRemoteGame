class_name ElectricBoltFlash
extends Node2D

var target_offset := Vector2.ZERO

func setup(start_position: Vector2, end_position: Vector2) -> void:
	global_position = start_position
	target_offset = end_position - start_position

func _ready() -> void:
	add_to_group("player_attack")
	z_index = 21
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	var normal := target_offset.normalized().orthogonal()
	for index in range(1, 5):
		var ratio := float(index) / 5.0
		points.append(target_offset * ratio + normal * randf_range(-12.0, 12.0))
	points.append(target_offset)
	draw_polyline(points, Color(1.0, 0.94, 0.20, 1.0), 4.0, true)
