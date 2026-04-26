extends Sprite2D

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	region_rect.position.y -= Vars.scroll_speed * delta  / .266
