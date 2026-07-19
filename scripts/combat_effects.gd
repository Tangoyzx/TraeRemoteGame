class_name CombatEffects
extends Node

const ELEMENT_FIRE := "fire"
const ELEMENT_POISON := "poison"
const ELEMENT_FROST := "frost"
const ELEMENT_ELECTRIC := "electric"

const FIRE_EXPLOSION_RADIUS := 100.0
const FIRE_EXPLOSION_DAMAGE := 50.0
const FIRE_EXPLOSION_COOLDOWN := 5.0

const POISON_DAMAGE_PER_SECOND := 10.0
const POISON_DURATION := 5.0

const FROST_DAMAGE_PER_SECOND := 2.0
const FROST_DURATION := 5.0
const FROST_SPEED_MULTIPLIER := 0.5

# 电属性:命中后 50% 概率触发连锁闪电,索敌范围 100px,最多攻击 4 个敌人(含首个),每击 100 伤害。
const ELECTRIC_TRIGGER_CHANCE := 0.5
const ELECTRIC_CHAIN_RADIUS := 100.0
const ELECTRIC_CHAIN_MAX_TARGETS := 4
const ELECTRIC_DAMAGE := 100.0

# 元素 → 显示色映射(火=红、毒=绿、冰=蓝)。武器获得元素后会按此着色。
# 用 var 而非 const:const Dictionary 在 release 编译器里 .get()/[] 的值类型
# 无法静态推断为 Color,会导致依赖本脚本的 main.gd 编译失败。
var ELEMENT_COLORS := {
	ELEMENT_FIRE: Color(1.0, 0.32, 0.28, 1.0),
	ELEMENT_POISON: Color(0.40, 0.95, 0.40, 1.0),
	ELEMENT_FROST: Color(0.45, 0.75, 1.0, 1.0),
	ELEMENT_ELECTRIC: Color(1.0, 0.95, 0.20, 1.0),
}
# 多元素同时解锁时,武器展示用此顺序的首个元素颜色。
var ELEMENT_PRIORITY := [ELEMENT_FIRE, ELEMENT_POISON, ELEMENT_FROST, ELEMENT_ELECTRIC]

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
	_try_electric_chain(target, hit_position)
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


# 电属性连锁闪电:命中后 50% 概率触发,从首个目标开始向范围内最近的未访问敌人跳跃,
# 最多攻击 ELECTRIC_CHAIN_MAX_TARGETS 个敌人(含首个),每击 ELECTRIC_DAMAGE 伤害。
# 直接调用 take_damage 而非 apply_weapon_hit,避免递归触发火/毒/冰/电导致指数级伤害。
func _try_electric_chain(initial_target, hit_position: Vector2) -> void:
	if not is_element_unlocked(ELEMENT_ELECTRIC) or enemies_layer == null:
		return
	if randf() > ELECTRIC_TRIGGER_CHANCE:
		return

	var visited: Array = []
	var chain_positions: Array = []

	# 第一个目标:已被武器命中的敌人(若仍存活则受到电击伤害)
	if initial_target != null and is_instance_valid(initial_target) and initial_target.hp > 0.0:
		initial_target.take_damage(ELECTRIC_DAMAGE)
		visited.append(initial_target)
		chain_positions.append(initial_target.global_position)
	else:
		chain_positions.append(hit_position)

	# 后续跳跃:从上一个目标位置找范围内最近的未访问敌人
	var jumps_remaining := ELECTRIC_CHAIN_MAX_TARGETS - 1
	while jumps_remaining > 0:
		var from_pos: Vector2 = chain_positions.back()
		var next_target := _find_nearest_enemy_within(from_pos, ELECTRIC_CHAIN_RADIUS * ELECTRIC_CHAIN_RADIUS, visited)
		if next_target == null:
			break
		next_target.take_damage(ELECTRIC_DAMAGE)
		visited.append(next_target)
		chain_positions.append(next_target.global_position)
		jumps_remaining -= 1

	# 画闪电视觉:连接所有经过的位置
	if chain_positions.size() >= 2:
		_spawn_chain_flash(chain_positions)


# 在 center 的 radius_sq 范围内找最近的、未在 exclude_list 中出现过的存活敌人。
func _find_nearest_enemy_within(center: Vector2, radius_sq: float, exclude_list: Array) -> Node:
	var best: Node = null
	var best_dist_sq := radius_sq
	for child in enemies_layer.get_children():
		if child.is_in_group("enemy") and is_instance_valid(child) and child.hp > 0.0:
			if exclude_list.has(child):
				continue
			var d := center.distance_squared_to(child.global_position)
			if d <= best_dist_sq:
				best_dist_sq = d
				best = child
	return best


func _spawn_chain_flash(positions: Array) -> void:
	var flash := ChainFlash.new()
	var packed := PackedVector2Array()
	for pos in positions:
		packed.append(pos)
	flash.points = packed
	flash.color = ELEMENT_COLORS[ELEMENT_ELECTRIC]
	flash.position = Vector2.ZERO
	enemies_layer.add_child(flash)


# 电属性连锁闪电的视觉提示:黄色折线 + 中点抖动模拟闪电,0.25s 内淡出后自动销毁。
class ChainFlash:
	extends Node2D

	var points := PackedVector2Array()
	var color := Color.YELLOW

	func _ready() -> void:
		queue_redraw()
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		if points.size() < 2:
			return
		# 在每对相邻点之间插入一个中点并加横向抖动,模拟闪电锯齿状轨迹。
		var jagged := PackedVector2Array()
		for i in points.size():
			jagged.append(points[i])
			if i < points.size() - 1:
				var mid := (points[i] + points[i + 1]) * 0.5
				var dir := (points[i + 1] - points[i]).normalized()
				var perp := Vector2(-dir.y, dir.x)
				mid += perp * (randf() - 0.5) * 20.0
				jagged.append(mid)
		draw_polyline(jagged, color, 3.0)


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
