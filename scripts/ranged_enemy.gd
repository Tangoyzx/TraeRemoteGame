class_name RangedEnemy
extends Enemy

var preferred_distance_min := 420.0
var preferred_distance_max := 600.0
var fire_interval := 3.5
var fire_range := 900.0
var projectile_speed := 260.0
var projectile_damage := 100.0
var _fire_timer := 0.0
var _strafe_direction := 1.0
var _fire_interval_floor := 1.4
var _strafe_change_timer := 0.0
var _projectiles_layer: Node2D
var _projectile_scene

func apply_config(config: Dictionary) -> void:
	super(config)
	preferred_distance_min = float(config.get("preferred_distance_min", preferred_distance_min))
	preferred_distance_max = float(config.get("preferred_distance_max", preferred_distance_max))
	fire_interval = float(config.get("fire_interval", fire_interval))
	fire_range = float(config.get("fire_range", fire_range))
	projectile_speed = float(config.get("projectile_speed", projectile_speed))
	projectile_damage = float(config.get("projectile_damage", projectile_damage))

func apply_runtime_scaling(hp_multiplier: float, speed_multiplier: float, fire_interval_multiplier: float = 1.0) -> void:
	super(hp_multiplier, speed_multiplier)
	fire_interval = maxf(_fire_interval_floor, fire_interval * fire_interval_multiplier)

func set_fire_interval_floor(value: float) -> void:
	_fire_interval_floor = value

func setup_projectiles(layer: Node2D, projectile_scene) -> void:
	_projectiles_layer = layer
	_projectile_scene = projectile_scene

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_update_movement(delta)
	_fire_timer += delta
	if _fire_timer >= fire_interval:
		_fire_timer -= fire_interval
		_try_fire()

func _update_movement(delta: float) -> void:
	if is_paralyzed():
		return
	var to_target: Vector2 = target.global_position - global_position
	var distance := to_target.length()
	if distance <= 0.001:
		return
	var direction := to_target / distance
	var movement := Vector2.ZERO
	if distance < preferred_distance_min:
		movement = -direction
	elif distance > preferred_distance_max:
		movement = direction
	else:
		_strafe_change_timer -= delta
		if _strafe_change_timer <= 0.0:
			_strafe_change_timer = randf_range(1.5, 3.5)
			_strafe_direction = -1.0 if randf() < 0.5 else 1.0
		movement = direction.orthogonal() * _strafe_direction
	global_position += movement.normalized() * speed * delta

func _try_fire() -> void:
	if _projectiles_layer == null or _projectile_scene == null:
		return
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length() > fire_range or to_target.length_squared() <= 0.001:
		return
	var projectile = _projectile_scene.new()
	var lifetime := fire_range / projectile_speed
	projectile.setup(global_position, to_target.normalized(), projectile_speed, projectile_damage, lifetime)
	_projectiles_layer.add_child(projectile)
