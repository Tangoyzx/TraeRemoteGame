extends Node2D

const PlayerScene := preload("res://scripts/player.gd")
const EnemyScene := preload("res://scripts/enemy.gd")
const ProjectileScene := preload("res://scripts/projectile.gd")
const CombatEffectsScene := preload("res://scripts/combat_effects.gd")
const StatMath := preload("res://scripts/stat_math.gd")
const AutoShooterScene := preload("res://scripts/weapons/auto_shooter.gd")
const OrbitSwordScene := preload("res://scripts/weapons/orbit_sword.gd")
const DroneMinionScene := preload("res://scripts/weapons/drone_minion.gd")
const BossScene := preload("res://scripts/boss.gd")
const BossIntroScene := preload("res://scripts/boss_intro.gd")

const VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const MAP_SIZE := Vector2(12800.0, 7200.0)
const MAP_RECT := Rect2(Vector2.ZERO, MAP_SIZE)
# 各等级升级所需累计积分(下标 = 等级 - 1)。超出此列表的等级不再触发升级。
const LEVEL_REQUIRED_SCORES := [0, 20, 200, 99999]
# 游戏版本号,显示在屏幕顶部居中。
# 规则:合并到远端 main 前,若无特殊说明则末位自动 +1(如 1.0.0 → 1.0.1)。
const GAME_VERSION := "v1.1.10"
const UPGRADE_IMAGE_SIZE := Vector2(100.0, 200.0)
const BASIC_ENEMY_RADIUS := 18.0
const BASIC_ENEMY_SPEED := 115.0
const ENEMY_CONFIGS := {
	"basic": {
		"name": "Basic",
		"radius": BASIC_ENEMY_RADIUS,
		"max_hp": 100.0,
		"damage": 100,
		"speed": BASIC_ENEMY_SPEED,
		"score_value": 1,
		"body_color": Color(0.92, 0.20, 0.20, 1.0),
		"outline_color": Color(1.0, 0.68, 0.68, 1.0),
	},
	"chubby": {
		"name": "Chubby",
		"radius": BASIC_ENEMY_RADIUS * 1.2,
		"max_hp": 300.0,
		"damage": 200,
		"speed": BASIC_ENEMY_SPEED * 0.8,
		"score_value": 2,
		"body_color": Color(0.80, 0.34, 0.95, 1.0),
		"outline_color": Color(0.96, 0.75, 1.0, 1.0),
	},
}
const SPAWN_STRATEGY := [
	{
		"start_time": 0.0,
		"rates": {
			"basic": 20.0,
		},
	},
	{
		"start_time": 20.0,
		"rates": {
			"basic": 40.0,
		},
	},
	{
		"start_time": 40.0,
		"rates": {
			"basic": 40.0,
			"chubby": 10.0,
		},
	},
	{
		"start_time": 60.0,
		"rates": {
			"basic": 40.0,
			"chubby": 10.0,
		},
	},
]
# Boss 配置表:每个 boss 类型携带独立数值。
# 玩家:RADIUS=20, SPEED=230, MAX_HP=300。Big Brother 按 3x 体型 / 25% 速度。
const BOSS_CONFIGS := {
	"big_brother": {
		"boss_name": "Big Brother",
		"radius": 60.0,        # 玩家 20 * 3
		"max_hp": 2000.0,
		"damage": 300,
		"speed": 57.5,         # 玩家 230 * 25%
		"score_value": 50,
		"body_color": Color(0.75, 0.18, 0.22, 1.0),
		"outline_color": Color(1.0, 0.55, 0.55, 1.0),
	},
}
# Boss 生成池:每次到点从池中随机选一个生成。
const BOSS_SPAWN_POOL := ["big_brother"]
# Boss 生成时机:第一个 boss 在游戏开始后 BOSS_FIRST_SPAWN_DELAY 秒生成
# (相当于把第 0 秒当作"上一只 boss 刚死");之后每只 boss 死亡后再过
# BOSS_NEXT_SPAWN_DELAY 秒生成下一只,同一时间最多存在一只 boss。
const BOSS_FIRST_SPAWN_DELAY := 60.0
const BOSS_NEXT_SPAWN_DELAY := 180.0
const BOSS_SPAWN_DISTANCE := 360.0  # 生成在玩家可见区外此距离处
const UPGRADE_OPTIONS := {
	"auto_shooter": {
		"id": "auto_shooter",
		"title": "Bullet",
		"description": "Auto-targets nearest enemy",
		"image_path": "res://assets/upgrades/bullet.svg",
		"weapon_type": "auto_shooter",
	},
	"orbit_sword": {
		"id": "orbit_sword",
		"title": "Orbit Sword",
		"description": "Orbits player, damages enemies",
		"image_path": "res://assets/upgrades/orbit_sword.svg",
		"weapon_type": "orbit_sword",
	},
	"drone_minion": {
		"id": "drone_minion",
		"title": "Drone Minion",
		"description": "Spawns minion that tracks and explodes on enemies",
		"image_path": "res://assets/upgrades/drone_minion.svg",
		"weapon_type": "drone_minion",
	},
}
# 通用 stat 升级定义。weight 控制加权随机投放(详见 docs/skill-system-framework.md §8)。
# desc 仅作为无武器解锁时的兜底;有武器时改用 _build_stat_description 按已解锁武器动态拼接。
var stat_upgrade_defs := [
	{"id": "stat_frequency", "stat": StatMath.Stat.FREQUENCY, "title": "Frequency", "desc": "Lower bullet cooldown / faster sword spin", "weight": 100},
	{"id": "stat_damage", "stat": StatMath.Stat.DAMAGE, "title": "Damage", "desc": "Increase damage per hit", "weight": 100},
	{"id": "stat_area", "stat": StatMath.Stat.AREA, "title": "Area", "desc": "Increase bullet/sword size", "weight": 60},
	{"id": "stat_duration", "stat": StatMath.Stat.DURATION, "title": "Duration", "desc": "Longer bullet life / longer sword", "weight": 60},
	{"id": "stat_speed", "stat": StatMath.Stat.SPEED, "title": "Speed", "desc": "Faster bullets / faster sword spin", "weight": 60},
	{"id": "stat_count", "stat": StatMath.Stat.COUNT, "title": "Count", "desc": "+1 bullet (multi-target) / +1 sword", "weight": 35},
	{"id": "stat_pierce", "stat": StatMath.Stat.PIERCE, "title": "Pierce", "desc": "Bullets pierce more / sword cooldown down", "weight": 35},
]
# stat × weapon_type → 该 stat 对该武器的具体效果文案。
# 用 var 而非 const:避免 release 编译器对嵌套 Dictionary 的 enum key 类型推断失败。
# DURATION 对 drone_minion 无意义(不入池),故此处不列 drone_minion 的 DURATION 条目。
var STAT_DESC_PER_WEAPON := {
	StatMath.Stat.FREQUENCY: {
		"auto_shooter": "Bullet cooldown down",
		"orbit_sword": "Faster sword spin",
		"drone_minion": "Faster minion spawn",
	},
	StatMath.Stat.DAMAGE: {
		"auto_shooter": "+bullet damage",
		"orbit_sword": "+sword damage",
		"drone_minion": "+explosion damage",
	},
	StatMath.Stat.AREA: {
		"auto_shooter": "Bigger bullet",
		"orbit_sword": "Bigger sword + orbit radius",
		"drone_minion": "Larger detection + explosion radius",
	},
	StatMath.Stat.DURATION: {
		"auto_shooter": "Longer bullet life",
		"orbit_sword": "Longer sword",
	},
	StatMath.Stat.SPEED: {
		"auto_shooter": "Faster bullets",
		"orbit_sword": "Faster sword spin",
		"drone_minion": "Faster minion tracking",
	},
	StatMath.Stat.COUNT: {
		"auto_shooter": "+1 bullet (multi-target)",
		"orbit_sword": "+1 sword",
		"drone_minion": "+1 minion slot",
	},
	StatMath.Stat.PIERCE: {
		"auto_shooter": "Bullets pierce more",
		"orbit_sword": "Sword hit cooldown down",
		"drone_minion": "Minion survives +1 explosion",
	},
}
const ENEMY_SPAWN_MARGIN := 140.0
const MAX_ENEMIES := 120
var element_upgrade_defs := [
	{"id": "element_fire", "element": "fire", "title": "Fire", "desc": "On hit: explode for 50 damage in 100px radius. 5s cooldown.", "weight": 45},
	{"id": "element_poison", "element": "poison", "title": "Poison", "desc": "On hit: poison for 10 damage/sec over 5s. Reapply resets duration.", "weight": 45},
	{"id": "element_frost", "element": "frost", "title": "Frost", "desc": "On hit: frostbite for 2 damage/sec and 50% slow over 5s. Reapply resets duration.", "weight": 45},
]

var player
var camera: Camera2D
var world_layer: Node2D
var enemies_layer: Node2D
var projectiles_layer: Node2D
var weapons_layer: Node2D
var ui_layer: CanvasLayer
var combat_effects
var score_label: Label
var level_label: Label
var version_label: Label
var game_over_label: Label
var level_up_overlay: ColorRect
var level_up_title: Label
var level_up_options_box: HBoxContainer
var score := 0
var current_level := 0
var is_game_over := false
var is_level_up_open := false
var elapsed_seconds := 0.0
var _spawn_budgets := {}
var _acquired_upgrades := {}
var _stat_stacks := {}
var _unlocked_weapons := []
var _boss_intro
var _boss_name_label: Label
# 当前存活 boss 引用;为空表示当前没有 boss。
var _active_boss = null
# 下一个 boss 的生成时间(基于 elapsed_seconds)。
var _next_boss_spawn_time := BOSS_FIRST_SPAWN_DELAY
# Boss 血条 UI(屏幕顶部居中)。
var _boss_health_container: CenterContainer
var _boss_health_name_label: Label
var _boss_health_bar: ProgressBar


func _ready() -> void:
	randomize()
	get_tree().paused = false
	_init_spawn_budgets()
	_build_world()
	_build_combat_effects()
	_spawn_player()
	_build_ui()
	_update_score_label()
	_update_level_label()
	_check_level_up()


func _unhandled_input(event: InputEvent) -> void:
	if is_game_over or is_level_up_open or player == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_set_player_target(get_global_mouse_position())
	elif event is InputEventScreenTouch and event.pressed:
		_set_player_target(get_canvas_transform().affine_inverse() * event.position)


func _process(delta: float) -> void:
	if is_game_over or is_level_up_open:
		return
	elapsed_seconds += delta
	if camera != null and player != null:
		camera.global_position = _clamp_to_map(player.global_position)
	_update_enemy_spawns(delta)
	_update_boss_spawns()
	_update_boss_health_bar()


func _build_world() -> void:
	world_layer = Node2D.new()
	world_layer.name = "World"
	add_child(world_layer)
	world_layer.add_child(_create_map_background())
	world_layer.add_child(_create_map_grid())
	world_layer.add_child(_create_map_border())

	enemies_layer = Node2D.new()
	enemies_layer.name = "Enemies"
	add_child(enemies_layer)

	projectiles_layer = Node2D.new()
	projectiles_layer.name = "Projectiles"
	add_child(projectiles_layer)

	weapons_layer = Node2D.new()
	weapons_layer.name = "Weapons"
	add_child(weapons_layer)

	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.enabled = true
	camera.zoom = Vector2.ONE
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(MAP_SIZE.x)
	camera.limit_bottom = int(MAP_SIZE.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0
	add_child(camera)


func _create_map_background() -> Node2D:
	var background := MapBackground.new()
	background.name = "MapBackground"
	background.map_size = MAP_SIZE
	return background


func _create_map_grid() -> Node2D:
	var grid := MapGrid.new()
	grid.name = "MapGrid"
	grid.map_size = MAP_SIZE
	grid.cell_size = 320.0
	return grid


func _create_map_border() -> Node2D:
	var border := MapBorder.new()
	border.name = "MapBorder"
	border.map_size = MAP_SIZE
	return border


func _build_combat_effects() -> void:
	combat_effects = CombatEffectsScene.new()
	combat_effects.name = "CombatEffects"
	combat_effects.setup(enemies_layer)
	add_child(combat_effects)


func _spawn_player() -> void:
	player = PlayerScene.new()
	player.name = "Player"
	player.global_position = MAP_SIZE * 0.5
	player.map_rect = MAP_RECT
	player.died.connect(_on_player_died)
	add_child(player)
	camera.global_position = player.global_position


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)

	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.position = Vector2(24, 20)
	score_label.add_theme_font_size_override("font_size", 32)
	ui_layer.add_child(score_label)

	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.position = Vector2(24, 60)
	level_label.add_theme_font_size_override("font_size", 28)
	ui_layer.add_child(level_label)

	version_label = Label.new()
	version_label.name = "VersionLabel"
	version_label.text = GAME_VERSION
	version_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	version_label.offset_top = 14.0
	version_label.offset_bottom = 44.0
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 20)
	ui_layer.add_child(version_label)

	game_over_label = Label.new()
	game_over_label.name = "GameOverLabel"
	game_over_label.visible = false
	game_over_label.text = "GAME OVER"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 72)
	game_over_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(game_over_label)

	# Boss 出场名字:屏幕正中央,过场期间显示,需 ALWAYS 才能在暂停时显示
	_boss_name_label = Label.new()
	_boss_name_label.name = "BossNameLabel"
	_boss_name_label.visible = false
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_name_label.add_theme_font_size_override("font_size", 64)
	_boss_name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_name_label.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(_boss_name_label)

	_build_boss_health_bar()

	_build_level_up_ui()


func _build_level_up_ui() -> void:
	level_up_overlay = ColorRect.new()
	level_up_overlay.name = "LevelUpOverlay"
	level_up_overlay.visible = false
	level_up_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	level_up_overlay.color = Color(0.0, 0.0, 0.0, 0.70)
	level_up_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_up_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(level_up_overlay)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	level_up_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(720, 390)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	content.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_child(content)

	level_up_title = Label.new()
	level_up_title.name = "Title"
	level_up_title.text = "Level Up! Choose an Upgrade"
	level_up_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_up_title.add_theme_font_size_override("font_size", 34)
	content.add_child(level_up_title)

	level_up_options_box = HBoxContainer.new()
	level_up_options_box.name = "Options"
	level_up_options_box.alignment = BoxContainer.ALIGNMENT_CENTER
	level_up_options_box.add_theme_constant_override("separation", 28)
	level_up_options_box.process_mode = Node.PROCESS_MODE_ALWAYS
	content.add_child(level_up_options_box)


# Boss 血条:屏幕顶部居中,显示当前存活 boss 的名字与血量。
# process_mode = ALWAYS,确保 boss 过场暂停期间血条仍可见。
func _build_boss_health_bar() -> void:
	_boss_health_container = CenterContainer.new()
	_boss_health_container.name = "BossHealthContainer"
	_boss_health_container.visible = false
	_boss_health_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_health_container.offset_top = 64.0
	_boss_health_container.offset_bottom = 130.0
	_boss_health_container.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(_boss_health_container)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 4)
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS
	_boss_health_container.add_child(vbox)

	_boss_health_name_label = Label.new()
	_boss_health_name_label.name = "BossName"
	_boss_health_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_health_name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_boss_health_name_label)

	_boss_health_bar = ProgressBar.new()
	_boss_health_bar.name = "HealthBar"
	_boss_health_bar.custom_minimum_size = Vector2(420, 22)
	_boss_health_bar.min_value = 0.0
	_boss_health_bar.max_value = 100.0
	_boss_health_bar.value = 100.0
	_boss_health_bar.show_percentage = false
	_boss_health_bar.process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.08, 0.88)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.0, 0.0, 0.0, 0.9)
	bg.set_corner_radius_all(4)
	_boss_health_bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.18, 0.22, 1.0)
	fill.set_corner_radius_all(3)
	_boss_health_bar.add_theme_stylebox_override("fill", fill)
	vbox.add_child(_boss_health_bar)


func _show_boss_health_bar(boss) -> void:
	if _boss_health_container == null or boss == null:
		return
	_boss_health_name_label.text = str(boss.boss_name)
	_boss_health_bar.max_value = float(boss.max_hp)
	_boss_health_bar.value = float(boss.hp)
	_boss_health_container.visible = true


func _hide_boss_health_bar() -> void:
	if _boss_health_container != null:
		_boss_health_container.visible = false


# 每帧同步血条数值;boss 失效时自动隐藏(兜底,正常死亡走 _on_boss_died)。
func _update_boss_health_bar() -> void:
	if _boss_health_container == null or not _boss_health_container.visible:
		return
	if _active_boss == null or not is_instance_valid(_active_boss):
		_hide_boss_health_bar()
		return
	_boss_health_bar.value = float(_active_boss.hp)


func _init_spawn_budgets() -> void:
	for enemy_type in ENEMY_CONFIGS.keys():
		_spawn_budgets[enemy_type] = 0.0


func _update_enemy_spawns(delta: float) -> void:
	if player == null or enemies_layer == null or enemies_layer.get_child_count() >= MAX_ENEMIES:
		return
	var rates := _get_current_spawn_rates()
	for enemy_type in rates.keys():
		if not ENEMY_CONFIGS.has(enemy_type):
			continue
		_spawn_budgets[enemy_type] = float(_spawn_budgets.get(enemy_type, 0.0)) + float(rates[enemy_type]) / 60.0 * delta
		while _spawn_budgets[enemy_type] >= 1.0 and enemies_layer.get_child_count() < MAX_ENEMIES:
			_spawn_enemy(enemy_type)
			_spawn_budgets[enemy_type] -= 1.0


func _get_current_spawn_rates() -> Dictionary:
	var current_rates := {}
	for phase in SPAWN_STRATEGY:
		if elapsed_seconds >= float(phase["start_time"]):
			current_rates = phase["rates"]
		else:
			break
	return current_rates


func _spawn_enemy(enemy_type: String) -> void:
	if is_game_over or player == null or enemies_layer.get_child_count() >= MAX_ENEMIES:
		return
	var enemy := EnemyScene.new()
	enemy.apply_config(ENEMY_CONFIGS[enemy_type])
	enemy.global_position = _get_spawn_position_near_view()
	enemy.target = player
	enemy.died.connect(_on_enemy_died)
	enemies_layer.add_child(enemy)


func _get_spawn_position_near_view() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = VIEWPORT_SIZE
	var center: Vector2 = camera.get_screen_center_position() if camera != null else player.global_position
	var half := viewport_size * 0.5
	var side := randi() % 4
	var spawn: Vector2 = center
	match side:
		0:
			spawn.x = center.x - half.x - ENEMY_SPAWN_MARGIN
			spawn.y = randf_range(center.y - half.y, center.y + half.y)
		1:
			spawn.x = center.x + half.x + ENEMY_SPAWN_MARGIN
			spawn.y = randf_range(center.y - half.y, center.y + half.y)
		2:
			spawn.x = randf_range(center.x - half.x, center.x + half.x)
			spawn.y = center.y - half.y - ENEMY_SPAWN_MARGIN
		_:
			spawn.x = randf_range(center.x - half.x, center.x + half.x)
			spawn.y = center.y + half.y + ENEMY_SPAWN_MARGIN
	return _clamp_to_map(spawn)


func _set_player_target(world_position: Vector2) -> void:
	player.set_move_target(_clamp_to_map(world_position))


func _clamp_to_map(world_position: Vector2) -> Vector2:
	return Vector2(
		clampf(world_position.x, MAP_RECT.position.x, MAP_RECT.end.x),
		clampf(world_position.y, MAP_RECT.position.y, MAP_RECT.end.y)
	)


func _on_enemy_died(enemy) -> void:
	score += enemy.score_value
	_update_score_label()
	_check_level_up()


# === Boss 生成与出场过场 ===
# 第一个 boss 在游戏开始 BOSS_FIRST_SPAWN_DELAY 秒后生成;之后每只 boss
# 死亡后再过 BOSS_NEXT_SPAWN_DELAY 秒生成下一只。过场进行中或仍有 boss
# 存活时不安排新生成,避免同时出现多只 boss。
func _update_boss_spawns() -> void:
	if _boss_intro != null:
		return
	# 当前还有 boss 存活,不安排新的生成
	if _active_boss != null and is_instance_valid(_active_boss):
		return
	if _active_boss != null:
		# 引用已失效但未清理:做兜底,等下一帧再判断
		_active_boss = null
	if elapsed_seconds < _next_boss_spawn_time:
		return
	if BOSS_SPAWN_POOL.is_empty():
		return
	var boss_type: String = str(BOSS_SPAWN_POOL[randi() % BOSS_SPAWN_POOL.size()])
	_spawn_boss(boss_type)


func _spawn_boss(boss_type: String) -> void:
	if not BOSS_CONFIGS.has(boss_type):
		return
	var boss = BossScene.new()
	boss.apply_config(BOSS_CONFIGS[boss_type])
	boss.global_position = _get_boss_spawn_position()
	boss.target = player
	boss.died.connect(_on_enemy_died)
	boss.died.connect(_on_boss_died)
	enemies_layer.add_child(boss)
	_active_boss = boss
	_show_boss_health_bar(boss)
	# 启动过场:暂停全树 → 镜头缓动到 boss → 显示名字+震动 → 回到玩家 → 解暂停
	_start_boss_intro(boss)


# Boss 死亡:清理引用、隐藏血条,并从当前时间起安排下一只 boss 的生成。
func _on_boss_died(boss) -> void:
	_active_boss = null
	_hide_boss_health_bar()
	_next_boss_spawn_time = elapsed_seconds + BOSS_NEXT_SPAWN_DELAY


# Boss 生成在玩家可见区外 BOSS_SPAWN_DISTANCE 处,在地图范围内 clamp。
func _get_boss_spawn_position() -> Vector2:
	var center: Vector2 = player.global_position
	var angle := randf() * TAU
	var pos := center + Vector2(cos(angle), sin(angle)) * BOSS_SPAWN_DISTANCE
	return _clamp_to_map(pos)


func _start_boss_intro(boss) -> void:
	if _boss_intro != null:
		return
	_boss_intro = BossIntroScene.new()
	_boss_intro.name = "BossIntro"
	_boss_intro.finished.connect(_on_boss_intro_finished)
	add_child(_boss_intro)
	get_tree().paused = true
	_boss_intro.play(boss, camera, _boss_name_label, player, MAP_RECT)


func _on_boss_intro_finished() -> void:
	if _boss_intro != null:
		_boss_intro.queue_free()
		_boss_intro = null
	get_tree().paused = false


func _update_score_label() -> void:
	score_label.text = "Score: %d" % score


func _update_level_label() -> void:
	level_label.text = "Level: %d" % current_level


func _check_level_up() -> void:
	if is_game_over or is_level_up_open or _boss_intro != null:
		return
	var next_level := current_level + 1
	if next_level > LEVEL_REQUIRED_SCORES.size():
		return  # 超出已配置的等级数,不再触发升级
	var required_score: int = int(LEVEL_REQUIRED_SCORES[next_level - 1])
	if score >= required_score:
		_show_level_up_options(next_level)


func _show_level_up_options(level: int) -> void:
	is_level_up_open = true
	level_up_title.text = "Level %d - Choose an Upgrade" % level
	for child in level_up_options_box.get_children():
		child.queue_free()
	if level == 1:
		# Level 1: choose the initial weapon only.
		for option_id in ["auto_shooter", "orbit_sword", "drone_minion"]:
			level_up_options_box.add_child(_create_weapon_card(option_id))
	elif level == 2:
		# Level 2: choose an element (one-shot). If all elements exhausted, fall back to stat upgrades.
		var pool := _build_normal_upgrade_pool()
		if pool.is_empty():
			pool = _build_stat_pool()
		for def in _pick_weighted(pool, 3):
			level_up_options_box.add_child(_create_upgrade_card(def))
	else:
		# Level 3+: choose from stat upgrades (repeatable up to MAX_STACKS).
		for def in _pick_weighted(_build_stat_pool(), 3):
			level_up_options_box.add_child(_create_upgrade_card(def))
	level_up_overlay.visible = true
	get_tree().paused = true

# Stat pool: excludes stats already capped at MAX_STACKS。
# DURATION 对 drone_minion 无效:若已解锁武器里只有 drone_minion(没有 auto_shooter / orbit_sword),
# 则 DURATION 不入池(framework §7 禁用选项,避免选了无效果的升级)。
func _build_stat_pool() -> Array:
	var pool := []
	var types := _get_unlocked_weapon_types()
	var duration_disabled := not types.is_empty() and not types.has("auto_shooter") and not types.has("orbit_sword")
	for def in stat_upgrade_defs:
		var stat: int = int(def["stat"])
		if stat == StatMath.Stat.DURATION and duration_disabled:
			continue
		if int(_stat_stacks.get(stat, 0)) < StatMath.MAX_STACKS:
			pool.append(def)
	return pool


# 当前已解锁的 weapon_type 列表(去重,顺序与 UPGRADE_OPTIONS 一致)。
func _get_unlocked_weapon_types() -> Array:
	var types := []
	for option_id in _acquired_upgrades.keys():
		var option: Dictionary = UPGRADE_OPTIONS.get(str(option_id), {})
		var wtype := str(option.get("weapon_type", ""))
		if not wtype.is_empty() and not types.has(wtype):
			types.append(wtype)
	return types


# 按已解锁武器动态拼接 stat 描述;无武器时回退到 stat_upgrade_defs 的兜底 desc。
func _build_stat_description(stat: int) -> String:
	var types := _get_unlocked_weapon_types()
	if types.is_empty():
		for def in stat_upgrade_defs:
			if int(def["stat"]) == stat:
				return str(def["desc"])
		return ""
	var parts := []
	for wtype in types:
		var per: Dictionary = STAT_DESC_PER_WEAPON.get(stat, {})
		var d := str(per.get(wtype, ""))
		if not d.is_empty():
			parts.append(d)
	if parts.is_empty():
		return ""
	return " / ".join(parts)


# Normal upgrade pool: excludes one-shot upgrades already unlocked.
func _build_normal_upgrade_pool() -> Array:
	var pool := []
	for def in element_upgrade_defs:
		var element_id := str(def["element"])
		if combat_effects == null or not combat_effects.is_element_unlocked(element_id):
			pool.append(def)
	return pool


func _pick_weighted(pool: Array, n: int) -> Array:
	var result := []
	var working := pool.duplicate()
	while result.size() < n and not working.is_empty():
		var total_weight := 0.0
		for def in working:
			total_weight += float(def["weight"])
		var roll := randf() * total_weight
		var acc := 0.0
		var chosen := 0
		for i in working.size():
			acc += float(working[i]["weight"])
			if roll <= acc:
				chosen = i
				break
		result.append(working[chosen])
		working.remove_at(chosen)
	return result


func _create_weapon_card(option_id: String) -> Control:
	var option: Dictionary = UPGRADE_OPTIONS[option_id]
	var card := VBoxContainer.new()
	card.name = "Upgrade_%s" % str(option.get("id", option_id))
	card.custom_minimum_size = Vector2(180, 300)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 8)
	card.process_mode = Node.PROCESS_MODE_ALWAYS

	var title := Label.new()
	title.text = str(option["title"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 24)
	card.add_child(title)

	var image_button := TextureButton.new()
	image_button.name = "ImageButton"
	image_button.custom_minimum_size = UPGRADE_IMAGE_SIZE
	image_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	image_button.ignore_texture_size = true
	image_button.texture_normal = load(str(option["image_path"]))
	image_button.process_mode = Node.PROCESS_MODE_ALWAYS
	image_button.pressed.connect(_choose_upgrade.bind(option_id))
	card.add_child(image_button)

	var description := Label.new()
	description.text = str(option["description"])
	description.custom_minimum_size = Vector2(170, 0)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 16)
	card.add_child(description)

	return card


func _create_upgrade_card(def: Dictionary) -> Control:
	var is_element := def.has("element")
	var stat := int(def.get("stat", -1))
	var current_stacks: int = int(_stat_stacks.get(stat, 0))
	var card := VBoxContainer.new()
	card.name = "Upgrade_%s" % str(def["id"])
	card.custom_minimum_size = Vector2(180, 300)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 8)
	card.process_mode = Node.PROCESS_MODE_ALWAYS

	var title := Label.new()
	title.text = str(def["title"]) if is_element else "%s  Lv.%d -> Lv.%d" % [str(def["title"]), current_stacks, current_stacks + 1]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 22)
	card.add_child(title)

	var button := Button.new()
	button.name = "SelectButton"
	button.custom_minimum_size = Vector2(120, 120)
	button.text = str(def["title"])
	button.add_theme_font_size_override("font_size", 34)
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	if is_element:
		button.pressed.connect(_choose_element.bind(str(def["element"])))
	else:
		button.pressed.connect(_choose_stat.bind(stat))
	card.add_child(button)

	var description := Label.new()
	# stat 升级描述按已解锁武器动态拼接;element 升级沿用 def["desc"]。
	description.text = str(def["desc"]) if is_element else _build_stat_description(stat)
	description.custom_minimum_size = Vector2(170, 0)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 16)
	card.add_child(description)

	return card

func _choose_upgrade(option_id: String) -> void:
	_apply_upgrade(option_id)
	_finish_level_up()


func _choose_stat(stat: int) -> void:
	_apply_stat_upgrade(stat)
	_finish_level_up()


func _choose_element(element_id: String) -> void:
	if combat_effects != null:
		combat_effects.unlock_element(element_id)
	_finish_level_up()


func _finish_level_up() -> void:
	current_level += 1
	_update_level_label()
	level_up_overlay.visible = false
	is_level_up_open = false
	get_tree().paused = false
	_check_level_up()


func _apply_upgrade(option_id: String) -> void:
	if _acquired_upgrades.has(option_id):
		return
	_acquired_upgrades[option_id] = true
	var option: Dictionary = UPGRADE_OPTIONS.get(option_id, {})
	match str(option.get("weapon_type", "")):
		"auto_shooter":
			_create_auto_shooter()
		"orbit_sword":
			_create_orbit_sword()
		"drone_minion":
			_create_drone_minion()


# 通用 stat 升级:堆叠数 +1,并同步给所有已解锁武器。
func _apply_stat_upgrade(stat: int) -> void:
	_stat_stacks[stat] = int(_stat_stacks.get(stat, 0)) + 1
	var stacks: int = int(_stat_stacks[stat])
	for weapon in _unlocked_weapons:
		if is_instance_valid(weapon):
			weapon.apply_stat(stat, stacks)


func _create_auto_shooter() -> void:
	var auto_shooter := AutoShooterScene.new()
	auto_shooter.name = "AutoShooter"
	auto_shooter.setup(player, enemies_layer, projectiles_layer, ProjectileScene, combat_effects)
	weapons_layer.add_child(auto_shooter)
	_unlocked_weapons.append(auto_shooter)
	_sync_weapon_stats(auto_shooter)


func _create_orbit_sword() -> void:
	var orbit_sword := OrbitSwordScene.new()
	orbit_sword.name = "OrbitSword"
	orbit_sword.setup(player, combat_effects)
	weapons_layer.add_child(orbit_sword)
	_unlocked_weapons.append(orbit_sword)
	_sync_weapon_stats(orbit_sword)


func _create_drone_minion() -> void:
	var drone_minion := DroneMinionScene.new()
	drone_minion.name = "DroneMinion"
	drone_minion.setup(player, enemies_layer, combat_effects)
	weapons_layer.add_child(drone_minion)
	_unlocked_weapons.append(drone_minion)
	_sync_weapon_stats(drone_minion)


# 新武器解锁时,把当前已累积的 stat 堆叠同步过去(支持后续多武器共存)。
func _sync_weapon_stats(weapon: Node) -> void:
	for stat in _stat_stacks.keys():
		weapon.apply_stat(int(stat), int(_stat_stacks[stat]))


func _on_player_died() -> void:
	is_game_over = true
	is_level_up_open = false
	# 清理进行中的 boss 过场
	if _boss_intro != null:
		_boss_intro.queue_free()
		_boss_intro = null
	if _boss_name_label != null:
		_boss_name_label.visible = false
	_hide_boss_health_bar()
	get_tree().paused = false
	if level_up_overlay != null:
		level_up_overlay.visible = false
	game_over_label.visible = true
	get_tree().call_group("enemy", "set_process", false)
	get_tree().call_group("projectile", "queue_free")
	get_tree().call_group("weapon", "set_process", false)


class MapBackground:
	extends Node2D

	var map_size := Vector2.ZERO

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.07, 0.09, 0.10, 1.0), true)


class MapGrid:
	extends Node2D

	var map_size := Vector2.ZERO
	var cell_size := 320.0

	func _draw() -> void:
		var grid_color := Color(0.16, 0.19, 0.20, 0.45)
		var x := 0.0
		while x <= map_size.x:
			draw_line(Vector2(x, 0.0), Vector2(x, map_size.y), grid_color, 2.0)
			x += cell_size
		var y := 0.0
		while y <= map_size.y:
			draw_line(Vector2(0.0, y), Vector2(map_size.x, y), grid_color, 2.0)
			y += cell_size


class MapBorder:
	extends Node2D

	var map_size := Vector2.ZERO

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.65, 0.72, 0.78, 1.0), false, 8.0)
