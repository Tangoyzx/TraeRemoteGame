class_name Turret
extends Enemy

# 固定炮塔:继承 Enemy 的 hp/damage/take_damage/apply_debuff/died 机制,
# 但不移动(重写 _process 不调用父类的追玩家逻辑)。
# 当玩家进入射程内时,每隔 FIRE_INTERVAL 秒朝玩家方向发射一颗敌方子弹。
# 子弹射程由 lifetime * speed 决定,刚好覆盖 FIRE_RANGE 后自动销毁。

const FIRE_INTERVAL := 1.0
const FIRE_RANGE := 1280.0
const PROJECTILE_SPEED := 250.0
# 子弹寿命 = 射程 / 速度,让子弹飞完射程就消失,避免无限飞行。
const PROJECTILE_LIFETIME := FIRE_RANGE / PROJECTILE_SPEED

var _fire_timer := 0.0
var _projectiles_layer: Node2D
var _projectile_scene


func _ready() -> void:
	super()
	add_to_group("turret")


# 由 main.gd 在生成炮塔时注入:子弹挂载的 layer 和子弹场景。
func setup_projectiles(layer: Node2D, projectile_scene) -> void:
	_projectiles_layer = layer
	_projectile_scene = projectile_scene


# 重写 _process:不调用 super._process()(避免朝玩家移动),只做开火逻辑。
# 但保留 debuff 更新与重绘刷新(继承自父类)。
func _process(delta: float) -> void:
	_update_debuffs(delta)
	_refresh_debuff_redraw()
	if target == null or not is_instance_valid(target):
		return
	_fire_timer += delta
	if _fire_timer >= FIRE_INTERVAL:
		_fire_timer = 0.0
		_try_fire()


func _try_fire() -> void:
	if _projectiles_layer == null or _projectile_scene == null:
		return
	var to_target := target.global_position - global_position
	# 玩家超出射程不开火(节省子弹生成开销)
	if to_target.length() > FIRE_RANGE:
		return
	var projectile = _projectile_scene.new()
	projectile.setup(
		global_position,
		to_target.normalized(),
		PROJECTILE_SPEED,
		float(damage),
		PROJECTILE_LIFETIME
	)
	_projectiles_layer.add_child(projectile)


# 重写绘制:白色三角形(等边),大小约等于普通小怪(radius=18)。
# 三角形顶点朝上,与圆形普通小怪视觉区分。
# debuff 浅色滤镜叠在 body 之上,沿用父类 DEBUFF_TINTS 映射。
func _draw() -> void:
	var r := radius
	var pts := PackedVector2Array([
		Vector2(0.0, -r),
		Vector2(r * 0.866, r * 0.5),
		Vector2(-r * 0.866, r * 0.5),
	])
	draw_colored_polygon(pts, body_color)
	# 描边:polyline 闭合(末尾再回到首点)
	var outline_pts := PackedVector2Array(pts)
	outline_pts.append(pts[0])
	draw_polyline(outline_pts, outline_color, 2.0)
	# debuff 滤镜:同样以三角形叠加
	for debuff_id in DEBUFF_TINTS.keys():
		if _debuffs.has(debuff_id):
			draw_colored_polygon(pts, Color(DEBUFF_TINTS[debuff_id]))
