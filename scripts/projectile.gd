class_name Projectile
extends Area2D

const DEFAULT_COLOR := Color(1.0, 0.86, 0.16, 1.0)
var velocity := Vector2.ZERO
var damage := 50.0
var lifetime := 2.2
var radius := 6.0

func _ready() -> void:
	add_to_group("projectile")
	_create_collision()
	area_entered.connect(_on_area_entered)
	queue_redraw()

func setup(start_position: Vector2, direction: Vector2, projectile_speed: float, projectile_damage: float, projectile_radius: float, projectile_lifetime: float) -> void:
	global_position = start_position
	velocity = direction.normalized() * projectile_speed
	damage = projectile_damage
	radius = projectile_radius
	lifetime = projectile_lifetime

func _process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		area.take_damage(damage)
		queue_free()

func _create_collision() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	add_child(collision)

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, DEFAULT_COLOR)
