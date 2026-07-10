class_name AutoShooter
extends Node

const FIRE_INTERVAL := 0.55
const PROJECTILE_SPEED := 520.0
const PROJECTILE_DAMAGE := 1
const MUZZLE_OFFSET := 28.0

var player: Player
var enemies_layer: Node2D
var projectiles_layer: Node2D
var projectile_script: Script
var _cooldown := 0.0


func _ready() -> void:
	add_to_group("weapon")


func setup(owner_player: Player, enemy_container: Node2D, projectile_container: Node2D, projectile_scene: Script) -> void:
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
	var target := _find_nearest_enemy()
	if target == null:
		return
	_fire_at(target)
	_cooldown = FIRE_INTERVAL


func _find_nearest_enemy() -> Enemy:
	var nearest: Enemy = null
	var nearest_distance_sq := INF
	for child in enemies_layer.get_children():
		if child is Enemy and is_instance_valid(child):
			var distance_sq := player.global_position.distance_squared_to(child.global_position)
			if distance_sq < nearest_distance_sq:
				nearest_distance_sq = distance_sq
				nearest = child
	return nearest


func _fire_at(enemy: Enemy) -> void:
	var direction := enemy.global_position - player.global_position
	if direction.length_squared() <= 0.001:
		return
	var projectile: Projectile = projectile_script.new()
	projectile.setup(
		player.global_position + direction.normalized() * MUZZLE_OFFSET,
		direction,
		PROJECTILE_SPEED,
		PROJECTILE_DAMAGE
	)
	projectiles_layer.add_child(projectile)
