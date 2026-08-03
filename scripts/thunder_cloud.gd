class_name ThunderCloud
extends Node2D

const MOVE_SPEED := 400.0
const FOLLOW_HEIGHT := 100.0
const STRIKE_DAMAGE := 50.0
const FOLLOW_EPSILON := 8.0

var controller
var player
var target
var _strike_timer := 0.0
var _lifetime_remaining := -1.0

func setup(skill_controller, owner_player, spawn_position: Vector2, lifetime: float = -1.0) -> void:
	controller = skill_controller
	player = owner_player
	global_position = spawn_position
	_lifetime_remaining = lifetime

func _ready() -> void:
	add_to_group("player_attack")
	z_index = 7
	queue_redraw()

func _process(delta: float) -> void:
	if _lifetime_remaining > 0.0:
		_lifetime_remaining -= delta
		if _lifetime_remaining <= 0.0:
			queue_free()
			return
	if controller == null or not is_instance_valid(controller) or player == null or not is_instance_valid(player):
		return
	var interval: float = controller.get_cloud_attack_interval()
	# Each cloud charges independently while moving or waiting for a target.
	# Cap at one ready strike so idle time cannot create a burst of attacks.
	_strike_timer = minf(_strike_timer + delta, interval)
	if not _is_alive_enemy(target):
		target = controller.assign_cloud_target(self)
	var follow_position: Vector2 = player.global_position + Vector2(0.0, -FOLLOW_HEIGHT)
	if _is_alive_enemy(target):
		follow_position = target.global_position + Vector2(0.0, -FOLLOW_HEIGHT)
	_move_toward(follow_position, delta)
	if not _is_alive_enemy(target):
		return
	if global_position.distance_to(follow_position) > FOLLOW_EPSILON:
		return
	if _strike_timer < interval:
		return
	_strike_timer -= interval
	var struck_target = target
	var target_position: Vector2 = struck_target.global_position
	struck_target.take_damage(STRIKE_DAMAGE)
	controller.on_cloud_strike(global_position, target_position)
	if not _is_alive_enemy(struck_target):
		target = null

func _move_toward(destination: Vector2, delta: float) -> void:
	var offset := destination - global_position
	var distance := offset.length()
	if distance <= 0.001:
		return
	global_position += offset.normalized() * minf(distance, MOVE_SPEED * delta)

func _is_alive_enemy(enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and enemy.is_in_group("enemy") and float(enemy.get("hp")) > 0.0

func _draw() -> void:
	draw_circle(Vector2(-24.0, 2.0), 24.0, Color(0.25, 0.25, 0.34, 0.95))
	draw_circle(Vector2(0.0, -8.0), 31.0, Color(0.31, 0.30, 0.42, 0.98))
	draw_circle(Vector2(28.0, 3.0), 22.0, Color(0.25, 0.25, 0.34, 0.95))
	draw_line(Vector2(-10.0, 24.0), Vector2(3.0, 38.0), Color.YELLOW, 4.0)
	draw_line(Vector2(3.0, 38.0), Vector2(-4.0, 52.0), Color.YELLOW, 4.0)
