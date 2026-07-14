class_name CombatEffects
extends Node

const ELEMENT_FIRE := "fire"
const ELEMENT_POISON := "poison"
const ELEMENT_FROST := "frost"

const FIRE_EXPLOSION_RADIUS := 50.0
const FIRE_EXPLOSION_DAMAGE := 50.0
const FIRE_EXPLOSION_COOLDOWN := 20.0

const POISON_DAMAGE_PER_SECOND := 10.0
const POISON_DURATION := 5.0

const FROST_DAMAGE_PER_SECOND := 2.0
const FROST_DURATION := 5.0
const FROST_SPEED_MULTIPLIER := 0.5

# 元素 → 显示色映射(火=红、毒=绿、冰=蓝)。武器获得元素后会按此着色。
# 用 var 而非 const:const Dictionary 在 release 编译器里 .get()/[] 的值类型
# 无法静态推断为 Color,会导致依赖本脚本的 main.gd 编译失败。
var ELEMENT_COLORS := {
	ELEMENT_FIRE: Color(1.0, 0.32, 0.28, 1.0),
	ELEMENT_POISON: Color(0.40, 0.95, 0.40, 1.0),
	ELEMENT_FROST: Color(0.45, 0.75, 1.0, 1.0),
}
# 多元素同时解锁时,武器展示用此顺序的首个元素颜色。
var ELEMENT_PRIORITY := [ELEMENT_FIRE, ELEMENT_POISON, ELEMENT_FROST]

var enemies_layer: Node2D
var _unlocked_elements := {}
var _fire_explosion_cooldown := 0.0


func setup(enemy_container: Node2D) -> void:
	enemies_layer = enemy_container


func _process(delta: float) -> void:
	if _fire_explosion_cooldown > 0.0:
		_fire_explosion_cooldown = maxf(0.0, _fire_explosion_cooldown - delta)


func unlock_element(element_id: String) -> void:
	_unlocked_elements[element_id] = true


func is_element_unlocked(element_id: String) -> bool:
	return bool(_unlocked_elements.get(element_id, false))


# 查询某元素的显示色。
func get_element_color(element_id: String) -> Color:
	return Color(ELEMENT_COLORS.get(element_id, Color.WHITE))


# 当前武器应展示的主元素(按 ELEMENT_PRIORITY 取首个已解锁的);都没有则返回空串。
func get_dominant_element() -> String:
	for element_id in ELEMENT_PRIORITY:
		if is_element_unlocked(element_id):
			return element_id
	return ""


# 当前主元素的显示色;无元素时返回 default_color。
func get_dominant_element_color(default_color: Color = Color.WHITE) -> Color:
	var element_id := get_dominant_element()
	if element_id.is_empty():
		return default_color
	return get_element_color(element_id)


func apply_weapon_hit(target, base_damage: float, hit_position: Vector2, _source_tags := {}) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.take_damage(base_damage)
	_try_fire_explosion(hit_position)
	if target == null or not is_instance_valid(target) or target.hp <= 0.0:
		return
	_apply_on_hit_debuffs(target)


func _try_fire_explosion(center: Vector2) -> void:
	if not is_element_unlocked(ELEMENT_FIRE) or _fire_explosion_cooldown > 0.0 or enemies_layer == null:
		return
	_fire_explosion_cooldown = FIRE_EXPLOSION_COOLDOWN
	var radius_sq := FIRE_EXPLOSION_RADIUS * FIRE_EXPLOSION_RADIUS
	for child in enemies_layer.get_children():
		if child.is_in_group("enemy") and is_instance_valid(child) and child.hp > 0.0:
			if center.distance_squared_to(child.global_position) <= radius_sq:
				child.take_damage(FIRE_EXPLOSION_DAMAGE)
	# 美术表现:按爆炸范围闪一个红色圈,提示玩家爆炸覆盖区域。
	_spawn_explosion_flash(center)


func _spawn_explosion_flash(center: Vector2) -> void:
	var flash := ExplosionFlash.new()
	flash.radius = FIRE_EXPLOSION_RADIUS
	flash.color = ELEMENT_COLORS[ELEMENT_FIRE]
	flash.position = center
	enemies_layer.add_child(flash)


# 火属性爆炸的视觉提示:红色半透明圆 + 描边,0.35s 内放大并淡出后自动销毁。
class ExplosionFlash:
	extends Node2D

	var radius := 50.0
	var color := Color.RED

	func _ready() -> void:
		queue_redraw()
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.35))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, 3.0)


func _apply_on_hit_debuffs(target) -> void:
	if is_element_unlocked(ELEMENT_POISON):
		target.apply_debuff(
			ELEMENT_POISON,
			POISON_DURATION,
			POISON_DAMAGE_PER_SECOND,
			1.0
		)
	if is_element_unlocked(ELEMENT_FROST):
		target.apply_debuff(
			ELEMENT_FROST,
			FROST_DURATION,
			FROST_DAMAGE_PER_SECOND,
			FROST_SPEED_MULTIPLIER
		)
