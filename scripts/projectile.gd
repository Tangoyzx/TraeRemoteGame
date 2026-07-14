class_name Projectile
extends Area2D

const BASE_RADIUS := 6.0
# 无元素时的默认弹体色(暖黄)。
const DEFAULT_COLOR := Color(1.0, 0.86, 0.16, 1.0)

var velocity := Vector2.ZERO
var damage := 100.0
var lifetime := 2.2
var radius := BASE_RADIUS
# 命中后仍可继续穿透的敌人数(0 = 命中即销毁)。
var pierce := 0
var combat_effects


func _ready() -> void:
	add_to_group("projectile")
	_create_collision()
	area_entered.connect(_on_area_entered)
	queue_redraw()


func setup(
	start_position: Vector2,
	direction: Vector2,
	projectile_speed: float,
	projectile_damage: float,
	projectile_radius: float,
	projectile_lifetime: float,
	pierce_count: int,
	effect_controller = null
) -> void:
	global_position = start_position
	velocity = direction.normalized() * projectile_speed
	damage = projectile_damage
	radius = projectile_radius
	lifetime = projectile_lifetime
	pierce = pierce_count
	combat_effects = effect_controller
	# setup 在 add_child 之前/之后都可能被调用,确保元素色被刷新到绘制。
	queue_redraw()


func _process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		if combat_effects != null and is_instance_valid(combat_effects):
			combat_effects.apply_weapon_hit(area, damage, area.global_position, {"source": "projectile"})
		else:
			area.take_damage(damage)
		if pierce > 0:
			pierce -= 1
		else:
			queue_free()


func _create_collision() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	var c := DEFAULT_COLOR
	if combat_effects != null and is_instance_valid(combat_effects):
		c = combat_effects.get_dominant_element_color(c)
	draw_circle(Vector2.ZERO, radius, c)