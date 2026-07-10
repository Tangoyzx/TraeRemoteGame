extends Control

const IDLE_COLOR := Color(1.0, 0.0, 0.0, 1.0)
const CLICKED_COLOR := Color(0.0, 1.0, 0.0, 1.0)
const CLICK_DURATION_SECONDS := 2.0

@onready var color_box: ColorRect = $Center/VBox/ColorBox
@onready var click_button: Button = $Center/VBox/ClickButton

var _click_generation := 0

func _ready() -> void:
	color_box.color = IDLE_COLOR
	click_button.pressed.connect(_on_click_button_pressed)


func _on_click_button_pressed() -> void:
	_click_generation += 1
	var generation := _click_generation
	color_box.color = CLICKED_COLOR
	await get_tree().create_timer(CLICK_DURATION_SECONDS).timeout
	if generation == _click_generation:
		color_box.color = IDLE_COLOR
