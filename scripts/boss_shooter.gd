class_name BossShooter
extends Boss

# 会开火的 Boss:继承 Boss 的移动逻辑(追玩家),同时像炮塔一样定时朝玩家发射子弹。
# 与炮塔区别:炮塔不移动(重写 _process 不追玩家);本类调用 super._process 保留移动。

const FIRE_INTERVAL := 1.5
const FIRE_RANGE := 1400.0
const PROJECTILE_SPEED := 250.0
# 子弹寿命 = 射程 / 速度,让子弹飞完射程就消失,避免无限飞行。
const PROJECTILE_LIFETIME := FIRE_RANGE / PROJECTILE_SPEED

var _fire_timer := 0.0
var _projectiles_layer: Node2D
var _projectile_scene


# 由 main.gd 在生成 boss 时注入:子弹挂载的 layer 和子弹场景(与炮塔一致)。
func setup_projectiles(layer: Node2D, projectile_scene) -> void:
	_projectiles_layer = layer
	_projectile_scene = projectile_scene


# 调用 super._process 继承 Enemy 的移动 + debuff 更新,再叠加开火逻辑。
func _process(delta: float) -> void:
	super(delta)
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
