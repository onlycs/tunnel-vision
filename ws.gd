# ws.gd
extends Node

var socket := WebSocketPeer.new()
var _last_state := -1

const e = preload("res://player/guy.gd")

func _ready() -> void:
	var tls = TLSOptions.client_unsafe()
	socket.connect_to_url("ws://localhost:5001/", tls)

func _process(_delta: float) -> void:
	socket.poll()
	var state = socket.get_ready_state()
	if state != _last_state:
		_last_state = state
		if state == WebSocketPeer.STATE_OPEN:
			print("WS connected")
		elif state == WebSocketPeer.STATE_CLOSED:
			print("WS closed: ", socket.get_close_code(), " ", socket.get_close_reason())
	
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet()
			var text = packet.get_string_from_utf8()
			_handle_message(text)

func _handle_message(text: String) -> void:
	var val = text.to_int()
	var scene = get_tree().current_scene
	
	if !is_instance_valid(scene):
		return
	
	var guy = scene.get_node("guy")
	match val:
		1:
			guy.cmd_guy(e.MoveCommand.Right)
		2:
			guy.cmd_guy(e.MoveCommand.Left)
		3:
			scene.inherit_highlighted()
