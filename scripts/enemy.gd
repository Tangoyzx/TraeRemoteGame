class_name Enemy
extends Area2D

signal died(enemy: Enemy)

var enemy_name := "Basic"
var radius := 18.0
var max_hp := 1
var hp := 1
var damage := 1
var speed := 115.0
var score_value := 1
var body_color := Color(0.92, 0.20, 0.20, 1.0)
var outline_color := Color(1.0, 0.68, 0.68, 1.0)
var target: Node2D


func _ready() -> void:
	add_to_group("enemy")
	_create_collision()
	queue_redraw()


func apply_config(config: Dictionary) -> void:
	enemy_name = str(config.get("name", enemy_name))
	radius = float(config.get("radius", radius))
	max_hp = float(config.get("max_hp", max_hp))
	hp = max_hp
	damage = int(config.get("damage", damage))
	speed = float(config.get("speed", speed))
	score_value = int(config.get("score_value", score_value))
	body_color = config.get("body_color", body_color)
	outline_color = config.get("outline_color", outline_color)


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var offset := target.global_position - global_position
	if offset.length() > 1.0:
		global_position += offset.normalized() * speed * delta


func take_damage(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		died.emit(self)
		queue_free()


func _create_collision() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, outline_color, 2.0)
