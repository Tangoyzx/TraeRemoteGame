extends Node2D

const PlayerScene := preload("res://scripts/player.gd")
const EnemyScene := preload("res://scripts/enemy.gd")
const ProjectileScene := preload("res://scripts/projectile.gd")
const BasicAttackScene := preload("res://scripts/basic_attack.gd")
const ElectricSkillControllerScene := preload("res://scripts/electric_skill_controller.gd")

const BossScene := preload("res://scripts/boss.gd")
const BossShooterScene := preload("res://scripts/boss_shooter.gd")
const BossIntroScene := preload("res://scripts/boss_intro.gd")
const TurretScene := preload("res://scripts/turret.gd")
const EnemyProjectileScene := preload("res://scripts/enemy_projectile.gd")

const VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const MAP_SIZE := Vector2(12800.0, 7200.0)
const MAP_RECT := Rect2(Vector2.ZERO, MAP_SIZE)
# 各等级升级所需累计积分(下标 = 等级 - 1)。超出此列表的等级不再触发升级。
# TODO(临时调试): 第3级 100->40, 第4级 200->60;新增 Level 5-12(80/100/120/200/220/240/260)便于测试后期等级。
#                    调试完成后需确认正式积分曲线。
const LEVEL_REQUIRED_SCORES := [0, 20, 40, 60, 80, 100, 120, 200, 220, 240, 260, 280, 290, 300, 320, 400]
const UPGRADES_ENABLED := true
const MAX_UPGRADE_LEVEL := 3
const UPGRADE_OPTIONS := {
	"laser": {"title": "镭射炮", "prerequisite": ""},
	"laser_width": {"title": "镭射炮·宽", "prerequisite": "laser"},
	"laser_chain": {"title": "镭射炮·连", "prerequisite": "laser"},
	"thunder_cloud": {"title": "雷云", "prerequisite": ""},
	"thunder_cloud_ball": {"title": "雷云·球", "prerequisite": "thunder_cloud"},
	"thunder_cloud_haste": {"title": "雷云·疾", "prerequisite": "thunder_cloud"},
	"thunder_ball": {"title": "雷球", "prerequisite": ""},
	"thunder_ball_laser": {"title": "雷球·炮", "prerequisite": "thunder_ball"},
	"thunder_ball_paralysis": {"title": "雷球·麻", "prerequisite": "thunder_ball"},
}
# 游戏版本号,显示在屏幕顶部居中。
# 规则:合并到远端 main 前,若无特殊说明则末位自动 +1(如 1.0.0 → 1.0.1)。
const GAME_VERSION := "v1.2.1"
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
	# 固定炮塔:不动,远距离朝玩家发射子弹。hp 与 chubby 同档,伤害=玩家子弹
	# 基础伤害(100=1 玩家 HP),score_value 给 5(处理难度高于普通小怪)。
	# speed 字段对炮塔无意义(重写了 _process),保留 0 仅满足 config 结构。
	"turret": {
		"name": "Turret",
		"radius": BASIC_ENEMY_RADIUS,
		"max_hp": 300.0,
		"damage": 100,
		"speed": 0.0,
		"score_value": 5,
		"body_color": Color(1.0, 1.0, 1.0, 1.0),
		"outline_color": Color(0.55, 0.55, 0.55, 1.0),
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
			# turret 速率 0.1 = 每 10 秒尝试生成 1 个,实际数量受 MAX_TURRETS=3 限制。
			"turret": 0.1,
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
	# 会开火的 Big Brother 变体:继承移动(追玩家)+ 定时朝玩家发射子弹。
	# shooter 标志由 _spawn_boss 判断,决定创建 BossShooterScene 并注入子弹体系。
	# 伤害/血量同 big_brother;颜色改为橙色便于玩家识别。
	"big_brother_shooter": {
		"boss_name": "Big Brother",
		"radius": 60.0,
		"max_hp": 2000.0,
		"damage": 300,
		"speed": 57.5,
		"score_value": 50,
		"body_color": Color(0.95, 0.45, 0.12, 1.0),
		"outline_color": Color(1.0, 0.78, 0.45, 1.0),
		"shooter": true,
	},
}
# Boss 生成池:每次到点从池中随机选一个生成。
const BOSS_SPAWN_POOL := ["big_brother", "big_brother_shooter"]
# Boss 生成时机:第一个 boss 在游戏开始后 BOSS_FIRST_SPAWN_DELAY 秒生成
# (相当于把第 0 秒当作"上一只 boss 刚死");之后每只 boss 死亡后再过
# BOSS_NEXT_SPAWN_DELAY 秒生成下一只,同一时间最多存在一只 boss。
const BOSS_FIRST_SPAWN_DELAY := 60.0
const BOSS_NEXT_SPAWN_DELAY := 180.0
const BOSS_SPAWN_DISTANCE := 360.0  # 生成在玩家可见区外此距离处
const ENEMY_SPAWN_MARGIN := 140.0
const MAX_ENEMIES := 120
# 固定炮塔同时存活上限:独立于 MAX_ENEMIES,避免炮塔挤占普通敌人配额。
# MAX_ENEMIES 仍作为绝对上限兜底(炮塔也是 enemies_layer 的子节点)。
const MAX_TURRETS := 3
# 炮塔生成在距离玩家 [MIN, MAX] 的环内,且整个身体落在地图边界内。
# MIN > FIRE_RANGE(1280) 让玩家有反应时间,不会一出生就被开火打到。
const TURRET_SPAWN_DIST_MIN := 1500.0
const TURRET_SPAWN_DIST_MAX := 3000.0
var player
var camera: Camera2D
var world_layer: Node2D
var enemies_layer: Node2D
var projectiles_layer: Node2D
var player_attacks_layer: Node2D
var basic_attack
var electric_skills
var ui_layer: CanvasLayer
var score_label: Label
var level_label: Label
var version_label: Label
var hint_label: Label
var game_over_label: Label
var restart_button: Button
var level_up_overlay: ColorRect
var level_up_title: Label
var level_up_options_box: HBoxContainer
var score := 0
var current_level := 0
var is_game_over := false
var is_level_up_open := false
var elapsed_seconds := 0.0
var _spawn_budgets := {}
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
var _upgrade_levels := {}


func _ready() -> void:
	randomize()
	get_tree().paused = false
	_init_spawn_budgets()
	_build_world()
	_spawn_player()
	_create_basic_attack()
	_create_electric_skills()
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

	player_attacks_layer = Node2D.new()
	player_attacks_layer.name = "PlayerAttacks"
	add_child(player_attacks_layer)

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


func _spawn_player() -> void:
	player = PlayerScene.new()
	player.name = "Player"
	player.global_position = MAP_SIZE * 0.5
	player.map_rect = MAP_RECT
	player.died.connect(_on_player_died)
	add_child(player)
	camera.global_position = player.global_position


# BasicAttack is permanent and independent from the skill system.
func _create_basic_attack() -> void:
	basic_attack = BasicAttackScene.new()
	basic_attack.name = "BasicAttack"
	basic_attack.setup(player, enemies_layer, projectiles_layer, ProjectileScene)
	player_attacks_layer.add_child(basic_attack)


func _create_electric_skills() -> void:
	electric_skills = ElectricSkillControllerScene.new()
	electric_skills.name = "ElectricSkills"
	player_attacks_layer.add_child(electric_skills)
	electric_skills.setup(player, enemies_layer, player_attacks_layer, basic_attack)


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

	# 操作提示:屏幕右上角,半透明,与左上 score/level 视觉对称。
	hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = "Click / Tap to Move"
	hint_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hint_label.offset_left = -300.0
	hint_label.offset_right = -24.0
	hint_label.offset_top = 24.0
	hint_label.offset_bottom = 48.0
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.modulate = Color(1.0, 1.0, 1.0, 0.60)
	ui_layer.add_child(hint_label)

	game_over_label = Label.new()
	game_over_label.name = "GameOverLabel"
	game_over_label.visible = false
	game_over_label.text = "GAME OVER"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 72)
	game_over_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(game_over_label)

	# 重新开始按钮:玩家死亡时显示在 GAME OVER 文字下方,点击后重载场景。
	# 必须放在 game_over_label 之后(层级在上)才能优先接收点击。
	restart_button = Button.new()
	restart_button.name = "RestartButton"
	restart_button.visible = false
	restart_button.text = "Restart"
	restart_button.custom_minimum_size = Vector2(220, 64)
	restart_button.add_theme_font_size_override("font_size", 30)
	restart_button.set_anchors_preset(Control.PRESET_CENTER)
	restart_button.offset_left = -110.0
	restart_button.offset_right = 110.0
	restart_button.offset_top = 80.0
	restart_button.offset_bottom = 144.0
	restart_button.process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.pressed.connect(_on_restart_pressed)
	ui_layer.add_child(restart_button)

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
			# turret 单独限制同时存活数量;达上限时消耗 budget 等下次窗口,
			# 避免 budget 持续累积导致旧 turret 一死就瞬间补一堆。
			if enemy_type == "turret" and _count_turrets() >= MAX_TURRETS:
				_spawn_budgets[enemy_type] -= 1.0
				continue
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
	if enemy_type == "turret":
		_spawn_turret()
		return
	var enemy := EnemyScene.new()
	enemy.apply_config(ENEMY_CONFIGS[enemy_type])
	enemy.global_position = _get_spawn_position_near_view(enemy.radius)
	enemy.target = player
	enemy.died.connect(_on_enemy_died)
	enemies_layer.add_child(enemy)


# 炮塔专属生成:位置在玩家周围环形带内(整个地图范围,而非屏幕外),
# 注入子弹 layer 与子弹场景供其开火使用。
func _spawn_turret() -> void:
	if is_game_over or player == null:
		return
	var turret := TurretScene.new()
	turret.apply_config(ENEMY_CONFIGS["turret"])
	turret.global_position = _get_turret_spawn_position(turret.radius)
	turret.target = player
	turret.died.connect(_on_enemy_died)
	turret.setup_projectiles(projectiles_layer, EnemyProjectileScene)
	enemies_layer.add_child(turret)


# 炮塔生成位置:玩家周围 [MIN, MAX] 距离的环内随机一点,clamp 到地图边界内。
# MIN > FIRE_RANGE 让玩家有反应时间;MAX 限制不要太远避免炮塔孤立无意义。
func _get_turret_spawn_position(edge_margin: float = 0.0) -> Vector2:
	var center: Vector2 = player.global_position
	var angle := randf() * TAU
	var dist := randf_range(TURRET_SPAWN_DIST_MIN, TURRET_SPAWN_DIST_MAX)
	var pos := center + Vector2(cos(angle), sin(angle)) * dist
	return _clamp_to_map(pos, edge_margin)


func _count_turrets() -> int:
	return get_tree().get_nodes_in_group("turret").size()


# 在玩家可见区外生成敌方单位。edge_margin 为实体半径,用于把 clamp 范围向内收,
# 确保整个实体身体(含半径)都落在地图边界内,不会跨出边界。
func _get_spawn_position_near_view(edge_margin: float = 0.0) -> Vector2:
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
	return _clamp_to_map(spawn, edge_margin)


func _set_player_target(world_position: Vector2) -> void:
	player.set_move_target(_clamp_to_map(world_position))


# 把坐标限制在地图矩形内。margin > 0 时把范围向内收,确保半径为 margin 的实体
# 整体(含身体)都落在地图边界内,而不是只有中心点在边界内。
func _clamp_to_map(world_position: Vector2, margin: float = 0.0) -> Vector2:
	var min_x: float = MAP_RECT.position.x + margin
	var min_y: float = MAP_RECT.position.y + margin
	var max_x: float = MAP_RECT.end.x - margin
	var max_y: float = MAP_RECT.end.y - margin
	# 防止 margin 过大导致 min > max(地图极小时兜底)
	if max_x < min_x:
		min_x = (MAP_RECT.position.x + MAP_RECT.end.x) * 0.5
		max_x = min_x
	if max_y < min_y:
		min_y = (MAP_RECT.position.y + MAP_RECT.end.y) * 0.5
		max_y = min_y
	return Vector2(
		clampf(world_position.x, min_x, max_x),
		clampf(world_position.y, min_y, max_y)
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
	var config: Dictionary = BOSS_CONFIGS[boss_type]
	# shooter 标志决定创建会开火的 boss 变体;否则用普通 boss。
	var is_shooter := bool(config.get("shooter", false))
	var boss = BossShooterScene.new() if is_shooter else BossScene.new()
	boss.apply_config(config)
	boss.global_position = _get_boss_spawn_position(boss.radius)
	boss.target = player
	boss.died.connect(_on_enemy_died)
	boss.died.connect(_on_boss_died)
	if is_shooter:
		boss.setup_projectiles(projectiles_layer, EnemyProjectileScene)
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
# edge_margin 为 boss 半径,确保整个 boss 身体落在地图边界内。
func _get_boss_spawn_position(edge_margin: float = 0.0) -> Vector2:
	var center: Vector2 = player.global_position
	var angle := randf() * TAU
	var pos := center + Vector2(cos(angle), sin(angle)) * BOSS_SPAWN_DISTANCE
	return _clamp_to_map(pos, edge_margin)


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
	if not UPGRADES_ENABLED:
		return
	if is_game_over or is_level_up_open or _boss_intro != null:
		return
	var next_level := current_level + 1
	if next_level > LEVEL_REQUIRED_SCORES.size():
		return
	var required_score: int = int(LEVEL_REQUIRED_SCORES[next_level - 1])
	if score >= required_score:
		_show_level_up_options(next_level)


func _show_level_up_options(level: int) -> void:
	if not UPGRADES_ENABLED or UPGRADE_OPTIONS.is_empty():
		return
	level_up_title.text = "Level %d - Choose an Upgrade" % level
	for child in level_up_options_box.get_children():
		child.queue_free()
	var candidates := _build_upgrade_pool()
	candidates.shuffle()
	var option_count: int = mini(3, candidates.size())
	for index in range(option_count):
		level_up_options_box.add_child(_create_upgrade_card(str(candidates[index])))
	if level_up_options_box.get_child_count() == 0:
		return
	is_level_up_open = true
	level_up_overlay.visible = true
	get_tree().paused = true


func _build_upgrade_pool() -> Array:
	var pool := []
	for option_id in UPGRADE_OPTIONS.keys():
		var current_upgrade_level: int = int(_upgrade_levels.get(option_id, 0))
		if current_upgrade_level >= MAX_UPGRADE_LEVEL:
			continue
		var option: Dictionary = UPGRADE_OPTIONS[option_id]
		var prerequisite := str(option.get("prerequisite", ""))
		if not prerequisite.is_empty() and int(_upgrade_levels.get(prerequisite, 0)) <= 0:
			continue
		pool.append(str(option_id))
	return pool


func _create_upgrade_card(option_id: String) -> Control:
	var option: Dictionary = UPGRADE_OPTIONS[option_id]
	var current_upgrade_level: int = int(_upgrade_levels.get(option_id, 0))
	var next_upgrade_level := current_upgrade_level + 1
	var card := VBoxContainer.new()
	card.name = "Upgrade_%s" % option_id
	card.custom_minimum_size = Vector2(200, 280)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 12)
	card.process_mode = Node.PROCESS_MODE_ALWAYS

	var title := Label.new()
	title.text = "%s  Lv.%d -> Lv.%d" % [str(option["title"]), current_upgrade_level, next_upgrade_level]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 22)
	card.add_child(title)

	var button := Button.new()
	button.name = "SelectButton"
	button.custom_minimum_size = Vector2(160, 110)
	button.text = str(option["title"])
	button.add_theme_font_size_override("font_size", 26)
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(_choose_upgrade.bind(option_id))
	card.add_child(button)

	var description := Label.new()
	description.text = _get_upgrade_description(option_id, next_upgrade_level)
	description.custom_minimum_size = Vector2(190, 0)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 16)
	card.add_child(description)
	return card


func _get_upgrade_description(option_id: String, level: int) -> String:
	var chance := level * 20
	match option_id:
		"laser":
			return "基础射击后有 %d%% 概率发射贯穿镭射炮。" % chance
		"laser_width":
			return "镭射炮宽度增加 10px，总宽度达到 %dpx。" % (10 + level * 10)
		"laser_chain":
			return "镭射炮有 %d%% 概率在 0.5 秒后继续连射。" % chance
		"thunder_cloud":
			return "永久雷云数量增加到 %d 个。" % level
		"thunder_cloud_ball":
			return "雷云攻击有 %d%% 概率在目标处生成雷球。" % chance
		"thunder_cloud_haste":
			var intervals := [0.0, 2.0 / 1.5, 1.0, 2.0 / 2.5]
			return "雷云攻击间隔缩短为 %.2f 秒。" % float(intervals[level])
		"thunder_ball":
			return "每 %.2f 秒在玩家位置生成一个雷球。" % (10.0 / float(level))
		"thunder_ball_laser":
			return "雷球爆炸有 %d%% 概率发射镭射炮。" % chance
		"thunder_ball_paralysis":
			return "雷球爆炸有 %d%% 概率麻痹全部受击敌人 5 秒。" % chance
	return ""


func _choose_upgrade(option_id: String) -> void:
	var next_upgrade_level: int = int(_upgrade_levels.get(option_id, 0)) + 1
	_upgrade_levels[option_id] = mini(next_upgrade_level, MAX_UPGRADE_LEVEL)
	if electric_skills != null:
		electric_skills.set_upgrade_level(option_id, int(_upgrade_levels[option_id]))
	current_level += 1
	_update_level_label()
	level_up_overlay.visible = false
	is_level_up_open = false
	get_tree().paused = false
	_check_level_up()


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
	if restart_button != null:
		restart_button.visible = true
	get_tree().call_group("enemy", "set_process", false)
	get_tree().call_group("projectile", "queue_free")
	get_tree().call_group("enemy_projectile", "queue_free")
	get_tree().call_group("player_attack", "set_process", false)
	if electric_skills != null:
		electric_skills.stop()


# 点击重新开始按钮:重载当前场景,回到初始状态。
func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


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
