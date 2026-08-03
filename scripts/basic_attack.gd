class_name BasicAttack
extends Node

signal shot_fired(target)

# Permanent player attack; not a skill or upgrade option.
const FIRE_INTERVAL := 2.0
const PROJECTILE_DAMAGE := 50.0
const PROJECTILE_SPEED := 520.0
const PROJECTILE_RADIUS := 6.0
const PROJECTILE_LIFETIME := 2.2
const MUZZLE_OFFSET := 28.0

var player
var enemies_layer: Node2D
var projectiles_layer: Node2D
var projectile_script: Script
var _cooldown := 0.0

func _ready() -> void:
	add_to_group("player_attack")

func setup(owner_player, enemy_container: Node2D, projectile_container: Node2D, projectile_scene: Script) -> void:
	player = owner_player
	enemies_layer = enemy_container
	projectiles_layer = projectile_container
	projectile_script = projectile_scene

func _process(delta: float) -> void:
	if player == null or enemies_layer == null or projectiles_layer == null or projectile_script == null:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target = _find_nearest_enemy()
	if target == null:
		return
	_fire_at(target)
	_cooldown = FIRE_INTERVAL

func _find_nearest_enemy():
	var nearest = null
	var nearest_distance := INF
	for child in enemies_layer.get_children():
		if not child.is_in_group("enemy") or not is_instance_valid(child):
			continue
		var distance: float = player.global_position.distance_squared_to(child.global_position)
		if distance < nearest_distance:
			nearest = child
			nearest_distance = distance
	return nearest

func _fire_at(enemy) -> void:
	var direction: Vector2 = enemy.global_position - player.global_position
	if direction.length_squared() <= 0.001:
		return
	var projectile = projectile_script.new()
	projectile.setup(
		player.global_position + direction.normalized() * MUZZLE_OFFSET,
		direction,
		PROJECTILE_SPEED,
		PROJECTILE_DAMAGE,
		PROJECTILE_RADIUS,
		PROJECTILE_LIFETIME
	)
	projectiles_layer.add_child(projectile)
	shot_fired.emit(enemy)
