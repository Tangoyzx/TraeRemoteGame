class_name ElectricLaserBeam
extends Node2D

var beam_length := 600.0
var beam_width := 10.0
var direction := Vector2.RIGHT

func setup(start_position: Vector2, aim_direction: Vector2, length: float, width: float) -> void:
	global_position = start_position
	direction = aim_direction.normalized()
	beam_length = length
	beam_width = width

func _ready() -> void:
	add_to_group("player_attack")
	z_index = 20
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)

func _draw() -> void:
	var end_point := direction * beam_length
	draw_line(Vector2.ZERO, end_point, Color(1.0, 0.95, 0.15, 0.35), beam_width + 6.0, true)
	draw_line(Vector2.ZERO, end_point, Color(1.0, 0.96, 0.25, 1.0), beam_width, true)
