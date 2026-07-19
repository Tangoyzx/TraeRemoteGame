class_name EnemyProjectile
extends Area2D

# 敌方子弹:由炮塔(Turret)发射,命中玩家后扣血并销毁。
# 与玩家 Projectile 区别:group 为 "enemy_projectile",颜色浅红,
# 只命中 player group,不命中其他敌人(避免炮塔误伤己方小怪)。

const BASE_RADIUS := 6.0
# 无元素时的默认弹体色(浅红粉),与玩家子弹暖黄区分。
const DEFAULT_COLOR := Color(1.0, 0.50, 0.50, 1.0)

var velocity := Vector2.ZERO
var damage := 100.0
var lifetime := 5.0
var radius := BASE_RADIUS


func _ready() -> void:
	add_to_group("enemy_projectile")
	_create_collision()
	area_entered.connect(_on_area_entered)
	queue_redraw()


func setup(
	start_position: Vector2,
	direction: Vector2,
	projectile_speed: float,
	projectile_damage: float,
	projectile_lifetime: float
) -> void:
	global_position = start_position
	velocity = direction.normalized() * projectile_speed
	damage = projectile_damage
	lifetime = projectile_lifetime
	queue_redraw()


func _process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


# 命中玩家:扣血并销毁子弹。玩家 take_damage 内部已处理无敌帧,
# 但无论是否真的扣血,子弹都销毁(避免无敌帧期间子弹穿身而过重复触发)。
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		area.take_damage(int(damage))
		queue_free()


func _create_collision() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, DEFAULT_COLOR)
