class_name ElectricSkillController
extends Node

const LaserBeamScene := preload("res://scripts/electric_laser_beam.gd")
const BoltFlashScene := preload("res://scripts/electric_bolt_flash.gd")
const ExplosionFlashScene := preload("res://scripts/electric_explosion_flash.gd")
const ThunderCloudScene := preload("res://scripts/thunder_cloud.gd")
const ThunderBallScene := preload("res://scripts/thunder_ball.gd")

const LASER_LENGTH := 600.0
const LASER_BASE_WIDTH := 10.0
const LASER_LEVEL_ONE_DAMAGE := 50
const LASER_CHAIN_DELAY := 0.5
const THUNDER_BALL_LEVEL_ONE_DAMAGE := 25
const THUNDER_BALL_EXPLOSION_RADIUS := 100.0
const PARALYSIS_DURATION := 5.0
const LASER_CLOUD_DURATION := 10.0

var player
var enemies_layer: Node2D
var effects_layer: Node2D
var basic_attack
var _upgrade_levels := {}
var _clouds := []
var _temporary_clouds := []
var _ball_spawn_timer := 0.0
var _laser_cloud_progress := 0
var _active := true

func _ready() -> void:
	add_to_group("player_attack")

func setup(owner_player, enemy_container: Node2D, effect_container: Node2D, attack) -> void:
	player = owner_player
	enemies_layer = enemy_container
	effects_layer = effect_container
	basic_attack = attack
	if basic_attack != null and not basic_attack.enemy_damaged.is_connected(_on_basic_attack_enemy_damaged):
		basic_attack.enemy_damaged.connect(_on_basic_attack_enemy_damaged)

func set_upgrade_level(upgrade_id: String, level: int) -> void:
	var previous_level: int = int(_upgrade_levels.get(upgrade_id, 0))
	_upgrade_levels[upgrade_id] = clampi(level, 0, 3)
	if upgrade_id == "thunder_cloud":
		_ensure_cloud_count()
	elif upgrade_id == "thunder_ball" and previous_level <= 0 and level > 0:
		_ball_spawn_timer = get_ball_spawn_interval()
	elif upgrade_id == "thunder_ball" and level > previous_level:
		_ball_spawn_timer = minf(_ball_spawn_timer, get_ball_spawn_interval())

func get_upgrade_level(upgrade_id: String) -> int:
	return int(_upgrade_levels.get(upgrade_id, 0))

func _process(delta: float) -> void:
	if not _active:
		return
	_prune_clouds()
	_ensure_cloud_count()
	var ball_level := get_upgrade_level("thunder_ball")
	if ball_level <= 0:
		return
	_ball_spawn_timer -= delta
	if _ball_spawn_timer > 0.0:
		return
	spawn_thunder_ball(player.global_position)
	_ball_spawn_timer += get_ball_spawn_interval()
	if _ball_spawn_timer <= 0.0:
		_ball_spawn_timer = get_ball_spawn_interval()

func stop() -> void:
	_active = false
	set_process(false)

func _on_basic_attack_enemy_damaged(enemy, hit_position: Vector2) -> void:
	var laser_level := get_upgrade_level("laser")
	if laser_level <= 0 or not _roll_level_chance(laser_level):
		return
	var target_id: int = int(enemy.get_instance_id()) if enemy != null and is_instance_valid(enemy) else 0
	spawn_laser_at_position(player.global_position, hit_position, target_id)

func spawn_laser(origin: Vector2, excluded_target_id: int = 0) -> void:
	if not _active or enemies_layer == null or effects_layer == null:
		return
	var target = _pick_random_enemy(excluded_target_id)
	if target == null:
		return
	_fire_laser_at_target(origin, target)

func spawn_laser_at_position(origin: Vector2, target_position: Vector2, target_id: int = 0) -> void:
	if not _active or enemies_layer == null or effects_layer == null:
		return
	_fire_laser_at_position(origin, target_position, target_id)

func _fire_laser_at_target(origin: Vector2, target) -> void:
	_fire_laser_at_position(origin, target.global_position, target.get_instance_id())

func _fire_laser_at_position(origin: Vector2, target_position: Vector2, target_id: int) -> void:
	var direction := target_position - origin
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()
	var beam_width := LASER_BASE_WIDTH + float(get_upgrade_level("laser_width")) * 10.0
	var laser_damage := _get_base_effect_damage("laser", LASER_LEVEL_ONE_DAMAGE)
	_damage_laser_targets(origin, direction, beam_width, laser_damage)
	var beam = LaserBeamScene.new()
	beam.setup(origin, direction, LASER_LENGTH, beam_width)
	effects_layer.add_child(beam)
	_register_laser_for_cloud()
	var chain_level := get_upgrade_level("laser_chain")
	if chain_level > 0 and _roll_level_chance(chain_level):
		_schedule_laser_chain(target_position, target_id)

func _register_laser_for_cloud() -> void:
	var cloud_level := get_upgrade_level("laser_cloud")
	if cloud_level <= 0:
		return
	_laser_cloud_progress += 1
	var required_count := _get_laser_cloud_required_count(cloud_level)
	while _laser_cloud_progress >= required_count:
		_laser_cloud_progress -= required_count
		_spawn_temporary_cloud()

func _get_laser_cloud_required_count(level: int) -> int:
	match level:
		1:
			return 20
		2:
			return 15
		_:
			return 10

func _spawn_temporary_cloud() -> void:
	if not _active or player == null or effects_layer == null:
		return
	var cloud = ThunderCloudScene.new()
	cloud.setup(self, player, player.global_position + Vector2(0.0, -100.0), LASER_CLOUD_DURATION)
	effects_layer.add_child(cloud)
	_temporary_clouds.append(cloud)

func _schedule_laser_chain(next_origin: Vector2, excluded_target_id: int) -> void:
	await get_tree().create_timer(LASER_CHAIN_DELAY, false).timeout
	if not _active or not is_inside_tree():
		return
	spawn_laser(next_origin, excluded_target_id)

func _damage_laser_targets(origin: Vector2, direction: Vector2, beam_width: float, damage: int) -> void:
	var end_position := origin + direction * LASER_LENGTH
	var hit_targets := []
	for enemy in enemies_layer.get_children():
		if not _is_alive_enemy(enemy):
			continue
		var enemy_radius: float = float(enemy.get("radius"))
		var hit_radius := beam_width * 0.5 + enemy_radius
		if _distance_squared_to_segment(enemy.global_position, origin, end_position) <= hit_radius * hit_radius:
			hit_targets.append(enemy)
	for enemy in hit_targets:
		if _is_alive_enemy(enemy):
			enemy.take_damage(damage)

func _distance_squared_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_squared_to(start)
	var ratio := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_squared_to(start + segment * ratio)

func assign_cloud_target(requesting_cloud):
	var reserved_ids := {}
	for cloud in _get_all_clouds():
		if cloud == requesting_cloud or cloud == null or not is_instance_valid(cloud):
			continue
		var cloud_target = cloud.target
		if _is_alive_enemy(cloud_target):
			reserved_ids[cloud_target.get_instance_id()] = true
	var nearest = null
	var nearest_distance_squared := INF
	for enemy in enemies_layer.get_children():
		if not _is_alive_enemy(enemy):
			continue
		if reserved_ids.has(enemy.get_instance_id()):
			continue
		var distance_squared: float = player.global_position.distance_squared_to(enemy.global_position)
		if distance_squared < nearest_distance_squared:
			nearest = enemy
			nearest_distance_squared = distance_squared
	return nearest

func get_cloud_attack_interval() -> float:
	match get_upgrade_level("thunder_cloud_haste"):
		1:
			return 2.0 / 1.5
		2:
			return 1.0
		3:
			return 2.0 / 2.5
		_:
			return 2.0

func on_cloud_strike(cloud_position: Vector2, target_position: Vector2) -> void:
	_spawn_bolt(cloud_position, target_position)
	var ball_level := get_upgrade_level("thunder_cloud_ball")
	if ball_level > 0 and _roll_level_chance(ball_level):
		spawn_thunder_ball(target_position)

func spawn_thunder_ball(spawn_position: Vector2) -> void:
	if not _active or effects_layer == null:
		return
	var ball = ThunderBallScene.new()
	var base_level := get_upgrade_level("thunder_ball")
	ball.setup(self, enemies_layer, spawn_position, base_level)
	effects_layer.add_child(ball)

func explode_thunder_ball(center: Vector2, base_level: int) -> void:
	if not _active:
		return
	var damaged_targets := []
	var radius_squared := THUNDER_BALL_EXPLOSION_RADIUS * THUNDER_BALL_EXPLOSION_RADIUS
	for enemy in enemies_layer.get_children():
		if not _is_alive_enemy(enemy):
			continue
		if center.distance_squared_to(enemy.global_position) <= radius_squared:
			damaged_targets.append(enemy)
	var explosion_damage := _get_effect_damage_for_level(base_level, THUNDER_BALL_LEVEL_ONE_DAMAGE)
	for enemy in damaged_targets:
		if _is_alive_enemy(enemy):
			enemy.take_damage(explosion_damage)
	var paralysis_level := get_upgrade_level("thunder_ball_paralysis")
	if paralysis_level > 0 and _roll_level_chance(paralysis_level):
		for enemy in damaged_targets:
			if _is_alive_enemy(enemy):
				enemy.apply_paralysis(PARALYSIS_DURATION)
	var laser_level := get_upgrade_level("thunder_ball_laser")
	if laser_level > 0 and _roll_level_chance(laser_level):
		spawn_laser(center)
	_spawn_explosion(center)

func get_ball_spawn_interval() -> float:
	var ball_level := get_upgrade_level("thunder_ball")
	if ball_level <= 0:
		return INF
	return 10.0 / float(ball_level)

func _ensure_cloud_count() -> void:
	if not _active or player == null or effects_layer == null:
		return
	var desired_count := get_upgrade_level("thunder_cloud")
	while _clouds.size() < desired_count:
		var cloud = ThunderCloudScene.new()
		cloud.setup(self, player, player.global_position + Vector2(0.0, -100.0))
		effects_layer.add_child(cloud)
		_clouds.append(cloud)

func _prune_clouds() -> void:
	var valid_clouds := []
	for cloud in _clouds:
		if cloud != null and is_instance_valid(cloud):
			valid_clouds.append(cloud)
	_clouds = valid_clouds
	var valid_temporary_clouds := []
	for cloud in _temporary_clouds:
		if cloud != null and is_instance_valid(cloud):
			valid_temporary_clouds.append(cloud)
	_temporary_clouds = valid_temporary_clouds

func _get_all_clouds() -> Array:
	var all_clouds := _clouds.duplicate()
	all_clouds.append_array(_temporary_clouds)
	return all_clouds

func _pick_random_enemy(excluded_target_id: int = 0):
	var candidates := []
	for enemy in enemies_layer.get_children():
		if not _is_alive_enemy(enemy):
			continue
		if excluded_target_id != 0 and enemy.get_instance_id() == excluded_target_id:
			continue
		candidates.append(enemy)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]

func _is_alive_enemy(enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and enemy.is_in_group("enemy") and float(enemy.get("hp")) > 0.0

func _roll_level_chance(level: int) -> bool:
	return randf() < float(level) * 0.20

func _get_base_effect_damage(upgrade_id: String, level_one_damage: int) -> int:
	return _get_effect_damage_for_level(get_upgrade_level(upgrade_id), level_one_damage)

func _get_effect_damage_for_level(level: int, level_one_damage: int) -> int:
	if level > 0:
		return level_one_damage
	return int(floor(float(level_one_damage) * 0.5 + 0.5))

func _spawn_bolt(start_position: Vector2, end_position: Vector2) -> void:
	var bolt = BoltFlashScene.new()
	bolt.setup(start_position, end_position)
	effects_layer.add_child(bolt)

func _spawn_explosion(center: Vector2) -> void:
	var flash = ExplosionFlashScene.new()
	flash.setup(center, THUNDER_BALL_EXPLOSION_RADIUS)
	effects_layer.add_child(flash)
