class_name Enemy
extends Area2D

signal died(enemy: Enemy)

var enemy_name := "Basic"
var radius := 18.0
var max_hp := 100.0
var hp := 100.0
var damage := 100
var speed := 115.0
var score_value := 1
var body_color := Color(0.92, 0.20, 0.20, 1.0)
var outline_color := Color(1.0, 0.68, 0.68, 1.0)
var target: Node2D
var _debuffs := {}
# debuff → 浅色滤镜映射(叠在 body 之上,半透明,避免变成纯色)。
# 用 var 而非 const:const Dictionary 在 release 编译器里 [] 索引的值类型无法
# 静态推断为 Color,会导致 extends 本类的 boss.gd / preload 链编译失败。
var DEBUFF_TINTS := {
	"poison": Color(0.55, 1.0, 0.55, 0.40),
	"frost": Color(0.55, 0.80, 1.0, 0.45),
}
var _debuff_sig := ""


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
	_update_debuffs(delta)
	_refresh_debuff_redraw()
	if target == null or not is_instance_valid(target):
		return
	var offset := target.global_position - global_position
	if offset.length() > 1.0:
		global_position += offset.normalized() * speed * _get_speed_multiplier() * delta


# debuff 集合变化时才重绘,避免每帧无谓 redraw。
func _refresh_debuff_redraw() -> void:
	var sig := _debuff_signature()
	if sig != _debuff_sig:
		_debuff_sig = sig
		queue_redraw()


func _debuff_signature() -> String:
	if _debuffs.is_empty():
		return ""
	var keys := _debuffs.keys()
	keys.sort()
	return ",".join(PackedStringArray(keys))


func take_damage(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		died.emit(self)
		queue_free()


func apply_debuff(debuff_id: String, duration: float, damage_per_second: float, speed_multiplier: float = 1.0) -> void:
	if debuff_id.is_empty() or duration <= 0.0 or hp <= 0.0:
		return
	_debuffs[debuff_id] = {
		"remaining": duration,
		"damage_per_second": maxf(0.0, damage_per_second),
		"speed_multiplier": clampf(speed_multiplier, 0.0, 1.0),
	}


func _update_debuffs(delta: float) -> void:
	if _debuffs.is_empty() or hp <= 0.0:
		return
	var expired := []
	for debuff_id in _debuffs.keys():
		var debuff: Dictionary = _debuffs[debuff_id]
		var damage_per_second := float(debuff.get("damage_per_second", 0.0))
		if damage_per_second > 0.0:
			take_damage(damage_per_second * delta)
			if hp <= 0.0:
				return
		debuff["remaining"] = float(debuff.get("remaining", 0.0)) - delta
		if float(debuff["remaining"]) <= 0.0:
			expired.append(debuff_id)
		else:
			_debuffs[debuff_id] = debuff
	for debuff_id in expired:
		_debuffs.erase(debuff_id)


func _get_speed_multiplier() -> float:
	var multiplier := 1.0
	for debuff in _debuffs.values():
		multiplier = minf(multiplier, float(debuff.get("speed_multiplier", 1.0)))
	return multiplier


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
	# debuff 浅色滤镜叠在 body 之上;多 debuff 时依次叠加形成混色。
	for debuff_id in DEBUFF_TINTS.keys():
		if _debuffs.has(debuff_id):
			draw_circle(Vector2.ZERO, radius, Color(DEBUFF_TINTS[debuff_id]))