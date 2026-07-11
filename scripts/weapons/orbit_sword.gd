class_name OrbitSword
extends Area2D

const DAMAGE := 1
const ORBIT_RADIUS := 186.0
const ORBIT_SPEED := 3.4
const SIZE := Vector2(52.0, 12.0)
const HIT_COOLDOWN_SECONDS := 0.45

var player: Player
var _angle := 0.0
var _hit_cooldowns := {}


func _ready() -> void:
	add_to_group("weapon")
	_create_collision()
	area_entered.connect(_on_area_entered)
	queue_redraw()


func setup(owner_player: Player) -> void:
	player = owner_player


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_angle += ORBIT_SPEED * delta
	global_position = player.global_position + Vector2.RIGHT.rotated(_angle) * ORBIT_RADIUS
	rotation = _angle + PI * 0.5
	_update_hit_cooldowns(delta)
	_damage_overlapping_enemies()


func _on_area_entered(area: Area2D) -> void:
	if area is Enemy:
		_try_hit_enemy(area)


func _damage_overlapping_enemies() -> void:
	for area in get_overlapping_areas():
		if area is Enemy:
			_try_hit_enemy(area)


func _try_hit_enemy(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if _hit_cooldowns.has(id):
		return
	enemy.take_damage(DAMAGE)
	_hit_cooldowns[id] = HIT_COOLDOWN_SECONDS


func _update_hit_cooldowns(delta: float) -> void:
	var expired := []
	for id in _hit_cooldowns.keys():
		_hit_cooldowns[id] -= delta
		if _hit_cooldowns[id] <= 0.0:
			expired.append(id)
	for id in expired:
		_hit_cooldowns.erase(id)


func _create_collision() -> void:
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	var rect := Rect2(-SIZE * 0.5, SIZE)
	draw_rect(rect, Color(0.88, 0.96, 1.0, 1.0), true)
	draw_rect(rect, Color(0.38, 0.78, 1.0, 1.0), false, 2.0)
