extends AnimatedSprite2D

@onready var area2 = $Area2D
var slowed = false

func _ready() -> void:
	area2.monitoring = true
	area2.area_entered.connect(_collide)
	play("default")

func _collide(node: Node) -> void:
	if node.get_parent().name == "guy":
		node.get_parent().get_parent().die()
	if node.get_parent().name == "bystander_sprite":
		if node.get_parent().is_gravestone() and not slowed:
			_apply_slow()

func _apply_slow() -> void:
	slowed = true
	await get_tree().create_timer(3.0).timeout
	slowed = false

func _process(delta: float) -> void:
	var slow_factor = 0.5 if slowed else 1.0
	var speed_factor = 3 if position.y > 750 else 1.0
	position.y += Vars.scroll_speed * delta - 90.0 * delta * slow_factor * speed_factor

func set_x(x: int) -> void:
	position.x = x

func set_y() -> void:
	position.y = 720
