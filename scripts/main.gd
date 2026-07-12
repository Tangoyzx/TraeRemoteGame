extends Node2D

const PlayerScene := preload("res://scripts/player.gd")
const EnemyScene := preload("res://scripts/enemy.gd")
const ProjectileScene := preload("res://scripts/projectile.gd")
const AutoShooterScene := preload("res://scripts/weapons/auto_shooter.gd")
const OrbitSwordScene := preload("res://scripts/weapons/orbit_sword.gd")
const UpgradeUIFont := _create_system_font()


# 用系统字体渲染 UI 中文,避免在 .pck 内打包中文字体(显著减小首包)。
# Web 端会回落到浏览器的中文字体栈,不同设备字体外观略有差异但都能正常显示。
static func _create_system_font() -> SystemFont:
	var font := SystemFont.new()
	# 按优先级排列常见中文/通用无衬线字体;缺失的会被自动跳过。
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "SimHei",
		"Noto Sans CJK SC", "Source Han Sans SC", "WenQuanYi Micro Hei",
		"Arial Unicode MS", "sans-serif",
	])
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_HALF
	return font

const VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const MAP_SIZE := Vector2(12800.0, 7200.0)
const MAP_RECT := Rect2(Vector2.ZERO, MAP_SIZE)
# 各等级升级所需累计积分(下标 = 等级 - 1)。超出此列表的等级不再触发升级。
const LEVEL_REQUIRED_SCORES := [0, 50, 200, 99999]
# 游戏版本号,显示在屏幕顶部居中。
# 规则:合并到远端 main 前,若无特殊说明则末位自动 +1(如 1.0.0 → 1.0.1)。
const GAME_VERSION := "v1.0.5"
const UPGRADE_IMAGE_SIZE := Vector2(100.0, 200.0)
const BASIC_ENEMY_RADIUS := 18.0
const BASIC_ENEMY_SPEED := 115.0
const ENEMY_CONFIGS := {
	"basic": {
		"name": "初级怪",
		"radius": BASIC_ENEMY_RADIUS,
		"max_hp": 1,
		"damage": 1,
		"speed": BASIC_ENEMY_SPEED,
		"score_value": 1,
		"body_color": Color(0.92, 0.20, 0.20, 1.0),
		"outline_color": Color(1.0, 0.68, 0.68, 1.0),
	},
	"chubby": {
		"name": "小胖子",
		"radius": BASIC_ENEMY_RADIUS * 1.2,
		"max_hp": 3,
		"damage": 2,
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
const UPGRADE_OPTIONS := {
	"auto_shooter": {
		"id": "auto_shooter",
		"title": "子弹",
		"description": "自动瞄准最近敌人发射子弹",
		"image_path": "res://assets/upgrades/bullet.svg",
		"weapon_type": "auto_shooter",
	},
	"orbit_sword": {
		"id": "orbit_sword",
		"title": "环绕剑",
		"description": "围绕角色旋转并持续伤害敌人",
		"image_path": "res://assets/upgrades/orbit_sword.svg",
		"weapon_type": "orbit_sword",
	},
}
# 通用 stat 升级定义。weight 控制加权随机投放(详见 docs/skill-system-framework.md §8)。
var stat_upgrade_defs := [
	{"id": "stat_frequency", "stat": StatMath.Stat.FREQUENCY, "title": "频率", "desc": "减少子弹冷却 / 加快剑的旋转", "weight": 100},
	{"id": "stat_damage", "stat": StatMath.Stat.DAMAGE, "title": "伤害", "desc": "提升每次命中伤害", "weight": 100},
	{"id": "stat_area", "stat": StatMath.Stat.AREA, "title": "范围", "desc": "增大子弹与剑的尺寸/半径", "weight": 60},
	{"id": "stat_duration", "stat": StatMath.Stat.DURATION, "title": "持续", "desc": "延长子弹寿命 / 加长剑身", "weight": 60},
	{"id": "stat_speed", "stat": StatMath.Stat.SPEED, "title": "速度", "desc": "提升弹速 / 加快剑的旋转", "weight": 60},
	{"id": "stat_count", "stat": StatMath.Stat.COUNT, "title": "数量", "desc": "+1 子弹(多瞄一敌) / +1 剑", "weight": 35},
	{"id": "stat_pierce", "stat": StatMath.Stat.PIERCE, "title": "穿透", "desc": "子弹穿透更多敌 / 剑命中冷却↓", "weight": 35},
]
const ENEMY_SPAWN_MARGIN := 140.0
const MAX_ENEMIES := 120

var player: Player
var camera: Camera2D
var world_layer: Node2D
var enemies_layer: Node2D
var projectiles_layer: Node2D
var weapons_layer: Node2D
var ui_layer: CanvasLayer
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


func _ready() -> void:
	randomize()
	get_tree().paused = false
	_init_spawn_budgets()
	_build_world()
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
	level_up_title.text = "升级！选择一个强化"
	level_up_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_up_title.add_theme_font_override("font", UpgradeUIFont)
	level_up_title.add_theme_font_size_override("font_size", 34)
	content.add_child(level_up_title)

	level_up_options_box = HBoxContainer.new()
	level_up_options_box.name = "Options"
	level_up_options_box.alignment = BoxContainer.ALIGNMENT_CENTER
	level_up_options_box.add_theme_constant_override("separation", 28)
	level_up_options_box.process_mode = Node.PROCESS_MODE_ALWAYS
	content.add_child(level_up_options_box)


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
	var center := camera.get_screen_center_position() if camera != null else player.global_position
	var half := viewport_size * 0.5
	var side := randi() % 4
	var spawn := center
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


func _on_enemy_died(enemy: Enemy) -> void:
	score += enemy.score_value
	_update_score_label()
	_check_level_up()


func _update_score_label() -> void:
	score_label.text = "Score: %d" % score


func _update_level_label() -> void:
	level_label.text = "Level: %d" % current_level


func _check_level_up() -> void:
	if is_game_over or is_level_up_open:
		return
	var next_level := current_level + 1
	if next_level > LEVEL_REQUIRED_SCORES.size():
		return  # 超出已配置的等级数,不再触发升级
	var required_score: int = int(LEVEL_REQUIRED_SCORES[next_level - 1])
	if score >= required_score:
		_show_level_up_options(next_level)


func _show_level_up_options(level: int) -> void:
	is_level_up_open = true
	level_up_title.text = "等级 %d - 选择一个强化" % level
	for child in level_up_options_box.get_children():
		child.queue_free()
	if level == 1:
		# 首次升级:选择初始武器。
		for option_id in ["auto_shooter", "orbit_sword"]:
			level_up_options_box.add_child(_create_weapon_card(option_id))
	else:
		# 后续升级:从已解锁武器可用的 stat 池中加权随机抽 3 个。
		var pool := _build_stat_pool()
		for def in _pick_weighted(pool, 3):
			level_up_options_box.add_child(_create_stat_card(def))
	level_up_overlay.visible = true
	get_tree().paused = true


# 可投放的 stat 池:排除已堆满(MAX_STACKS)的属性。
func _build_stat_pool() -> Array:
	var pool := []
	for def in stat_upgrade_defs:
		var stat: int = int(def["stat"])
		if int(_stat_stacks.get(stat, 0)) < StatMath.MAX_STACKS:
			pool.append(def)
	return pool


# 从 pool 中按 weight 加权随机抽 n 个互不相同的项。
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
	title.add_theme_font_override("font", UpgradeUIFont)
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
	description.add_theme_font_override("font", UpgradeUIFont)
	description.add_theme_font_size_override("font_size", 16)
	card.add_child(description)

	return card


func _create_stat_card(def: Dictionary) -> Control:
	var stat: int = int(def["stat"])
	var current_stacks: int = int(_stat_stacks.get(stat, 0))
	var card := VBoxContainer.new()
	card.name = "Stat_%s" % str(def["id"])
	card.custom_minimum_size = Vector2(180, 300)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 8)
	card.process_mode = Node.PROCESS_MODE_ALWAYS

	var title := Label.new()
	title.text = "%s  Lv.%d → Lv.%d" % [str(def["title"]), current_stacks, current_stacks + 1]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font", UpgradeUIFont)
	title.add_theme_font_size_override("font_size", 22)
	card.add_child(title)

	var button := Button.new()
	button.name = "SelectButton"
	button.custom_minimum_size = Vector2(120, 120)
	button.text = str(def["title"])
	button.add_theme_font_override("font", UpgradeUIFont)
	button.add_theme_font_size_override("font_size", 34)
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(_choose_stat.bind(stat))
	card.add_child(button)

	var description := Label.new()
	description.text = str(def["desc"])
	description.custom_minimum_size = Vector2(170, 0)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_override("font", UpgradeUIFont)
	description.add_theme_font_size_override("font_size", 16)
	card.add_child(description)

	return card


func _choose_upgrade(option_id: String) -> void:
	_apply_upgrade(option_id)
	_finish_level_up()


func _choose_stat(stat: int) -> void:
	_apply_stat_upgrade(stat)
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
	auto_shooter.setup(player, enemies_layer, projectiles_layer, ProjectileScene)
	weapons_layer.add_child(auto_shooter)
	_unlocked_weapons.append(auto_shooter)
	_sync_weapon_stats(auto_shooter)


func _create_orbit_sword() -> void:
	var orbit_sword := OrbitSwordScene.new()
	orbit_sword.name = "OrbitSword"
	orbit_sword.setup(player)
	weapons_layer.add_child(orbit_sword)
	_unlocked_weapons.append(orbit_sword)
	_sync_weapon_stats(orbit_sword)


# 新武器解锁时,把当前已累积的 stat 堆叠同步过去(支持后续多武器共存)。
func _sync_weapon_stats(weapon: Node) -> void:
	for stat in _stat_stacks.keys():
		weapon.apply_stat(int(stat), int(_stat_stacks[stat]))


func _on_player_died() -> void:
	is_game_over = true
	is_level_up_open = false
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
