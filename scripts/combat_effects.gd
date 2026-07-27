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

# 电属性进阶升级:连锁闪电命中敌人时有概率触发麻痹 debuff。
# 麻痹:每秒扣 20 生命值 + 完全定身(speed_multiplier=0),持续 5 秒。
const ELECTRIC_PARALYSIS_TRIGGER_CHANCE := 0.4
const ELECTRIC_PARALYSIS_DAMAGE_PER_SECOND := 20.0
const ELECTRIC_PARALYSIS_DURATION := 5.0
const ELECTRIC_PARALYSIS_SPEED_MULTIPLIER := 0.0
const DEBUFF_ID_PARALYSIS := "paralysis"

# 电属性雷暴进阶升级:连锁闪电命中敌人时有概率在目标位置生成雷暴乌云。
# 乌云持续 10 秒,每 ELECTRIC_THUNDERSTORM_STRIKE_INTERVAL 秒自动劈离它最近的 1 个敌人,
# 造成 ELECTRIC_THUNDERSTORM_DAMAGE 伤害,不递归触发连锁。
# 索敌范围限制在 ELECTRIC_THUNDERSTORM_RANGE 内(= 子弹基础射程 SPEED×LIFETIME = 520×2.2 = 1144),
# 从乌云位置起算;范围内无敌人则本轮不劈(等下一拍)。
const ELECTRIC_THUNDERSTORM_TRIGGER_CHANCE := 0.4
const ELECTRIC_THUNDERSTORM_DURATION := 10.0
const ELECTRIC_THUNDERSTORM_DAMAGE := 100.0
const ELECTRIC_THUNDERSTORM_STRIKE_INTERVAL := 1.0
const ELECTRIC_THUNDERSTORM_RANGE := 1144.0

# 毒地进阶升级:毒属性 weapon hit 触发持续伤害时,有 POISON_POOL_TRIGGER_CHANCE 概率
# 在目标位置生成一个毒地。毒地保留 POISON_POOL_DURATION 秒,半径 POISON_POOL_RADIUS,
# 站在毒地上的敌方单位会被持续刷新毒属性 debuff(伤害/时长同基础毒),并额外受到
# POISON_POOL_SPEED_MULTIPLIER 的减速(独立 debuff,每帧刷新短时长,离开毒地立刻失效)。
const POISON_POOL_TRIGGER_CHANCE := 0.5
const POISON_POOL_RADIUS := 100.0
const POISON_POOL_DURATION := 5.0
const POISON_POOL_SPEED_MULTIPLIER := 0.7
# 减速 debuff 的单次时长:略大于一帧,保证每帧刷新时不会中断;离开毒地后很快失效。
const POISON_POOL_SLOW_DURATION := 0.25

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
# 毒地进阶升级是否已解锁(基础毒元素解锁后才可解锁此升级)。
var _poison_pool_unlocked := false
# 电属性麻痹进阶升级是否已解锁(基础电元素解锁后才可解锁此升级)。
var _electric_paralysis_unlocked := false
# 电属性雷暴进阶升级是否已解锁(基础电元素解锁后才可解锁此升级)。
var _electric_thunderstorm_unlocked := false


func setup(enemy_container: Node2D) -> void:
	enemies_layer = enemy_container


func _process(delta: float) -> void:
	if _fire_explosion_cooldown > 0.0:
		_fire_explosion_cooldown = maxf(0.0, _fire_explosion_cooldown - delta)


func unlock_element(element_id: String) -> void:
	_unlocked_elements[element_id] = true


func is_element_unlocked(element_id: String) -> bool:
	return bool(_unlocked_elements.get(element_id, false))


# 解锁毒地进阶升级。调用方需保证 poison 元素已解锁(由 main.gd 的升级池过滤保证)。
func unlock_poison_pool() -> void:
	_poison_pool_unlocked = true


func is_poison_pool_unlocked() -> bool:
	return _poison_pool_unlocked


# 解锁电属性麻痹进阶升级。调用方需保证 electric 元素已解锁(由 main.gd 的升级池过滤保证)。
func unlock_electric_paralysis() -> void:
	_electric_paralysis_unlocked = true


func is_electric_paralysis_unlocked() -> bool:
	return _electric_paralysis_unlocked


# 解锁电属性雷暴进阶升级。调用方需保证 electric 元素已解锁(由 main.gd 的升级池过滤保证)。
func unlock_electric_thunderstorm() -> void:
	_electric_thunderstorm_unlocked = true


func is_electric_thunderstorm_unlocked() -> bool:
	return _electric_thunderstorm_unlocked


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
# 若电属性麻痹进阶升级已解锁,每个被闪电命中的敌人额外有 ELECTRIC_PARALYSIS_TRIGGER_CHANCE
# 概率被附加麻痹 debuff(每秒扣血 + 完全定身,持续 ELECTRIC_PARALYSIS_DURATION 秒)。
# 若电属性雷暴进阶升级已解锁,每个被闪电命中的敌人额外有 ELECTRIC_THUNDERSTORM_TRIGGER_CHANCE
# 概率在目标位置生成雷暴乌云(持续电击范围内其他敌人,持续 ELECTRIC_THUNDERSTORM_DURATION 秒)。
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
		_try_apply_paralysis(initial_target)
		_try_spawn_thunderstorm_cloud(initial_target)
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
		_try_apply_paralysis(next_target)
		_try_spawn_thunderstorm_cloud(next_target)
		visited.append(next_target)
		chain_positions.append(next_target.global_position)
		jumps_remaining -= 1

	# 画闪电视觉:连接所有经过的位置
	if chain_positions.size() >= 2:
		_spawn_chain_flash(chain_positions)


# 电属性进阶升级:对被连锁闪电命中的目标按 ELECTRIC_PARALYSIS_TRIGGER_CHANCE 概率附加麻痹 debuff。
# 麻痹 debuff 由 enemy.gd 的 _update_debuffs/_get_speed_multiplier 统一驱动:
#   - 每秒扣 ELECTRIC_PARALYSIS_DAMAGE_PER_SECOND 生命值
#   - speed_multiplier=0.0 使目标完全定身(_get_speed_multiplier 取 min,与其他减速叠加时取最严)
# 直接 apply_debuff,不会递归触发 weapon hit。
func _try_apply_paralysis(target) -> void:
	if not _electric_paralysis_unlocked:
		return
	if target == null or not is_instance_valid(target) or target.hp <= 0.0:
		return
	if randf() > ELECTRIC_PARALYSIS_TRIGGER_CHANCE:
		return
	target.apply_debuff(
		DEBUFF_ID_PARALYSIS,
		ELECTRIC_PARALYSIS_DURATION,
		ELECTRIC_PARALYSIS_DAMAGE_PER_SECOND,
		ELECTRIC_PARALYSIS_SPEED_MULTIPLIER
	)


# 电属性雷暴进阶升级:对被连锁闪电命中的目标按 ELECTRIC_THUNDERSTORM_TRIGGER_CHANCE 概率
# 在目标位置生成一个雷暴乌云(ThunderCloud)。乌云持续 ELECTRIC_THUNDERSTORM_DURATION 秒,
# 每 ELECTRIC_THUNDERSTORM_STRIKE_INTERVAL 秒对范围内其他敌人造成 ELECTRIC_THUNDERSTORM_DAMAGE
# 伤害,并画一道闪电(BoltFlash)。乌云只调用 take_damage,不会递归触发 weapon hit / 连锁。
func _try_spawn_thunderstorm_cloud(target) -> void:
	if not _electric_thunderstorm_unlocked:
		return
	if target == null or not is_instance_valid(target) or target.hp <= 0.0:
		return
	if randf() > ELECTRIC_THUNDERSTORM_TRIGGER_CHANCE:
		return
	var cloud := ThunderCloud.new()
	cloud.duration = ELECTRIC_THUNDERSTORM_DURATION
	cloud.color = ELEMENT_COLORS[ELEMENT_ELECTRIC]
	cloud.position = target.global_position
	cloud.enemies_layer = enemies_layer
	cloud.strike_damage = ELECTRIC_THUNDERSTORM_DAMAGE
	cloud.strike_interval = ELECTRIC_THUNDERSTORM_STRIKE_INTERVAL
	cloud.strike_range = ELECTRIC_THUNDERSTORM_RANGE
	enemies_layer.add_child(cloud)


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
		# 毒属性触发持续伤害时,有概率在目标位置生成毒地。
		# 在 poison 已应用(且 target 仍存活)后再 roll,确保毒地只对仍存活的敌人生成。
		if is_instance_valid(target) and target.hp > 0.0:
			_try_spawn_poison_pool(target.global_position)
	if is_element_unlocked(ELEMENT_FROST):
		target.apply_debuff(
			ELEMENT_FROST,
			FROST_DURATION,
			FROST_DAMAGE_PER_SECOND,
			FROST_SPEED_MULTIPLIER
		)


# 毒地生成:50% 概率在 center 处生成一个 PoisonPool 节点(挂在 enemies_layer 上)。
# 与电属性连锁一样,直接生成视觉节点 + 在 _process 里 apply_debuff,不会递归触发 weapon hit。
func _try_spawn_poison_pool(center: Vector2) -> void:
	if not _poison_pool_unlocked or not is_element_unlocked(ELEMENT_POISON) or enemies_layer == null:
		return
	if randf() > POISON_POOL_TRIGGER_CHANCE:
		return
	var pool := PoisonPool.new()
	pool.radius = POISON_POOL_RADIUS
	pool.duration = POISON_POOL_DURATION
	pool.color = ELEMENT_COLORS[ELEMENT_POISON]
	pool.position = center
	pool.enemies_layer = enemies_layer
	pool.poison_damage_per_second = POISON_DAMAGE_PER_SECOND
	pool.poison_duration = POISON_DURATION
	pool.speed_multiplier = POISON_POOL_SPEED_MULTIPLIER
	pool.slow_duration = POISON_POOL_SLOW_DURATION
	enemies_layer.add_child(pool)


# 毒地:在 enemies_layer 上保留 duration 秒,半径 radius,绿色半透明圆 + 描边。
# 每帧对范围内所有存活敌人:
#   1) 刷新 poison debuff(伤害/时长同基础毒,slow=1.0 不影响速度)
#   2) 应用独立的 poison_pool 减速 debuff(slow=speed_multiplier,短时长,离开后立即失效)
# 用独立 debuff_id 是为了让减速只在毒地内生效,不被武器命中时的 poison(slow=1.0)覆盖掉。
# PoisonPool 不可写入 _unlocked_elements / 不递归 apply_weapon_hit,只调用 take_damage/apply_debuff。
class PoisonPool:
	extends Node2D

	var radius := 100.0
	var duration := 5.0
	var color := Color(0.40, 0.95, 0.40, 1.0)
	var enemies_layer: Node2D
	var poison_damage_per_second := 10.0
	var poison_duration := 5.0
	var speed_multiplier := 0.7
	var slow_duration := 0.25
	# debuff id 用常量,避免和 enemy.gd 的 DEBUFF_TINTS 字面量散落多处不一致。
	const DEBUFF_ID_POISON := "poison"
	const DEBUFF_ID_SLOW := "poison_pool"
	var _remaining := 0.0
	var _pulse_phase := 0.0


	func _ready() -> void:
		_remaining = duration
		queue_redraw()


	func _process(delta: float) -> void:
		_remaining -= delta
		_pulse_phase += delta
		if _remaining <= 0.0:
			queue_free()
			return
		queue_redraw()
		if enemies_layer == null:
			return
		var radius_sq := radius * radius
		for child in enemies_layer.get_children():
			if not child.is_in_group("enemy") or not is_instance_valid(child) or child.hp <= 0.0:
				continue
			if global_position.distance_squared_to(child.global_position) <= radius_sq:
				# 1) 刷新基础毒(伤害 + 5s 时长,slow=1.0 不影响速度)。
				child.apply_debuff(DEBUFF_ID_POISON, poison_duration, poison_damage_per_second, 1.0)
				# 2) 叠加毒地专属减速(独立 debuff,每帧刷新,离开毒地后 0.25s 内自动消失)。
				child.apply_debuff(DEBUFF_ID_SLOW, slow_duration, 0.0, speed_multiplier)


	func _draw() -> void:
		# 半透明绿色填充 + 描边,带轻微脉冲让玩家察觉这是持续效果。
		var pulse := 0.85 + 0.15 * sin(_pulse_phase * 6.0)
		var fill_alpha := 0.22 * pulse
		var edge_alpha := clampf(0.65 * pulse, 0.4, 0.85)
		draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, fill_alpha))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color.r, color.g, color.b, edge_alpha), 3.0)
		# 内圈描边:强调中心位置,便于玩家识别毒地生成点。
		draw_arc(Vector2.ZERO, radius * 0.5, 0.0, TAU, 32, Color(color.r, color.g, color.b, edge_alpha * 0.6), 2.0)


# 雷暴乌云:在 enemies_layer 上保留 duration 秒,每 strike_interval 秒自动劈离它最近的 1 个敌人,
# 造成 strike_damage 伤害,并画一道闪电(BoltFlash)。
# 索敌范围 = strike_range(从乌云位置起算),仅在该范围内找最近敌人;范围内无敌人则本轮不劈。
# 不递归触发连锁闪电/火/毒/冰,只调用 take_damage。
# 首次打击延迟一个 strike_interval,避免生成瞬间就劈(给玩家视觉缓冲)。
class ThunderCloud:
	extends Node2D

	# 乌云视觉半径(仅用于绘制,不影响索敌)。
	const CLOUD_VISUAL_RADIUS := 60.0

	var duration := 10.0
	var color := Color(1.0, 0.95, 0.20, 1.0)
	var enemies_layer: Node2D
	var strike_damage := 100.0
	var strike_interval := 1.0
	var strike_range := 1144.0
	var _remaining := 0.0
	var _strike_timer := 0.0
	var _pulse_phase := 0.0


	func _ready() -> void:
		_remaining = duration
		_strike_timer = strike_interval
		queue_redraw()


	func _process(delta: float) -> void:
		_remaining -= delta
		_pulse_phase += delta
		if _remaining <= 0.0:
			queue_free()
			return
		_strike_timer -= delta
		if _strike_timer <= 0.0:
			_strike_timer = strike_interval
			_strike_nearest_enemy()
		queue_redraw()


	# 在 strike_range 范围内(从乌云位置起算)找最近的存活敌人劈下;范围内无敌人则跳过本轮。
	func _strike_nearest_enemy() -> void:
		if enemies_layer == null:
			return
		var range_sq := strike_range * strike_range
		var best = null
		var best_dist_sq := range_sq
		for child in enemies_layer.get_children():
			if not child.is_in_group("enemy") or not is_instance_valid(child) or child.hp <= 0.0:
				continue
			var d := global_position.distance_squared_to(child.global_position)
			if d < best_dist_sq:
				best_dist_sq = d
				best = child
		if best == null:
			return
		best.take_damage(strike_damage)
		_spawn_bolt(best.global_position)


	func _spawn_bolt(target_position: Vector2) -> void:
		var bolt := BoltFlash.new()
		bolt.cloud_position = global_position
		bolt.target_positions = [target_position]
		bolt.color = color
		enemies_layer.add_child(bolt)


	func _draw() -> void:
		# 乌云主体:深灰紫色半透明圆,带脉冲让玩家察觉这是持续效果。
		var pulse := 0.85 + 0.15 * sin(_pulse_phase * 4.0)
		var cloud_fill := Color(0.20, 0.18, 0.28, 0.55 * pulse)
		var cloud_edge := Color(0.35, 0.32, 0.45, 0.75)
		draw_circle(Vector2.ZERO, CLOUD_VISUAL_RADIUS, cloud_fill)
		draw_arc(Vector2.ZERO, CLOUD_VISUAL_RADIUS, 0.0, TAU, 32, cloud_edge, 2.0)


# 雷暴乌云劈下的闪电视觉:从乌云位置到每个被击中敌人画一条锯齿折线,0.2s 内淡出后自动销毁。
# 节点挂在 enemies_layer 上(原点 = 世界原点),draw 时直接使用世界坐标。
class BoltFlash:
	extends Node2D

	var cloud_position := Vector2.ZERO
	var target_positions := []
	var color := Color.YELLOW


	func _ready() -> void:
		queue_redraw()
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)


	func _draw() -> void:
		for target in target_positions:
			_draw_jagged_line(cloud_position, Vector2(target))


	func _draw_jagged_line(from: Vector2, to: Vector2) -> void:
		# 在 from -> to 之间插入 4 段锯齿,垂直方向随机抖动模拟闪电轨迹。
		var jagged := PackedVector2Array()
		var segments := 4
		for i in range(segments + 1):
			var t := float(i) / float(segments)
			var p := from.lerp(to, t)
			if i > 0 and i < segments:
				var dir := (to - from).normalized()
				var perp := Vector2(-dir.y, dir.x)
				p += perp * (randf() - 0.5) * 18.0
			jagged.append(p)
		draw_polyline(jagged, color, 2.5)
