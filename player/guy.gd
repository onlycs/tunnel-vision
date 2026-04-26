extends AnimatedSprite2D

const pos_min: int = 533 - 120
var _current_pos: int = 533
const pos_max: int = 533 + 120
const pos_ctr: int = 533
const pos_delta: int = 120
var _tween: Tween = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	play("default")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

enum MoveCommand {
	Left = 2,
	Right = 1,
}

func cmd_guy(cmd: MoveCommand) -> void:
	match cmd:
		MoveCommand.Left: 
			_current_pos -= pos_delta
		MoveCommand.Right:
			_current_pos += pos_delta
	
	_current_pos = clampi(_current_pos, pos_min, pos_max)
	
	if _tween != null and _tween.is_running():
		_tween.stop()
	
	_tween = create_tween()
	_tween.tween_property(self, "position:x", _current_pos, 1).set_ease(Tween.EASE_OUT)
	
	
	create_tween().tween_property(get_parent().get_node("cop"), "position:x", _current_pos, 1).set_ease(Tween.EASE_IN_OUT)
