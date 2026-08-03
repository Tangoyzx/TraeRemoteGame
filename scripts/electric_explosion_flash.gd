class_name ElectricExplosionFlash
extends Node2D

var radius := 100.0

func setup(center: Vector2, effect_radius: float) -> void:
	global_position = center
	radius = effect_radius

func _ready() -> void:
	add_to_group("player_attack")
	z_index = 15
	scale = Vector2(0.25, 0.25)
	queue_redraw()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.35)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.90, 0.15, 0.18))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.95, 0.25, 0.95), 4.0)
