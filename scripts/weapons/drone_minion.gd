class_name DroneMinion
extends Node2D

const StatMath := preload("res://scripts/stat_math.gd")

# 基线参数(随升级变化,参见 docs/skill-calibration.md §2 DroneMinion)。
const BASE_SPAWN_INTERVAL := 2.0
const BASE_MAX_MINIONS := 1
const BASE_ORBIT_RADIUS := 150.0
const BASE_ORBIT_SPEED := 3.0
const BASE_DETECTION_RADIUS := 200.0
const BASE_EXPLOSION_RADIUS := 100.0
const BASE_EXPLOSION_DAMAGE := 100.0
const BASE_TRACK_SPEED := 320.0
const BASE_RETURN_SPEED := 360.0
# 追踪目标超出此距离视为追丢,回到玩家身边重新环绕。
const TRACK_LOSE_DISTANCE := 280.0

# 适配系数 k(详见 docs/skill-calibration.md §5)。
# DURATION 对 drone 禁用(由 main._build_stat_pool 过滤,不入池),不在此声明。
var _K := {
	StatMath.Stat.COUNT: 1.0,
	StatMath.Stat.FREQUENCY: 1.0,
	StatMath.Stat.DAMAGE: 1.0,
	StatMath.Stat.AREA: 0.85,
	StatMath.Stat.PIERCE: 0.8,
	StatMath.Stat.SPEED: 1.0,
}

var player
var enemies_layer: Node2D
var combat_effects
var _angle := 0.0
var _minions: Array = []
var _spawn_timer := 0.0
var _stat_stacks := {}

# 当前参数(由 _recompute 从通用属性堆叠数推导)。
var _spawn_interval := BASE_SPAWN_INTERVAL
var _max_minions := BASE_MAX_MINIONS
var _orbit_radius := BASE_ORBIT_RADIUS
var _orbit_speed := BASE_ORBIT_SPEED
var _detection_radius := BASE_DETECTION_RADIUS
var _explosion_radius := BASE_EXPLOSION_RADIUS
var _explosion_damage := BASE_EXPLOSION_DAMAGE
var _track_speed := BASE_TRACK_SPEED
var _pierce := 0


func _ready() -> void:
	add_to_group("weapon")


func setup(owner_player, enemy_container: Node2D, effect_controller = null) -> void:
	player = owner_player
	enemies_layer = enemy_container
	combat_effects = effect_controller
	for minion in _minions:
		minion.combat_effects = combat_effects


# 由 main 在 stat 升级时调用,传入该属性的当前堆叠数(绝对值)。
func apply_stat(stat: int, stacks: int) -> void:
	_stat_stacks[stat] = clampi(stacks, 0, StatMath.MAX_STACKS)
	_recompute()


func _recompute() -> void:
	# FREQUENCY:生成间隔 ↓。
	var freq := _stacks(StatMath.Stat.FREQUENCY)
	_spawn_interval = BASE_SPAWN_INTERVAL / (1.0 + StatMath.total_multiplier(StatMath.Stat.FREQUENCY, freq))

	# COUNT:整数型,每层 +1 小兵上限。
	_max_minions = BASE_MAX_MINIONS + _stacks(StatMath.Stat.COUNT)

	# DAMAGE:k=1.0。
	var dmg := _stacks(StatMath.Stat.DAMAGE)
	_explosion_damage = BASE_EXPLOSION_DAMAGE * (1.0 + StatMath.total_multiplier(StatMath.Stat.DAMAGE, dmg))

	# AREA:检测半径 + 爆炸半径(双收益,k=0.85 打折)。
	var area := _stacks(StatMath.Stat.AREA)
	var area_mag := StatMath.total_multiplier(StatMath.Stat.AREA, area) * _k(StatMath.Stat.AREA)
	_detection_radius = BASE_DETECTION_RADIUS * (1.0 + area_mag)
	_explosion_radius = BASE_EXPLOSION_RADIUS * (1.0 + area_mag)

	# SPEED:追踪速度 ↑。k=1.0。
	var spd := _stacks(StatMath.Stat.SPEED)
	_track_speed = BASE_TRACK_SPEED * (1.0 + StatMath.total_multiplier(StatMath.Stat.SPEED, spd))

	# PIERCE:整数型,每层 +1 次爆炸后存活。
	_pierce = _stacks(StatMath.Stat.PIERCE)

	# 同步给已存在的小兵(跳过本帧已 queue_free 但尚未从 _minions 清理的实例)。
	for minion in _minions:
		if is_instance_valid(minion):
			minion.sync_params(_detection_radius, _explosion_radius, _explosion_damage, _track_speed, _pierce, combat_effects)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_angle += _orbit_speed * delta
	# 清理已销毁的小兵(queue_free 后下一帧 is_instance_valid 变 false)。
	var alive := []
	for minion in _minions:
		if is_instance_valid(minion):
			alive.append(minion)
	_minions = alive
	# 生成倒计时:仅在有空位时推进;满员时重置,空位出现后从 0 开始计完整间隔。
	if _minions.size() < _max_minions:
		_spawn_timer += delta
		if _spawn_timer >= _spawn_interval:
			_spawn_timer = 0.0
			_spawn_minion()
	else:
		_spawn_timer = 0.0
	# 推进每个小兵的状态机。
	# 速度倍数:高 ID 小兵若与任意低 ID 小兵角距过近(< 60°)则降速 50%,避免环绕堆叠。
	var n := _minions.size()
	for i in n:
		var minion = _minions[i]
		var speed_mult := 1.0
		if i > 0 and n > 1:
			for j in i:
				var other = _minions[j]
				if is_instance_valid(other):
					var ang_diff := absf(angle_difference(minion._orbit_angle, other._orbit_angle))
					if ang_diff < deg_to_rad(60.0):
						speed_mult = 0.5
						break
		minion.tick(delta, player.global_position, _orbit_speed * speed_mult, _orbit_radius, enemies_layer)


func _spawn_minion() -> void:
	var minion := Minion.new()
	minion.setup(_detection_radius, _explosion_radius, _explosion_damage, _track_speed, _pierce, combat_effects, enemies_layer)
	add_child(minion)
	minion.global_position = player.global_position
	# 初始轨道角度:在现有小兵基础上均匀分布,避免与已有小兵同角度。
	var n_after := _minions.size() + 1
	minion._orbit_angle = _angle + float(n_after - 1) * TAU / float(n_after)
	_minions.append(minion)


func _stacks(stat: int) -> int:
	return int(_stat_stacks.get(stat, 0))


func _k(stat: int) -> float:
	return _K.get(stat, 1.0)


# 小兵:自己的状态机、碰撞、绘制、爆炸。
class Minion:
	extends Area2D

	# 无元素时的默认小兵色(蓝白,与 OrbitSword 同色系)。
	const DEFAULT_FILL := Color(0.88, 0.96, 1.0, 1.0)
	const DEFAULT_EDGE := Color(0.38, 0.78, 1.0, 1.0)
	const MINION_RADIUS := 14.0
	const STATE_ORBITING := 0
	const STATE_TRACKING := 1
	const STATE_RETURNING := 2

	var detection_radius := 100.0
	var explosion_radius := 100.0
	var explosion_damage := 100.0
	var track_speed := 320.0
	var pierce := 0  # 剩余可爆炸次数(0 = 炸完即销毁)。
	var combat_effects
	var enemies_layer: Node2D

	var _state := STATE_ORBITING
	var _target = null
	var _cached_fill := DEFAULT_FILL
	var _cached_edge := DEFAULT_EDGE
	var _shape: CircleShape2D
	var _orbit_angle := 0.0  # 小兵自己的轨道角度(由父节点初始化,ORBITING 时自行推进)


	func _ready() -> void:
		add_to_group("drone_minion")
		_create_collision()
		area_entered.connect(_on_area_entered)
		queue_redraw()


	func setup(det_r: float, expl_r: float, dmg: float, spd: float, p: int, effect_controller, enemies: Node2D) -> void:
		detection_radius = det_r
		explosion_radius = expl_r
		explosion_damage = dmg
		track_speed = spd
		pierce = p
		combat_effects = effect_controller
		enemies_layer = enemies
		_refresh_color()


	# stat 升级时父节点同步参数到已存在的小兵。
	func sync_params(det_r: float, expl_r: float, dmg: float, spd: float, p: int, effect_controller) -> void:
		detection_radius = det_r
		explosion_radius = expl_r
		explosion_damage = dmg
		track_speed = spd
		pierce = p
		combat_effects = effect_controller
		_refresh_color()


	# 由父节点每帧调用:推进状态机,并检查是否已 overlap 敌人(补偿 area_entered 时序)。
	# orbit_speed 为该小兵本帧的轨道角速度(父节点按需降速以避免多小兵堆叠)。
	func tick(delta: float, player_pos: Vector2, orbit_speed: float, orbit_radius: float, enemies: Node2D) -> void:
		enemies_layer = enemies
		_update_state(delta, player_pos, orbit_speed, orbit_radius)
		if _state == STATE_TRACKING or _state == STATE_RETURNING:
			_check_overlap_explosion()
		_refresh_color()


	func _update_state(delta: float, player_pos: Vector2, orbit_speed: float, orbit_radius: float) -> void:
		match _state:
			STATE_ORBITING:
				_orbit_angle += orbit_speed * delta
				global_position = player_pos + Vector2.RIGHT.rotated(_orbit_angle) * orbit_radius
				_target = _find_nearest_enemy_within(detection_radius)
				if _target != null:
					_state = STATE_TRACKING
			STATE_TRACKING:
				# 仅当目标失效(死亡/销毁)时才返回;不再因离玩家太远而中断追踪。
				if _target == null or not is_instance_valid(_target) or _target.hp <= 0.0:
					_target = null
					_state = STATE_RETURNING
					return
				var to_target: Vector2 = _target.global_position - global_position
				if to_target.length() > 1.0:
					global_position += to_target.normalized() * track_speed * delta
			STATE_RETURNING:
				# 朝环绕圈上该小兵对应的角度位置移动,而不是冲向玩家中心。
				# 到达后切换到 ORBITING 时位置天然吻合,避免闪现。
				# RETURNING 不主动索敌(避免与 TRACKING 频繁切换导致抖动),但碰到敌人仍会爆炸
				# (见 _on_area_entered / _check_overlap_explosion)。
				var orbit_pos: Vector2 = player_pos + Vector2.RIGHT.rotated(_orbit_angle) * orbit_radius
				var to_orbit: Vector2 = orbit_pos - global_position
				var dist_to_orbit := to_orbit.length()
				var step := DroneMinion.BASE_RETURN_SPEED * delta
				if dist_to_orbit <= step + 1.0:
					global_position = orbit_pos
					_state = STATE_ORBITING
				else:
					global_position += to_orbit.normalized() * step


	# 在 detection_radius 内找最近的敌人(以小兵自己为中心)。
	func _find_nearest_enemy_within(radius: float):
		if enemies_layer == null:
			return null
		var best = null
		var best_dist_sq := radius * radius
		for child in enemies_layer.get_children():
			if child.is_in_group("enemy") and is_instance_valid(child) and child.hp > 0.0:
				var d := global_position.distance_squared_to(child.global_position)
				if d <= best_dist_sq:
					best_dist_sq = d
					best = child
		return best


	func _on_area_entered(area: Area2D) -> void:
		# TRACKING 主动追击、RETURNING 专心回归不索敌,但碰到了仍要爆炸。
		if (_state == STATE_TRACKING or _state == STATE_RETURNING) and area.is_in_group("enemy") and is_instance_valid(area):
			_explode(area)


	# 补偿:area_entered 只在首次进入时触发,TRACKING/RETURNING 时每帧检查是否已重叠。
	func _check_overlap_explosion() -> void:
		for area in get_overlapping_areas():
			if area.is_in_group("enemy") and is_instance_valid(area):
				_explode(area)
				return


	# 范围伤害:首个被碰撞目标(primary)吃全额,范围内其他敌人吃半额。
	func _explode(primary_target = null) -> void:
		if enemies_layer != null:
			var radius_sq := explosion_radius * explosion_radius
			var secondary_damage := explosion_damage * 0.5
			for child in enemies_layer.get_children():
				if child.is_in_group("enemy") and is_instance_valid(child) and child.hp > 0.0:
					if global_position.distance_squared_to(child.global_position) <= radius_sq:
						var dmg := explosion_damage if child == primary_target else secondary_damage
						if combat_effects != null and is_instance_valid(combat_effects):
							combat_effects.apply_weapon_hit(child, dmg, global_position, {"source": "drone_minion"})
						else:
							child.take_damage(dmg)
		_spawn_explosion_flash()
		# PIERCE:还能再炸几次?不能则销毁。
		if pierce > 0:
			pierce -= 1
			_state = STATE_RETURNING
		else:
			queue_free()


	func _spawn_explosion_flash() -> void:
		var flash := ExplosionFlash.new()
		flash.radius = explosion_radius
		flash.color = _current_edge_color()
		flash.position = global_position
		if enemies_layer != null:
			enemies_layer.add_child(flash)


	func _current_edge_color() -> Color:
		if combat_effects != null and is_instance_valid(combat_effects) and combat_effects.get_dominant_element() != "":
			return combat_effects.get_dominant_element_color(DEFAULT_EDGE)
		return DEFAULT_EDGE


	# 按当前主元素刷新小兵色;变化时才触发重绘,避免每帧无谓 redraw。
	func _refresh_color() -> void:
		var fill := DEFAULT_FILL
		var edge := DEFAULT_EDGE
		if combat_effects != null and is_instance_valid(combat_effects) and combat_effects.get_dominant_element() != "":
			var c: Color = combat_effects.get_dominant_element_color(Color.WHITE)
			fill = Color(c.r, c.g, c.b, 1.0)
			edge = Color(c.r * 0.55, c.g * 0.55, c.b * 0.55, 1.0)
		if fill != _cached_fill:
			_cached_fill = fill
			_cached_edge = edge
			queue_redraw()


	func _create_collision() -> void:
		_shape = CircleShape2D.new()
		_shape.radius = MINION_RADIUS
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		collision.shape = _shape
		add_child(collision)


	func _draw() -> void:
		# 小兵本体:实心圆 + 描边 + 中心点。
		draw_circle(Vector2.ZERO, MINION_RADIUS, _cached_fill)
		draw_arc(Vector2.ZERO, MINION_RADIUS, 0.0, TAU, 32, _cached_edge, 2.0)
		draw_circle(Vector2.ZERO, MINION_RADIUS * 0.4, _cached_edge)


	# 爆炸视觉:半透明圆 + 描边,0.35s 内放大并淡出后自动销毁。
	# 与 combat_effects.ExplosionFlash 实现一致,但用小兵自己的颜色。
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
