class_name Enemy
extends Area2D

signal died(enemy: Enemy)

var enemy_name := "Chaser"
var radius := 18.0
var max_hp := 100.0
var hp := 100.0
var damage := 100
var speed := 190.0
var score_value := 2
var shape_type := "square"
var tier := 1
var body_color := Color(0.92, 0.20, 0.20, 1.0)
var outline_color := Color(1.0, 0.68, 0.68, 1.0)
var target: Node2D
var _paralysis_timer: Timer
var _paralysis_visual: Node2D

func _ready() -> void:
	add_to_group("enemy")
	_create_collision()
	_create_paralysis_status()
	queue_redraw()

func apply_config(config: Dictionary) -> void:
	enemy_name = str(config.get("name", enemy_name))
	radius = float(config.get("radius", radius))
	max_hp = float(config.get("max_hp", max_hp))
	hp = max_hp
	damage = int(config.get("damage", damage))
	speed = float(config.get("speed", speed))
	score_value = int(config.get("score_value", score_value))
	shape_type = str(config.get("shape", shape_type))
	tier = int(config.get("tier", tier))
	body_color = config.get("body_color", body_color)
	outline_color = config.get("outline_color", outline_color)

func apply_runtime_scaling(hp_multiplier: float, speed_multiplier: float) -> void:
	max_hp = maxf(1.0, max_hp * hp_multiplier)
	hp = max_hp
	speed *= speed_multiplier

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or is_paralyzed():
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

func apply_paralysis(duration: float) -> void:
	if duration <= 0.0 or hp <= 0.0 or _paralysis_timer == null:
		return
	_paralysis_timer.start(duration)
	if _paralysis_visual != null:
		_paralysis_visual.visible = true

func is_paralyzed() -> bool:
	return _paralysis_timer != null and not _paralysis_timer.is_stopped()

func _create_paralysis_status() -> void:
	_paralysis_timer = Timer.new()
	_paralysis_timer.name = "ParalysisTimer"
	_paralysis_timer.one_shot = true
	_paralysis_timer.timeout.connect(_on_paralysis_ended)
	add_child(_paralysis_timer)
	var visual := ParalysisVisual.new()
	visual.name = "ParalysisVisual"
	visual.radius = radius
	visual.visible = false
	visual.z_index = 5
	add_child(visual)
	_paralysis_visual = visual

func _on_paralysis_ended() -> void:
	if _paralysis_visual != null:
		_paralysis_visual.visible = false

func _create_collision() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	add_child(collision)

func _draw() -> void:
	match shape_type:
		"triangle":
			_draw_triangle()
		"diamond":
			_draw_diamond()
		_:
			_draw_square()

func _draw_square() -> void:
	var rect := Rect2(Vector2(-radius, -radius), Vector2(radius * 2.0, radius * 2.0))
	draw_rect(rect, body_color, true)
	draw_rect(rect, outline_color, false, 3.0)

func _draw_triangle() -> void:
	var points := PackedVector2Array([
		Vector2(0.0, -radius),
		Vector2(radius * 0.90, radius * 0.70),
		Vector2(-radius * 0.90, radius * 0.70),
	])
	draw_colored_polygon(points, body_color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, outline_color, 3.0, true)

func _draw_diamond() -> void:
	var points := PackedVector2Array([
		Vector2(0.0, -radius),
		Vector2(radius, 0.0),
		Vector2(0.0, radius),
		Vector2(-radius, 0.0),
	])
	draw_colored_polygon(points, body_color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, outline_color, 3.0, true)

class ParalysisVisual:
	extends Node2D

	var radius := 18.0

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.90, 0.20, 0.20))
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 24, Color(1.0, 0.92, 0.25, 0.95), 3.0)
		draw_line(Vector2(-radius, -radius * 0.5), Vector2(radius * 0.2, 0.0), Color.YELLOW, 2.0)
		draw_line(Vector2(radius * 0.2, 0.0), Vector2(-radius * 0.1, radius), Color.YELLOW, 2.0)
