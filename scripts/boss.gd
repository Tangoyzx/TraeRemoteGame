class_name Boss
extends Enemy

var boss_name := "Square Colossus"

func _ready() -> void:
	super()
	add_to_group("boss")

func apply_config(config: Dictionary) -> void:
	super(config)
	boss_name = str(config.get("boss_name", boss_name))
