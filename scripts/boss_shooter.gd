class_name BossShooter
extends Boss

# Moving boss that also fires at the player.
const FIRE_INTERVAL := 1.5
const FIRE_RANGE := 1400.0
const PROJECTILE_SPEED := 250.0
const PROJECTILE_DAMAGE := 100.0
const PROJECTILE_LIFETIME := FIRE_RANGE / PROJECTILE_SPEED

var _fire_timer := 0.0
var _projectiles_layer: Node2D
var _projectile_scene

func setup_projectiles(layer: Node2D, projectile_scene) -> void:
	_projectiles_layer = layer
	_projectile_scene = projectile_scene

func _process(delta: float) -> void:
	super(delta)
	if target == null or not is_instance_valid(target):
		return
	_fire_timer += delta
	if _fire_timer >= FIRE_INTERVAL:
		_fire_timer = 0.0
		_try_fire()

func _try_fire() -> void:
	if _projectiles_layer == null or _projectile_scene == null:
		return
	var to_target := target.global_position - global_position
	if to_target.length() > FIRE_RANGE:
		return
	var projectile = _projectile_scene.new()
	projectile.setup(global_position, to_target.normalized(), PROJECTILE_SPEED, PROJECTILE_DAMAGE, PROJECTILE_LIFETIME)
	_projectiles_layer.add_child(projectile)
