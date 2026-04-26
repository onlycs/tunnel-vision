extends AnimatedSprite2D

class Bystander:
	var sprite: String
	var speed: int
	var max_health: float
	
	func _init(p_sprite: String, p_speed: int, p_max_health: float) -> void:
		sprite = p_sprite
		speed = p_speed
		max_health = p_max_health

var RANDOM_SPRITES: Array[Bystander] = [
	Bystander.new("runner", 100., 8.),
	Bystander.new("normal", 75., 10.)
]

var _bystander = RANDOM_SPRITES[randi() % RANDOM_SPRITES.size()]

var _indicator: Sprite2D = null

func _ready() -> void:
	play(_bystander.sprite)

func _process(delta: float) -> void:
	position.y += Vars.scroll_speed * delta - 0.5 * _bystander.speed * delta * (!_is_gravestone as int)

	if position.y > 800:
		get_parent().queue_free()

func highlight(enabled: bool) -> void:
	if _is_gravestone:
		return
	
	if enabled:
		if _indicator != null:
			return
		_indicator = Sprite2D.new()
		_indicator.texture = preload("res://bystander/yellow_dot.png")
		_indicator.modulate = Color.YELLOW
		_indicator.position = Vector2(0, -80)  # relative to sprite, moves with it
		_indicator.scale = Vector2(0.35, 0.35)
		_indicator.z_index = 0
		_indicator.z_as_relative = false       # absolute z so it's not buried
		add_child(_indicator)                  # child of self, not get_parent()
	else:
		if _indicator != null:
			_indicator.queue_free()
			_indicator = null

var _is_gravestone: bool = false

func become_gravestone() -> void:
	_is_gravestone = true
	
	play("gravestone")
	
	if _indicator != null:
		_indicator.queue_free()
		_indicator = null

func is_gravestone() -> bool:
	return _is_gravestone
	
func bystander() -> Bystander:
	return _bystander
