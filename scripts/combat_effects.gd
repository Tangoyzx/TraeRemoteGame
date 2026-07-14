class_name CombatEffects
extends Node

const ELEMENT_FIRE := "fire"
const ELEMENT_POISON := "poison"
const ELEMENT_FROST := "frost"

const FIRE_EXPLOSION_RADIUS := 50.0
const FIRE_EXPLOSION_DAMAGE := 50.0
const FIRE_EXPLOSION_COOLDOWN := 20.0

const POISON_DAMAGE_PER_SECOND := 10.0
const POISON_DURATION := 5.0

const FROST_DAMAGE_PER_SECOND := 2.0
const FROST_DURATION := 5.0
const FROST_SPEED_MULTIPLIER := 0.5

var enemies_layer: Node2D
var _unlocked_elements := {}
var _fire_explosion_cooldown := 0.0


func setup(enemy_container: Node2D) -> void:
	enemies_layer = enemy_container


func _process(delta: float) -> void:
	if _fire_explosion_cooldown > 0.0:
		_fire_explosion_cooldown = maxf(0.0, _fire_explosion_cooldown - delta)


func unlock_element(element_id: String) -> void:
	_unlocked_elements[element_id] = true


func is_element_unlocked(element_id: String) -> bool:
	return bool(_unlocked_elements.get(element_id, false))


func apply_weapon_hit(target, base_damage: float, hit_position: Vector2, _source_tags := {}) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.take_damage(base_damage)
	_try_fire_explosion(hit_position)
	if target == null or not is_instance_valid(target) or target.hp <= 0.0:
		return
	_apply_on_hit_debuffs(target)


func _try_fire_explosion(center: Vector2) -> void:
	if not is_element_unlocked(ELEMENT_FIRE) or _fire_explosion_cooldown > 0.0 or enemies_layer == null:
		return
	_fire_explosion_cooldown = FIRE_EXPLOSION_COOLDOWN
	var radius_sq := FIRE_EXPLOSION_RADIUS * FIRE_EXPLOSION_RADIUS
	for child in enemies_layer.get_children():
		if child.is_in_group("enemy") and is_instance_valid(child) and child.hp > 0.0:
			if center.distance_squared_to(child.global_position) <= radius_sq:
				child.take_damage(FIRE_EXPLOSION_DAMAGE)


func _apply_on_hit_debuffs(target) -> void:
	if is_element_unlocked(ELEMENT_POISON):
		target.apply_debuff(
			ELEMENT_POISON,
			POISON_DURATION,
			POISON_DAMAGE_PER_SECOND,
			1.0
		)
	if is_element_unlocked(ELEMENT_FROST):
		target.apply_debuff(
			ELEMENT_FROST,
			FROST_DURATION,
			FROST_DAMAGE_PER_SECOND,
			FROST_SPEED_MULTIPLIER
		)
