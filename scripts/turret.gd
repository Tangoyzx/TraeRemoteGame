class_name Turret
extends Enemy

# Stationary enemy that periodically fires at the player.
const FIRE_INTERVAL := 1.0
const FIRE_RANGE := 1280.0
const PROJECTILE_SPEED := 250.0
const PROJECTILE_LIFETIME := FIRE_RANGE / PROJECTILE_SPEED

var _fire_timer := 0.0
var _projectiles_layer: Node2D
var _projectile_scene

func _ready() -> void:
	super()
	add_to_group("turret")

func setup_projectiles(layer: Node2D, projectile_scene) -> void:
	_projectiles_layer = layer
	_projectile_scene = projectile_scene

func _process(delta: float) -> void:
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
	projectile.setup(global_position, to_target.normalized(), PROJECTILE_SPEED, float(damage), PROJECTILE_LIFETIME)
	_projectiles_layer.add_child(projectile)

func _draw() -> void:
	var r := radius
	var pts := PackedVector2Array([
		Vector2(0.0, -r),
		Vector2(r * 0.866, r * 0.5),
		Vector2(-r * 0.866, r * 0.5),
	])
	draw_colored_polygon(pts, body_color)
	var outline_pts := PackedVector2Array(pts)
	outline_pts.append(pts[0])
	draw_polyline(outline_pts, outline_color, 2.0)
