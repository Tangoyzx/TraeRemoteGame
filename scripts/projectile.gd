class_name Projectile
extends Area2D

const RADIUS := 6.0

var velocity := Vector2.ZERO
var damage := 1
var lifetime := 2.2


func _ready() -> void:
	add_to_group("projectile")
	_create_collision()
	area_entered.connect(_on_area_entered)
	queue_redraw()


func setup(start_position: Vector2, direction: Vector2, projectile_speed: float, projectile_damage: int) -> void:
	global_position = start_position
	velocity = direction.normalized() * projectile_speed
	damage = projectile_damage


func _process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area is Enemy:
		area.take_damage(damage)
		queue_free()


func _create_collision() -> void:
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.86, 0.16, 1.0))
