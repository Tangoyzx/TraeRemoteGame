class_name ThunderBall
extends Node2D

const FADE_IN_SECONDS := 1.0
const MAX_LIFETIME := 30.0
const COLLISION_RADIUS := 18.0

var controller
var enemies_layer: Node2D
var _age := 0.0
var _base_level := 0

func setup(skill_controller, enemy_container: Node2D, spawn_position: Vector2, base_level: int) -> void:
	controller = skill_controller
	enemies_layer = enemy_container
	global_position = spawn_position
	_base_level = base_level

func _ready() -> void:
	add_to_group("player_attack")
	z_index = 8
	modulate.a = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	modulate.a = clampf(_age / FADE_IN_SECONDS, 0.0, 1.0)
	if _age >= MAX_LIFETIME:
		queue_free()
		return
	if _age < FADE_IN_SECONDS or enemies_layer == null:
		return
	for enemy in enemies_layer.get_children():
		if not _is_alive_enemy(enemy):
			continue
		var enemy_radius: float = float(enemy.get("radius"))
		var collision_distance := COLLISION_RADIUS + enemy_radius
		if global_position.distance_squared_to(enemy.global_position) <= collision_distance * collision_distance:
			if controller != null and is_instance_valid(controller):
				controller.explode_thunder_ball(global_position, _base_level)
			queue_free()
			return

func _is_alive_enemy(enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and enemy.is_in_group("enemy") and float(enemy.get("hp")) > 0.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, COLLISION_RADIUS, Color(1.0, 0.88, 0.10, 0.65))
	draw_arc(Vector2.ZERO, COLLISION_RADIUS, 0.0, TAU, 32, Color(1.0, 1.0, 0.55, 1.0), 3.0)
	draw_arc(Vector2.ZERO, COLLISION_RADIUS * 0.55, 0.0, TAU, 20, Color.WHITE, 2.0)
