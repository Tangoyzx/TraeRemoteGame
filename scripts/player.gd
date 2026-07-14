class_name Player
extends Area2D

signal died

const RADIUS := 20.0
# Internal HP/damage unit: 100 = 1 player-facing HP point.
const HP_UNIT := 100
const MAX_HP := 3 * HP_UNIT
const SPEED := 230.0
const CONTACT_INVULNERABLE_SECONDS := 2.0
const FLASH_INTERVAL := 0.1

var map_rect := Rect2(Vector2.ZERO, Vector2(12800.0, 7200.0))
var hp := MAX_HP
var move_target := Vector2.ZERO
var has_move_target := false
var _damage_cooldown := 0.0
var _flash_timer := 0.0
var _hp_label: Label


func _ready() -> void:
	add_to_group("player")
	_create_collision()
	_create_hp_label()
	_update_hp_label()
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _process(delta: float) -> void:
	if _damage_cooldown > 0.0:
		_damage_cooldown -= delta
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_timer = FLASH_INTERVAL
			visible = not visible
		if _damage_cooldown <= 0.0:
			visible = true
	if has_move_target:
		_move_toward_target(delta)
	_damage_overlapping_enemies()


func set_move_target(target: Vector2) -> void:
	move_target = Vector2(
		clampf(target.x, map_rect.position.x, map_rect.end.x),
		clampf(target.y, map_rect.position.y, map_rect.end.y)
	)
	has_move_target = true


func take_damage(amount: int) -> void:
	if amount <= 0 or _damage_cooldown > 0.0 or hp <= 0:
		return
	hp = max(0, hp - amount)
	_damage_cooldown = CONTACT_INVULNERABLE_SECONDS
	_update_hp_label()
	if hp <= 0:
		died.emit()


func _move_toward_target(delta: float) -> void:
	var offset := move_target - global_position
	var distance := offset.length()
	if distance <= 4.0:
		global_position = move_target
		has_move_target = false
		return
	var step := SPEED * delta
	global_position += offset.normalized() * minf(step, distance)


func _damage_overlapping_enemies() -> void:
	if _damage_cooldown > 0.0 or hp <= 0:
		return
	for area in get_overlapping_areas():
		if area.is_in_group("enemy"):
			take_damage(area.damage)
			return


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		take_damage(area.damage)


func _create_collision() -> void:
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	add_child(collision)


func _create_hp_label() -> void:
	_hp_label = Label.new()
	_hp_label.name = "HpLabel"
	_hp_label.position = Vector2(-36, -58)
	_hp_label.add_theme_font_size_override("font_size", 20)
	add_child(_hp_label)


func _update_hp_label() -> void:
	if _hp_label != null:
		_hp_label.text = "HP: %d" % hp


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0.20, 0.55, 1.0, 1.0))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 36, Color(0.80, 0.92, 1.0, 1.0), 3.0)
