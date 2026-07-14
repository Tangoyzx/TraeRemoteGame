class_name OrbitSword
extends Node2D

const StatMath := preload("res://scripts/stat_math.gd")

# 基线参数(随升级变化,参见 docs/skill-calibration.md §2)。
const BASE_DAMAGE := 100.0
const BASE_ORBIT_RADIUS := 186.0
const BASE_ORBIT_SPEED := 3.4
const BASE_SIZE := Vector2(52.0, 12.0)
const BASE_HIT_COOLDOWN := 0.45
# PIERCE 每层减少的命中冷却(秒)。
const PIERCE_COOLDOWN_REDUCTION_PER_STACK := 0.10

# 适配系数 k(详见 docs/skill-calibration.md §5)。
# SPEED 折叠进 FREQUENCY,故共用其 k;DURATION 折叠进 AREA 的剑长,半价 0.5。
var _K := {
	StatMath.Stat.COUNT: 1.0,
	StatMath.Stat.FREQUENCY: 0.95,
	StatMath.Stat.DAMAGE: 1.0,
	StatMath.Stat.AREA: 0.9,
	StatMath.Stat.PIERCE: 0.8,
	StatMath.Stat.DURATION: 0.5,
	StatMath.Stat.SPEED: 0.95,
}

var player
var combat_effects
var _angle := 0.0
var _blades: Array = []
var _stat_stacks := {}

# 当前参数(由 _recompute 从通用属性堆叠数推导)。
var _damage := BASE_DAMAGE
var _orbit_radius := BASE_ORBIT_RADIUS
var _orbit_speed := BASE_ORBIT_SPEED
var _size := BASE_SIZE
var _hit_cooldown := BASE_HIT_COOLDOWN
var _sword_count := 1


func _ready() -> void:
	add_to_group("weapon")
	_rebuild_blades()


func setup(owner_player, effect_controller = null) -> void:
	player = owner_player
	combat_effects = effect_controller
	for blade in _blades:
		blade.combat_effects = combat_effects


# 由 main 在 stat 升级时调用,传入该属性的当前堆叠数(绝对值)。
func apply_stat(stat: int, stacks: int) -> void:
	_stat_stacks[stat] = clampi(stacks, 0, StatMath.MAX_STACKS)
	_recompute()


func _recompute() -> void:
	# FREQUENCY + SPEED(折叠):转速。
	var freq := _stacks(StatMath.Stat.FREQUENCY)
	var spd := _stacks(StatMath.Stat.SPEED)
	var freq_mag := StatMath.total_multiplier(StatMath.Stat.FREQUENCY, freq) * _k(StatMath.Stat.FREQUENCY)
	var spd_mag := StatMath.total_multiplier(StatMath.Stat.SPEED, spd) * _k(StatMath.Stat.SPEED)
	_orbit_speed = BASE_ORBIT_SPEED * (1.0 + freq_mag + spd_mag)

	# DAMAGE。
	var dmg := _stacks(StatMath.Stat.DAMAGE)
	var dmg_mag := StatMath.total_multiplier(StatMath.Stat.DAMAGE, dmg) * _k(StatMath.Stat.DAMAGE)
	_damage = BASE_DAMAGE * (1.0 + dmg_mag)

	# AREA(半径 + 剑长) + DURATION(折叠进剑长)。
	var area := _stacks(StatMath.Stat.AREA)
	var dur := _stacks(StatMath.Stat.DURATION)
	var area_mag := StatMath.total_multiplier(StatMath.Stat.AREA, area) * _k(StatMath.Stat.AREA)
	var dur_mag := StatMath.total_multiplier(StatMath.Stat.DURATION, dur) * _k(StatMath.Stat.DURATION)
	_orbit_radius = BASE_ORBIT_RADIUS * (1.0 + area_mag)
	_size = BASE_SIZE * (1.0 + area_mag + dur_mag)

	# PIERCE:命中冷却 ↓。
	var pierce := _stacks(StatMath.Stat.PIERCE)
	var reduction := PIERCE_COOLDOWN_REDUCTION_PER_STACK * float(pierce) * _k(StatMath.Stat.PIERCE)
	_hit_cooldown = maxf(0.1, BASE_HIT_COOLDOWN - reduction)

	# COUNT:整数型,每层 +1 剑(均匀分布)。
	_sword_count = 1 + _stacks(StatMath.Stat.COUNT)

	_rebuild_blades()


func _rebuild_blades() -> void:
	for blade in _blades:
		blade.queue_free()
	_blades.clear()
	for i in _sword_count:
		var blade := SwordBlade.new()
		blade.setup(_size, _damage, _hit_cooldown, combat_effects)
		add_child(blade)
		_blades.append(blade)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_angle += _orbit_speed * delta
	var n := _blades.size()
	for i in n:
		var blade = _blades[i]
		var a := _angle + float(i) * TAU / float(n)
		blade.global_position = player.global_position + Vector2.RIGHT.rotated(a) * _orbit_radius
		blade.rotation = a + PI * 0.5
		blade.tick(delta)


func _stacks(stat: int) -> int:
	return int(_stat_stacks.get(stat, 0))


func _k(stat: int) -> float:
	return _K.get(stat, 1.0)


# 单把剑:自己的碰撞、绘制、命中冷却。
class SwordBlade:
	extends Area2D

	# 无元素时的默认剑身色(蓝白)。
	const DEFAULT_FILL := Color(0.88, 0.96, 1.0, 1.0)
	const DEFAULT_EDGE := Color(0.38, 0.78, 1.0, 1.0)

	var size := Vector2(52.0, 12.0)
	var damage := 100.0
	var hit_cooldown := 0.45
	var combat_effects
	var _hit_cooldowns := {}
	var _shape: RectangleShape2D
	# 缓存当前绘制色,仅在元素变化时触发 queue_redraw。
	var _cached_fill := DEFAULT_FILL
	var _cached_edge := DEFAULT_EDGE


	func _ready() -> void:
		_create_collision()
		area_entered.connect(_on_area_entered)
		queue_redraw()


	func setup(sz: Vector2, dmg: float, cd: float, effect_controller = null) -> void:
		size = sz
		damage = dmg
		hit_cooldown = cd
		combat_effects = effect_controller
		_refresh_color()


	func tick(delta: float) -> void:
		_update_hit_cooldowns(delta)
		_damage_overlapping_enemies()
		_refresh_color()


	# 按当前主元素刷新剑身色;变化时才触发重绘,避免每帧无谓 redraw。
	func _refresh_color() -> void:
		var fill: Color
		var edge: Color
		if combat_effects != null and is_instance_valid(combat_effects) and combat_effects.get_dominant_element() != "":
			var c := combat_effects.get_dominant_element_color()
			fill = Color(c.r, c.g, c.b, 1.0)
			edge = Color(c.r * 0.55, c.g * 0.55, c.b * 0.55, 1.0)
		else:
			fill = DEFAULT_FILL
			edge = DEFAULT_EDGE
		if fill != _cached_fill:
			_cached_fill = fill
			_cached_edge = edge
			queue_redraw()


	func _on_area_entered(area: Area2D) -> void:
		if area.is_in_group("enemy"):
			_try_hit_enemy(area)


	func _damage_overlapping_enemies() -> void:
		for area in get_overlapping_areas():
			if area.is_in_group("enemy"):
				_try_hit_enemy(area)


	func _try_hit_enemy(enemy) -> void:
		if enemy == null or not is_instance_valid(enemy):
			return
		var id: int = enemy.get_instance_id()
		if _hit_cooldowns.has(id):
			return
		if combat_effects != null and is_instance_valid(combat_effects):
			combat_effects.apply_weapon_hit(enemy, damage, enemy.global_position, {"source": "orbit_sword"})
		else:
			enemy.take_damage(damage)
		_hit_cooldowns[id] = hit_cooldown


	func _update_hit_cooldowns(delta: float) -> void:
		var expired := []
		for id in _hit_cooldowns.keys():
			_hit_cooldowns[id] -= delta
			if _hit_cooldowns[id] <= 0.0:
				expired.append(id)
		for id in expired:
			_hit_cooldowns.erase(id)


	func _create_collision() -> void:
		_shape = RectangleShape2D.new()
		_shape.size = size
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		collision.shape = _shape
		add_child(collision)


	func _draw() -> void:
		var rect := Rect2(-size * 0.5, size)
		draw_rect(rect, _cached_fill, true)
		draw_rect(rect, _cached_edge, false, 2.0)