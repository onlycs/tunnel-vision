extends Node2D

const BystanderScene = preload("res://bystander/bystander.tscn")
const g = preload("res://player/guy.gd")
const spawn_y = 40
const min_delay = 3.0
const max_delay = 8.0
const TARGET_Y = 400.0
const MAX_HEALTH = 10.0

var _spawn_positions = [g.pos_min, g.pos_ctr, g.pos_max]
var _bystanders: Array = []
var _highlighted: Node = null
var _health: float = MAX_HEALTH
var _dead: bool = false

@onready var _health_bar = $health

func _ready() -> void:
	_health_bar.max_value = MAX_HEALTH
	_health_bar.value = _health
	_spawn_bystander()
	_queue_next_spawn()

func _process(delta: float) -> void:
	if _dead:
		return
	_tick_health(delta)
	_update_highlight()
	if Input.is_key_pressed(KEY_E):
		inherit_highlighted()

func _tick_health(delta: float) -> void:
	_health -= delta
	_health_bar.value = _health
	if _health <= 0:
		die()

func die() -> void:
	_dead = true
	Vars.scroll_speed = 75
	get_tree().reload_current_scene()

func _queue_next_spawn() -> void:
	var delay = randf_range(min_delay, max_delay)
	await get_tree().create_timer(delay).timeout
	if _dead:
		return	 # don't spawn after death
	_spawn_bystander()
	_queue_next_spawn()

func _spawn_bystander() -> void:
	var x = _spawn_positions[randi() % _spawn_positions.size()]
	var b = BystanderScene.instantiate()
	b.position = Vector2(x, spawn_y)
	b.z_index = 1
	add_child(b)
	_bystanders.append(b)
	b.get_node("bystander_sprite/Area2D").area_entered.connect(_on_bystander_collision.bind(b))

var _slowed: bool = false

func _on_bystander_collision(other_area: Area2D, b: Node) -> void:
	# make sure it's the guy's area, not another bystander
	if not get_node("guy").is_ancestor_of(other_area):
		return
	var sprite = b.get_node("bystander_sprite")
	if sprite.is_gravestone() or _slowed:
		return
	_apply_slow()

func _apply_slow() -> void:
	_slowed = true
	Vars.scroll_speed *= 0.5
	get_node("cop").set_y()
	await get_tree().create_timer(3.0).timeout
	Vars.scroll_speed *= 2.0
	_slowed = false

func _update_highlight() -> void:
	_bystanders = _bystanders.filter(func(b): return is_instance_valid(b))
	if _bystanders.is_empty():
		return

	# filter out gravestones from consideration
	var living = _bystanders.filter(func(b): 
		return not b.get_node("bystander_sprite").is_gravestone()
	)
	if living.is_empty():
		return

	var nearest = living.reduce(func(closest, b):
		var closest_y = closest.get_node("bystander_sprite").global_position.y
		var b_y = b.get_node("bystander_sprite").global_position.y
		var cd = abs(closest_y - TARGET_Y)
		var bd = abs(b_y - TARGET_Y)
		return b if bd < cd else closest
	)

	var nearest_y = nearest.get_node("bystander_sprite").global_position.y
	var in_range = abs(nearest_y - TARGET_Y) <= 200.0

	if not in_range:
		if _highlighted != null and is_instance_valid(_highlighted):
			_highlighted.get_node("bystander_sprite").highlight(false)
			_highlighted = null
		return

	if nearest == _highlighted:
		return

	if _highlighted != null and is_instance_valid(_highlighted):
		_highlighted.get_node("bystander_sprite").highlight(false)

	nearest.get_node("bystander_sprite").highlight(true)
	_highlighted = nearest

	
func inherit_highlighted() -> void:
	# must have an active highlight (in range, not gravestone)
	if _highlighted == null or not is_instance_valid(_highlighted):
		return
	var sprite = _highlighted.get_node("bystander_sprite")
	if sprite.is_gravestone():
		_highlighted = null
		return

	var b = sprite.bystander()

	# stats
	_health = b.max_health
	_health_bar.max_value = _health
	Vars.scroll_speed = b.speed
	
	if _slowed: Vars.scroll_speed = Vars.scroll_speed * 0.5

	var guy = get_node("guy")
	
	# grab world positions before anything moves
	var old_guy_global_pos = guy.global_position
	var old_bystander_global_pos = sprite.global_position

	# swap in world space
	guy.global_position = old_bystander_global_pos
	sprite.global_position = old_guy_global_pos

	# gravestone
	sprite.become_gravestone()

	# clear highlight
	if _highlighted != null and is_instance_valid(_highlighted):
		sprite.highlight(false)
	_highlighted = null

	# tween guy to y=400
	var tween = create_tween()
	tween.tween_property(guy, "global_position:y", TARGET_Y, 2.0)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	
	tween = create_tween()
	tween.tween_property(get_node("cop"), "global_position:x", old_bystander_global_pos.x, 1.0).set_ease(Tween.EASE_OUT)
