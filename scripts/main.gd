extends Control

const WELCOME_TEXT := "欢迎"
const CLICKED_TEXT := "点击"
const CLICK_DURATION_SECONDS := 2.0

@onready var message_label: Label = $Center/VBox/MessageLabel
@onready var click_button: Button = $Center/VBox/ClickButton

var _click_generation := 0

func _ready() -> void:
	message_label.text = WELCOME_TEXT
	click_button.pressed.connect(_on_click_button_pressed)


func _on_click_button_pressed() -> void:
	_click_generation += 1
	var generation := _click_generation
	message_label.text = CLICKED_TEXT
	await get_tree().create_timer(CLICK_DURATION_SECONDS).timeout
	if generation == _click_generation:
		message_label.text = WELCOME_TEXT
