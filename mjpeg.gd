extends Node

const SHM_PATH = "/tmp/godot_frame.bin"
const WIDTH = 320
const HEIGHT = 240
const FRAME_SIZE = WIDTH * HEIGHT * 3

var _image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGB8)
var _texture: ImageTexture = null
var _rect: TextureRect = null

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	if _rect == null:
		var scene = get_tree().current_scene
		if scene:
			_rect = scene.get_node_or_null("CanvasLayer/camera")
		return

	var file = FileAccess.open(SHM_PATH, FileAccess.READ)
	if file == null:
		return

	var flag = file.get_8()
	if flag != 1:
		file.close()
		return

	var raw = file.get_buffer(FRAME_SIZE)
	file.close()  # close and reopen every frame — this is the key

	if raw.size() < FRAME_SIZE:
		return

	_image.set_data(WIDTH, HEIGHT, false, Image.FORMAT_RGB8, raw)

	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)

	if _rect:
		_rect.texture = _texture
