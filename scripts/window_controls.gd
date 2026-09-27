extends Node

var saved_mode: Window.Mode = Window.MODE_WINDOWED
var saved_size := Vector2i.ZERO
var saved_position := Vector2i.ZERO

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
 handle_shortcut(event)

func handle_shortcut(event: InputEvent) -> bool:
 if not event is InputEventKey or not event.pressed or event.echo:return false
 if event.physical_keycode!=KEY_L and event.keycode!=KEY_L:return false
 toggle_fullscreen()
 get_viewport().set_input_as_handled()
 return true

func toggle_fullscreen() -> void:
 var window:=get_tree().root
 if window.mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN]:
  window.mode=saved_mode
  if saved_mode==Window.MODE_WINDOWED and saved_size!=Vector2i.ZERO:
   window.size=saved_size
   window.position=saved_position
 else:
  saved_mode=window.mode
  saved_size=window.size
  saved_position=window.position
  window.mode=Window.MODE_FULLSCREEN
