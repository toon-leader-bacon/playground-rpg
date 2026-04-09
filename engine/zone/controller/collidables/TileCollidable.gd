extends Node
class_name TileCollidable

var _handler: Callable = Callable()
var _enter_handler: Callable = Callable()
var _exit_handler: Callable = Callable()

func set_handler(handler: Callable) -> void:
	_handler = handler

func set_enter_handler(handler: Callable) -> void:
	_enter_handler = handler

func set_exit_handler(handler: Callable) -> void:
	_exit_handler = handler

func on_player_collide(player: Node2D) -> void:
	if _handler.is_valid():
		_handler.call(player)

func on_player_enter(player: Node2D) -> void:
	if _enter_handler.is_valid():
		_enter_handler.call(player)

func on_player_exit(player: Node2D) -> void:
	if _exit_handler.is_valid():
		_exit_handler.call(player)
