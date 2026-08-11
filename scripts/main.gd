extends Node2D

const PlayerScene := preload("res://scripts/player.gd")
const EnemyScene := preload("res://scripts/enemy.gd")
const RangedEnemyScene := preload("res://scripts/ranged_enemy.gd")
const HexagramEnemyScene := preload("res://scripts/hexagram_enemy.gd")
const ProjectileScene := preload("res://scripts/projectile.gd")
const BasicAttackScene := preload("res://scripts/basic_attack.gd")
const ElectricSkillControllerScene := preload("res://scripts/electric_skill_controller.gd")

const BossScene := preload("res://scripts/boss.gd")
const BossShooterScene := preload("res://scripts/boss_shooter.gd")
const BossIntroScene := preload("res://scripts/boss_intro.gd")
const EnemyProjectileScene := preload("res://scripts/enemy_projectile.gd")

const VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const MAP_SIZE := Vector2(12800.0, 7200.0)
const MAP_RECT := Rect2(Vector2.ZERO, MAP_SIZE)
# 各等级升级所需累计积分(下标 = 等级 - 1)。超出此列表的等级不再触发升级。
# TODO(临时调试): 第3级 100->40, 第4级 200->60;新增 Level 5-12(80/100/120/200/220/240/260)便于测试后期等级。
#                    调试完成后需确认正式积分曲线。
const LEVEL_REQUIRED_SCORES := [0, 15, 35, 60, 90, 125, 165, 215, 270, 330, 400, 480, 570, 670, 780, 800]
const UPGRADES_ENABLED := true
const MAX_UPGRADE_LEVEL := 3
const UPGRADE_OPTIONS := {
	"laser": {"title": "镭射炮", "prerequisite": ""},
	"laser_width": {"title": "镭射炮·宽", "prerequisite": "laser"},
	"laser_chain": {"title": "镭射炮·连", "prerequisite": "laser"},
	"laser_cloud": {"title": "镭射炮·云", "prerequisite": "laser"},
	"thunder_cloud": {"title": "雷云", "prerequisite": ""},
	"thunder_cloud_ball": {"title": "雷云·球", "prerequisite": "thunder_cloud"},
	"thunder_cloud_haste": {"title": "雷云·疾", "prerequisite": "thunder_cloud"},
	"thunder_ball": {"title": "雷球", "prerequisite": ""},
	"thunder_ball_laser": {"title": "雷球·炮", "prerequisite": "thunder_ball"},
	"thunder_ball_paralysis": {"title": "雷球·麻", "prerequisite": "thunder_ball"},
}
const GAME_VERSION := "v1.2.6"
const ENEMY_CONFIGS := {
	"chaser_1": {"name":"Chaser I", "behavior":"chaser", "shape":"square", "tier":1, "radius":18.0, "max_hp":100.0, "damage":100, "speed":190.0, "score_value":2, "body_color":Color(0.76,0.18,0.20,1.0), "outline_color":Color(1.0,0.56,0.58,1.0)},
	"chaser_2": {"name":"Chaser II", "behavior":"chaser", "shape":"square", "tier":2, "radius":20.0, "max_hp":200.0, "damage":100, "speed":200.0, "score_value":3, "body_color":Color(0.88,0.25,0.18,1.0), "outline_color":Color(1.0,0.72,0.50,1.0)},
	"chaser_3": {"name":"Chaser III", "behavior":"chaser", "shape":"square", "tier":3, "radius":22.0, "max_hp":350.0, "damage":100, "speed":210.0, "score_value":5, "body_color":Color(0.92,0.08,0.34,1.0), "outline_color":Color(1.0,0.72,0.84,1.0)},
	"ranged_1": {"name":"Ranged I", "behavior":"ranged", "shape":"triangle", "tier":1, "radius":18.0, "max_hp":100.0, "damage":100, "speed":145.0, "score_value":3, "body_color":Color(0.30,0.72,0.96,1.0), "outline_color":Color(0.76,0.94,1.0,1.0), "preferred_distance_min":420.0, "preferred_distance_max":600.0, "fire_interval":3.5, "fire_range":900.0, "projectile_speed":260.0, "projectile_damage":100.0},
	"ranged_2": {"name":"Ranged II", "behavior":"ranged", "shape":"triangle", "tier":2, "radius":20.0, "max_hp":175.0, "damage":100, "speed":155.0, "score_value":5, "body_color":Color(0.36,0.42,0.98,1.0), "outline_color":Color(0.78,0.82,1.0,1.0), "preferred_distance_min":420.0, "preferred_distance_max":600.0, "fire_interval":3.0, "fire_range":900.0, "projectile_speed":285.0, "projectile_damage":100.0},
	"ranged_3": {"name":"Ranged III", "behavior":"ranged", "shape":"triangle", "tier":3, "radius":22.0, "max_hp":300.0, "damage":100, "speed":165.0, "score_value":7, "body_color":Color(0.62,0.24,0.94,1.0), "outline_color":Color(0.92,0.74,1.0,1.0), "preferred_distance_min":420.0, "preferred_distance_max":600.0, "fire_interval":2.5, "fire_range":900.0, "projectile_speed":310.0, "projectile_damage":100.0},
	"fast_1": {"name":"Runner I", "behavior":"chaser", "shape":"diamond", "tier":1, "radius":12.0, "max_hp":50.0, "damage":100, "speed":250.0, "score_value":1, "body_color":Color(0.98,0.78,0.16,1.0), "outline_color":Color(1.0,0.96,0.62,1.0)},
	"fast_2": {"name":"Runner II", "behavior":"chaser", "shape":"diamond", "tier":2, "radius":13.0, "max_hp":50.0, "damage":100, "speed":270.0, "score_value":2, "body_color":Color(0.98,0.48,0.12,1.0), "outline_color":Color(1.0,0.82,0.48,1.0)},
	"fast_3": {"name":"Runner III", "behavior":"chaser", "shape":"diamond", "tier":3, "radius":14.0, "max_hp":50.0, "damage":100, "speed":290.0, "score_value":2, "body_color":Color(1.0,0.18,0.54,1.0), "outline_color":Color(1.0,0.72,0.88,1.0)},
	# 六芒星:近战(白系)对标 chaser_N 的速度/血量/体型;远程(蓝系)对标 ranged_N。
	# 同一组分裂只首杀给分,故 score_value 高于同档 chaser。
	"hexagram_melee_1": {"name":"Hexagram I", "behavior":"hexagram", "shape":"hexagram", "form":"melee", "tier":1, "radius":18.0, "max_hp":100.0, "damage":100, "speed":190.0, "score_value":5, "body_color":Color(0.95,0.95,0.95,1.0), "outline_color":Color(1.0,1.0,1.0,1.0)},
	"hexagram_melee_2": {"name":"Hexagram II", "behavior":"hexagram", "shape":"hexagram", "form":"melee", "tier":2, "radius":20.0, "max_hp":200.0, "damage":100, "speed":200.0, "score_value":8, "body_color":Color(0.78,0.78,0.82,1.0), "outline_color":Color(0.95,0.95,1.0,1.0)},
	"hexagram_melee_3": {"name":"Hexagram III", "behavior":"hexagram", "shape":"hexagram", "form":"melee", "tier":3, "radius":22.0, "max_hp":350.0, "damage":100, "speed":210.0, "score_value":12, "body_color":Color(0.95,0.78,0.82,1.0), "outline_color":Color(1.0,0.85,0.88,1.0)},
	"hexagram_ranged_1": {"name":"Hexagram R-I", "behavior":"hexagram", "shape":"hexagram", "form":"ranged", "tier":1, "radius":18.0, "max_hp":100.0, "damage":100, "speed":145.0, "score_value":5, "body_color":Color(0.40,0.78,1.0,1.0), "outline_color":Color(0.80,0.95,1.0,1.0), "preferred_distance_min":420.0, "preferred_distance_max":600.0, "fire_interval":3.5, "fire_range":900.0, "projectile_speed":260.0, "projectile_damage":100.0},
	"hexagram_ranged_2": {"name":"Hexagram R-II", "behavior":"hexagram", "shape":"hexagram", "form":"ranged", "tier":2, "radius":20.0, "max_hp":175.0, "damage":100, "speed":155.0, "score_value":8, "body_color":Color(0.30,0.55,1.0,1.0), "outline_color":Color(0.75,0.85,1.0,1.0), "preferred_distance_min":420.0, "preferred_distance_max":600.0, "fire_interval":3.0, "fire_range":900.0, "projectile_speed":285.0, "projectile_damage":100.0},
	"hexagram_ranged_3": {"name":"Hexagram R-III", "behavior":"hexagram", "shape":"hexagram", "form":"ranged", "tier":3, "radius":22.0, "max_hp":300.0, "damage":100, "speed":165.0, "score_value":12, "body_color":Color(0.40,0.30,0.95,1.0), "outline_color":Color(0.80,0.75,1.0,1.0), "preferred_distance_min":420.0, "preferred_distance_max":600.0, "fire_interval":2.5, "fire_range":900.0, "projectile_speed":310.0, "projectile_damage":100.0},
}
const SPAWN_STRATEGY := [
	{"start_time":0.0, "rates":{"chaser_1":14.0}},
	{"start_time":60.0, "rates":{"chaser_1":16.0, "fast_1":4.0}},
	{"start_time":120.0, "rates":{"chaser_1":18.0, "ranged_1":3.0, "fast_1":7.0, "hexagram_melee_1":4.0}},
	{"start_time":180.0, "rates":{"chaser_1":18.0, "ranged_1":5.0, "fast_1":8.0, "hexagram_melee_1":4.0}},
	{"start_time":240.0, "rates":{"chaser_1":14.0, "chaser_2":8.0, "ranged_1":6.0, "fast_1":10.0, "hexagram_melee_1":4.0}},
	{"start_time":300.0, "rates":{"chaser_1":10.0, "chaser_2":14.0, "ranged_1":4.0, "ranged_2":4.0, "fast_1":6.0, "fast_2":8.0, "hexagram_melee_2":4.0}},
	{"start_time":360.0, "rates":{"chaser_2":20.0, "ranged_1":3.0, "ranged_2":7.0, "fast_2":14.0, "hexagram_melee_2":4.0}},
	{"start_time":420.0, "rates":{"chaser_2":20.0, "chaser_3":6.0, "ranged_2":8.0, "fast_2":16.0, "hexagram_melee_2":4.0}},
	{"start_time":480.0, "rates":{"chaser_2":15.0, "chaser_3":12.0, "ranged_2":6.0, "ranged_3":5.0, "fast_2":10.0, "fast_3":10.0, "hexagram_melee_3":4.0}},
	{"start_time":540.0, "rates":{"chaser_2":10.0, "chaser_3":20.0, "ranged_2":4.0, "ranged_3":8.0, "fast_3":20.0, "hexagram_melee_3":4.0}},
]
const BOSS_CONFIGS := {
	"square_boss": {"boss_name":"Square Colossus", "shape":"square", "tier":1, "radius":60.0, "max_hp":3000.0, "damage":100, "speed":105.0, "score_value":75, "body_color":Color(0.66,0.10,0.16,1.0), "outline_color":Color(1.0,0.50,0.52,1.0)},
	"triangle_boss": {"boss_name":"Triangle Warden", "shape":"triangle", "tier":1, "radius":60.0, "max_hp":5000.0, "damage":100, "speed":205.0, "score_value":125, "body_color":Color(0.92,0.38,0.08,1.0), "outline_color":Color(1.0,0.82,0.45,1.0), "shooter":true, "preferred_distance_min":520.0, "preferred_distance_max":700.0, "fire_interval":1.8, "fire_range":1050.0, "projectile_speed":320.0, "projectile_damage":100.0},
}
const SCRIPTED_BOSS_SCHEDULE := [{"time":180.0,"type":"square_boss"},{"time":420.0,"type":"triangle_boss"}]
const POST_TEN_BOSS_INTERVAL := 180.0
const BOSS_DELAY_AFTER_DEATH := 10.0
const BOSS_SPAWN_DISTANCE := 760.0
const ENEMY_SPAWN_MARGIN := 140.0
const MAX_ENEMIES := 120
const MAX_RANGED_ENEMIES := 18
const MAX_FAST_ENEMIES := 36
const MAX_HEXAGRAM_ENEMIES := 24
const ENDLESS_START_TIME := 600.0
const ENDLESS_RATE_GROWTH := 1.08
const ENDLESS_HP_GROWTH := 1.12
const ENDLESS_SPEED_GROWTH := 1.02
const ENDLESS_FIRE_INTERVAL_DECAY := 0.97
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
var level_up_confirm_button: Button
var score := 0
var current_level := 0
var is_game_over := false
var is_level_up_open := false
var elapsed_seconds := 0.0
var _spawn_budgets := {}
# 六芒星分裂组积分记录:group_id -> true(已首杀给分)。仅首杀时写入,自然有界(=初始生成数)。
var _granted_score_groups := {}
var _next_hexagram_group_id := 0
var _boss_intro
var _boss_name_label: Label
# 当前存活 boss 引用;为空表示当前没有 boss。
var _active_boss = null
var _next_scripted_boss_index := 0
var _pending_boss_queue := []
var _pending_boss_ready_time := 0.0
var _next_endless_boss_time := ENDLESS_START_TIME + POST_TEN_BOSS_INTERVAL
var _endless_boss_index := 0
var _boss_health_container: CenterContainer
var _boss_health_name_label: Label
var _boss_health_bar: ProgressBar
var _upgrade_levels := {}
var _pending_upgrade_id := ""


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

	level_up_confirm_button = Button.new()
	level_up_confirm_button.name = "ConfirmButton"
	level_up_confirm_button.text = "CONFIRM"
	level_up_confirm_button.custom_minimum_size = Vector2(240, 58)
	level_up_confirm_button.add_theme_font_size_override("font_size", 28)
	level_up_confirm_button.process_mode = Node.PROCESS_MODE_ALWAYS
	level_up_confirm_button.disabled = true
	level_up_confirm_button.pressed.connect(_confirm_upgrade)
	content.add_child(level_up_confirm_button)


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
	if player == null or enemies_layer == null or _count_regular_enemies() >= MAX_ENEMIES:
		return
	var rates := _get_current_spawn_rates()
	for enemy_type in rates.keys():
		if not ENEMY_CONFIGS.has(enemy_type):
			continue
		_spawn_budgets[enemy_type] = float(_spawn_budgets.get(enemy_type, 0.0)) + float(rates[enemy_type]) / 60.0 * delta
		while _spawn_budgets[enemy_type] >= 1.0 and _count_regular_enemies() < MAX_ENEMIES:
			if _is_enemy_category_capped(str(enemy_type)):
				_spawn_budgets[enemy_type] -= 1.0
				continue
			_spawn_enemy(str(enemy_type))
			_spawn_budgets[enemy_type] -= 1.0

func _get_current_spawn_rates() -> Dictionary:
	var current_rates := {}
	for phase in SPAWN_STRATEGY:
		if elapsed_seconds >= float(phase["start_time"]):
			current_rates = phase["rates"].duplicate()
		else:
			break
	if elapsed_seconds >= ENDLESS_START_TIME:
		var endless_minutes := int(floor((elapsed_seconds - ENDLESS_START_TIME) / 60.0)) + 1
		var rate_multiplier := pow(ENDLESS_RATE_GROWTH, endless_minutes)
		for enemy_type in current_rates.keys():
			current_rates[enemy_type] = float(current_rates[enemy_type]) * rate_multiplier
	return current_rates

func _spawn_enemy(enemy_type: String) -> void:
	if is_game_over or player == null or _count_regular_enemies() >= MAX_ENEMIES:
		return
	var config: Dictionary = ENEMY_CONFIGS[enemy_type]
	var behavior := str(config.get("behavior", "chaser"))
	var enemy
	match behavior:
		"hexagram":
			enemy = HexagramEnemyScene.new()
		"ranged":
			enemy = RangedEnemyScene.new()
		_:
			enemy = EnemyScene.new()
	enemy.apply_config(config)
	# 远程类(ranged / hexagram 远程态)走带 fire_interval 的缩放分支;
	# hexagram 近战态走普通分支(speed_cap 与 chaser 一致)。
	var is_ranged_like: bool = behavior == "ranged" or (behavior == "hexagram" and enemy.form == "ranged")
	_apply_endless_enemy_scaling(enemy, enemy_type, is_ranged_like)
	enemy.global_position = _get_spawn_position_near_view(enemy.radius)
	enemy.target = player
	enemy.died.connect(_on_enemy_died)
	if behavior == "ranged" or behavior == "hexagram":
		# hexagram 近战态不射击,但 setup_projectiles 无副作用,统一调用以简化分支
		enemy.setup_projectiles(projectiles_layer, EnemyProjectileScene)
	if behavior == "hexagram":
		# 初始生成分配新 group_id;分裂子单位在 _on_hexagram_split 中继承父 group_id
		enemy.group_id = _next_hexagram_group_id
		_next_hexagram_group_id += 1
		enemy.split_completed.connect(_on_hexagram_split)
	enemies_layer.add_child(enemy)

func _apply_endless_enemy_scaling(enemy, enemy_type: String, is_ranged: bool) -> void:
	if elapsed_seconds < ENDLESS_START_TIME:
		return
	var endless_minutes := int(floor((elapsed_seconds - ENDLESS_START_TIME) / 60.0)) + 1
	var hp_multiplier := pow(ENDLESS_HP_GROWTH, endless_minutes)
	var speed_multiplier := pow(ENDLESS_SPEED_GROWTH, endless_minutes)
	var base_speed: float = float(ENEMY_CONFIGS[enemy_type]["speed"])
	var speed_cap := 330.0 if enemy_type.begins_with("fast_") else (190.0 if is_ranged else 218.0)
	speed_multiplier = minf(speed_multiplier, speed_cap / base_speed)
	if is_ranged:
		var fire_multiplier := pow(ENDLESS_FIRE_INTERVAL_DECAY, endless_minutes)
		enemy.apply_runtime_scaling(hp_multiplier, speed_multiplier, fire_multiplier)
	else:
		enemy.apply_runtime_scaling(hp_multiplier, speed_multiplier)

func _count_regular_enemies() -> int:
	var count := 0
	for child in enemies_layer.get_children():
		if child.is_in_group("enemy") and not child.is_in_group("boss"):
			count += 1
	return count

func _count_enemy_prefix(prefix: String) -> int:
	var count := 0
	for child in enemies_layer.get_children():
		if child.is_in_group("boss"):
			continue
		if str(child.enemy_name).to_lower().begins_with(prefix):
			count += 1
	return count

func _is_enemy_category_capped(enemy_type: String) -> bool:
	# 六芒星(近战+远程合计)统一上限,避免分裂指数膨胀
	if enemy_type.begins_with("hexagram_"):
		return get_tree().get_nodes_in_group("hexagram").size() >= MAX_HEXAGRAM_ENEMIES
	if enemy_type.begins_with("ranged_"):
		return _count_enemy_prefix("ranged") >= MAX_RANGED_ENEMIES
	if enemy_type.begins_with("fast_"):
		return _count_enemy_prefix("runner") >= MAX_FAST_ENEMIES
	return false

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
	var gained_score: int = int(enemy.score_value)
	# 六芒星分裂组:同一组只首杀给分,其后该组任何击杀不给分
	if enemy is HexagramEnemy:
		var gid: int = int(enemy.group_id)
		if _granted_score_groups.has(gid):
			gained_score = 0
		else:
			_granted_score_groups[gid] = true
	score += gained_score
	_update_score_label()
	_check_level_up()


# 六芒星分裂抖动结束回调:生成同组子单位,继承父 group_id 与当前血量
func _on_hexagram_split(parent, child_form: String) -> void:
	if is_game_over or player == null:
		return
	if not is_instance_valid(parent):
		return
	# 上限保护:六芒星总数或全局敌人数达上限时跳过本次分裂
	if get_tree().get_nodes_in_group("hexagram").size() >= MAX_HEXAGRAM_ENEMIES:
		return
	if _count_regular_enemies() >= MAX_ENEMIES:
		return
	var config_key := "hexagram_" + child_form + "_" + str(parent.tier)
	if not ENEMY_CONFIGS.has(config_key):
		return
	var config: Dictionary = ENEMY_CONFIGS[config_key]
	var child = HexagramEnemyScene.new()
	child.apply_config(config)
	# 远程态走带 fire_interval 的缩放;近战态走普通分支
	var child_is_ranged := (child_form == "ranged")
	_apply_endless_enemy_scaling(child, config_key, child_is_ranged)
	# 血量继承:子单位 max_hp = hp = 父单位当前血量(父单位血量不变)
	var inherited_hp: float = float(parent.hp)
	child.max_hp = inherited_hp
	child.hp = inherited_hp
	# 位置:父单位附近偏移,限制在地图内
	var offset := Vector2(randf_range(40.0, 80.0), randf_range(40.0, 80.0))
	child.global_position = _clamp_to_map(parent.global_position + offset, child.radius)
	child.target = player
	child.died.connect(_on_enemy_died)
	child.setup_projectiles(projectiles_layer, EnemyProjectileScene)
	# 继承父 group_id:保证同组积分只给一次
	child.group_id = parent.group_id
	child.split_completed.connect(_on_hexagram_split)
	enemies_layer.add_child(child)


# === Boss schedule and intro ===
func _update_boss_spawns() -> void:
	if _boss_intro != null:
		return
	if _active_boss != null and not is_instance_valid(_active_boss):
		_active_boss = null
	_queue_due_scripted_bosses()
	_queue_due_endless_bosses()
	if _pending_boss_queue.is_empty() or elapsed_seconds < _pending_boss_ready_time:
		return
	if _active_boss != null and is_instance_valid(_active_boss):
		return
	var boss_type := str(_pending_boss_queue.pop_front())
	_pending_boss_ready_time = INF if not _pending_boss_queue.is_empty() else 0.0
	_spawn_boss(boss_type)

func _queue_due_scripted_bosses() -> void:
	if _next_scripted_boss_index >= SCRIPTED_BOSS_SCHEDULE.size():
		return
	var entry: Dictionary = SCRIPTED_BOSS_SCHEDULE[_next_scripted_boss_index]
	if elapsed_seconds < float(entry["time"]):
		return
	_queue_boss(str(entry["type"]))
	_next_scripted_boss_index += 1

func _queue_due_endless_bosses() -> void:
	if elapsed_seconds < _next_endless_boss_time:
		return
	var boss_type := "square_boss" if _endless_boss_index % 2 == 0 else "triangle_boss"
	_queue_boss(boss_type)
	_endless_boss_index += 1
	_next_endless_boss_time += POST_TEN_BOSS_INTERVAL

func _queue_boss(boss_type: String) -> void:
	_pending_boss_queue.append(boss_type)
	if _pending_boss_queue.size() > 1:
		return
	_pending_boss_ready_time = elapsed_seconds
	if _active_boss != null and is_instance_valid(_active_boss):
		_pending_boss_ready_time = INF

func _spawn_boss(boss_type: String) -> void:
	if not BOSS_CONFIGS.has(boss_type):
		return
	var config: Dictionary = BOSS_CONFIGS[boss_type]
	var is_shooter := bool(config.get("shooter", false))
	var boss = BossShooterScene.new() if is_shooter else BossScene.new()
	boss.apply_config(config)
	_apply_endless_boss_scaling(boss, is_shooter)
	boss.global_position = _get_boss_spawn_position(boss.radius)
	boss.target = player
	boss.died.connect(_on_enemy_died)
	boss.died.connect(_on_boss_died)
	if is_shooter:
		boss.setup_projectiles(projectiles_layer, EnemyProjectileScene)
	enemies_layer.add_child(boss)
	_active_boss = boss
	_show_boss_health_bar(boss)
	_start_boss_intro(boss)

func _apply_endless_boss_scaling(boss, is_shooter: bool) -> void:
	if elapsed_seconds < ENDLESS_START_TIME:
		return
	var boss_number := maxi(1, _endless_boss_index)
	var hp_multiplier := pow(1.20, boss_number)
	if is_shooter:
		var fire_multiplier := pow(0.95, boss_number)
		boss.set_fire_interval_floor(1.2)
		boss.apply_runtime_scaling(hp_multiplier, 1.0, fire_multiplier)
	else:
		boss.apply_runtime_scaling(hp_multiplier, 1.0)

func _on_boss_died(_boss) -> void:
	_active_boss = null
	_hide_boss_health_bar()
	if not _pending_boss_queue.is_empty():
		_pending_boss_ready_time = elapsed_seconds + BOSS_DELAY_AFTER_DEATH

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
	_pending_upgrade_id = ""
	if level_up_confirm_button != null:
		level_up_confirm_button.disabled = true
	for child in level_up_options_box.get_children():
		# Remove immediately so back-to-back level-ups cannot leave old cards
		# participating in layout or intercepting input until queue_free runs.
		level_up_options_box.remove_child(child)
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
	var current_upgrade_level: int = int(_upgrade_levels.get(option_id, 0))
	var next_upgrade_level := current_upgrade_level + 1
	var button := TextureButton.new()
	button.name = "Upgrade_%s" % option_id
	button.custom_minimum_size = Vector2(240, 315)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_normal = load(_get_upgrade_card_image_path(option_id, next_upgrade_level))
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.tooltip_text = ""
	button.pressed.connect(_select_upgrade.bind(option_id))
	return button


func _get_upgrade_card_image_path(option_id: String, level: int) -> String:
	return "res://assets/upgrades/electric/%s_lv%d.png" % [option_id, level]


func _select_upgrade(option_id: String) -> void:
	_pending_upgrade_id = option_id
	if level_up_confirm_button != null:
		level_up_confirm_button.disabled = false
	for child in level_up_options_box.get_children():
		if child is TextureButton:
			child.modulate = Color.WHITE if child.name == "Upgrade_%s" % option_id else Color(0.42, 0.42, 0.42, 0.72)


func _confirm_upgrade() -> void:
	if _pending_upgrade_id.is_empty():
		return
	var option_id := _pending_upgrade_id
	_pending_upgrade_id = ""
	if level_up_confirm_button != null:
		level_up_confirm_button.disabled = true
	_apply_confirmed_upgrade(option_id)


func _apply_confirmed_upgrade(option_id: String) -> void:
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
	_pending_upgrade_id = ""
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
