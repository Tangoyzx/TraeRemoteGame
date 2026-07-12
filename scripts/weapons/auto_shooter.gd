class_name AutoShooter
extends Node

# 基线参数(随升级变化,参见 docs/skill-calibration.md §2)。
const BASE_FIRE_INTERVAL := 1.10
const BASE_PROJECTILE_SPEED := 520.0
const BASE_PROJECTILE_DAMAGE := 100.0
const BASE_PROJECTILE_RADIUS := 6.0
const BASE_PROJECTILE_LIFETIME := 2.2
const MUZZLE_OFFSET := 28.0

var player: Player
var enemies_layer: Node2D
var projectiles_layer: Node2D
var projectile_script: Script
var _cooldown := 0.0

# 当前参数(由 _recompute 从通用属性堆叠数推导)。
var _fire_interval := BASE_FIRE_INTERVAL
var _projectile_speed := BASE_PROJECTILE_SPEED
var _projectile_damage := BASE_PROJECTILE_DAMAGE
var _projectile_radius := BASE_PROJECTILE_RADIUS
var _projectile_lifetime := BASE_PROJECTILE_LIFETIME
var _pierce := 0
var _projectile_count := 1
var _stat_stacks := {}


func _ready() -> void:
	add_to_group("weapon")


func setup(owner_player: Player, enemy_container: Node2D, projectile_container: Node2D, projectile_scene: Script) -> void:
	player = owner_player
	enemies_layer = enemy_container
	projectiles_layer = projectile_container
	projectile_script = projectile_scene


# 由 main 在 stat 升级时调用,传入该属性的当前堆叠数(绝对值)。
func apply_stat(stat: int, stacks: int) -> void:
	_stat_stacks[stat] = clampi(stacks, 0, StatMath.MAX_STACKS)
	_recompute()


func _recompute() -> void:
	# FREQUENCY:冷却 ÷(1 + 累积增益)。k=1.0。
	var freq := _stacks(StatMath.Stat.FREQUENCY)
	_fire_interval = BASE_FIRE_INTERVAL / (1.0 + StatMath.total_multiplier(StatMath.Stat.FREQUENCY, freq))

	# DAMAGE:k=1.0。
	var dmg := _stacks(StatMath.Stat.DAMAGE)
	_projectile_damage = BASE_PROJECTILE_DAMAGE * (1.0 + StatMath.total_multiplier(StatMath.Stat.DAMAGE, dmg))

	# SPEED:k=1.0。
	var spd := _stacks(StatMath.Stat.SPEED)
	_projectile_speed = BASE_PROJECTILE_SPEED * (1.0 + StatMath.total_multiplier(StatMath.Stat.SPEED, spd))

	# AREA:弹体半径。k=1.0。
	var area := _stacks(StatMath.Stat.AREA)
	_projectile_radius = BASE_PROJECTILE_RADIUS * (1.0 + StatMath.total_multiplier(StatMath.Stat.AREA, area))

	# DURATION:弹体寿命(射程)。k=1.0。
	var dur := _stacks(StatMath.Stat.DURATION)
	_projectile_lifetime = BASE_PROJECTILE_LIFETIME * (1.0 + StatMath.total_multiplier(StatMath.Stat.DURATION, dur))

	# PIERCE:整数型,每层 +1 穿透。
	_pierce = _stacks(StatMath.Stat.PIERCE)

	# COUNT:整数型,每层 +1 弹(各瞄不同最近敌)。
	_projectile_count = 1 + _stacks(StatMath.Stat.COUNT)


func _stacks(stat: int) -> int:
	return int(_stat_stacks.get(stat, 0))


func _process(delta: float) -> void:
	if player == null or enemies_layer == null or projectiles_layer == null or projectile_script == null:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var targets := _find_nearest_enemies(_projectile_count)
	if targets.is_empty():
		return
	for target in targets:
		_fire_at(target)
	_cooldown = _fire_interval


# 取最近的 count 个不同敌人,按距离升序。
func _find_nearest_enemies(count: int) -> Array:
	var entries := []
	for child in enemies_layer.get_children():
		if child is Enemy and is_instance_valid(child):
			entries.append({
				"enemy": child,
				"dist": player.global_position.distance_squared_to(child.global_position)
			})
	entries.sort_custom(func(a, b): return float(a["dist"]) < float(b["dist"]))
	var result := []
	var n := min(count, entries.size())
	for i in n:
		result.append(entries[i]["enemy"])
	return result


func _fire_at(enemy: Enemy) -> void:
	var direction := enemy.global_position - player.global_position
	if direction.length_squared() <= 0.001:
		return
	var projectile: Projectile = projectile_script.new()
	projectile.setup(
		player.global_position + direction.normalized() * MUZZLE_OFFSET,
		direction,
		_projectile_speed,
		_projectile_damage,
		_projectile_radius,
		_projectile_lifetime,
		_pierce
	)
	projectiles_layer.add_child(projectile)
