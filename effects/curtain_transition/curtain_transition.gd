extends CanvasLayer
## Add once under SceneTree.root, or instance for play() without changing scenes.
signal covered
signal transition_finished(success: bool)
signal transition_failed(message: String)



enum Stage { IDLE, CLOSING, HOLDING, SWITCHING, OPENING }
@export_range(0.25, 3.0) var speed: float = 1.0
@export_range(0.0, 5.0) var closed_hold_seconds: float = 1.0
@export_range(1.0, 60.0) var load_timeout: float = 20.0
var busy: bool = false
var stage: Stage = Stage.IDLE
var _viewport: SubViewport
var _cloth: Node3D
var _closed_backing: ColorRect
var _content: Node2D
var _blocker: Control
var _elapsed: float = 0.0
var _load_elapsed: float = 0.0
var _target: String = ""
var _covered_sent: bool = false
var _success: bool = true
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_content = Node2D.new()
	_content.name = "Curtains"
	add_child(_content)
	_viewport = SubViewport.new()
	_viewport.name = "ClothViewport"
	_viewport.size = Vector2i(1920,1080)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_content.add_child(_viewport)
	_cloth = Node3D.new()
	_cloth.set_script(preload("res://effects/curtain_transition/curtain_3d.gd"))
	_viewport.add_child(_cloth)
	_closed_backing = ColorRect.new()
	_closed_backing.color = Color(0.025,0.002,0.004)
	_closed_backing.size = Vector2(1920,1080)
	_closed_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_closed_backing.hide()
	_content.add_child(_closed_backing)
	var display := TextureRect.new()
	display.texture = _viewport.get_texture()
	display.size = Vector2(1920,1080)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(display)
	_blocker = Control.new()
	_blocker.name = "TransitionInputBlocker"
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blocker)
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()
	_cloth.set_frame(0.0)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hide()
	set_process(false)
	set_process_input(false)

## Animation only: open -> closed -> open; emits covered at full coverage.
func play() -> Error:
	if busy:
		return ERR_BUSY
	_start("")
	return OK

## Preload asynchronously, cover, switch, then reveal. Never loops automatically.
func transition_to(scene_path: String) -> Error:
	if busy:
		return ERR_BUSY
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		transition_failed.emit("Scene does not exist: " + scene_path)
		return ERR_FILE_NOT_FOUND
	var err := ResourceLoader.load_threaded_request(scene_path, "PackedScene")
	if err != OK:
		transition_failed.emit("Could not request scene: " + scene_path)
		return err
	# Scene changes free current_scene. Keep the overlay outside that subtree.
	if get_parent() != get_tree().root:
		reparent(get_tree().root)
	_start(scene_path)
	return OK

func _start(path: String) -> void:
	_closed_backing.hide()
	_target = path
	_elapsed = 0.0
	_load_elapsed = 0.0
	_covered_sent = false
	_success = true
	busy = true
	stage = Stage.CLOSING
	_cloth.set_frame(0.0)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	show()
	set_process_input(true)
	set_process(true)

func _input(_event: InputEvent) -> void:
	if busy:
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_elapsed += delta if stage == Stage.HOLDING else delta * speed
	_load_elapsed += delta
	match stage:
		Stage.CLOSING:
			var frame := maxf(_elapsed-0.10,0.0)*60.0
			_cloth.set_frame(minf(frame,60.0))
			if frame >= 60.0:
				_closed_backing.show()
				_covered_sent = true
				stage = Stage.HOLDING
				_elapsed = 0.0
				covered.emit()
		Stage.HOLDING:
			_cloth.set_frame(minf(60.0+_elapsed*60.0,66.0))
			if _elapsed < closed_hold_seconds:
				return
			if _target.is_empty():
				_begin_open()
				return
			var status := ResourceLoader.load_threaded_get_status(_target)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				stage = Stage.SWITCHING
				_switch_scene.call_deferred()
			elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_fail("Scene loading failed: " + _target)
			elif _load_elapsed > load_timeout:
				_fail("Scene loading timed out: " + _target)
		Stage.OPENING:
			_cloth.set_frame(minf(66.0+_elapsed*60.0,130.0))
			if _elapsed >= 1.10:
				_finish()

func _switch_scene() -> void:
	# load_threaded_get is called only after THREAD_LOAD_LOADED; it does not wait on disk.
	var scene := ResourceLoader.load_threaded_get(_target) as PackedScene
	if scene == null:
		_fail("Loaded resource is not a scene: " + _target)
		return
	var err := get_tree().change_scene_to_packed(scene)
	if err != OK:
		_fail("Scene switch failed: " + str(err))
		return
	await get_tree().scene_changed
	await get_tree().process_frame
	_begin_open()

func _fail(message: String) -> void:
	_success = false
	transition_failed.emit(message)
	_begin_open()

func _begin_open() -> void:
	_closed_backing.hide()
	stage = Stage.OPENING
	_elapsed = 0.0
	_cloth.set_frame(66.0)

func _finish() -> void:
	_cloth.set_frame(130.0)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hide()
	busy = false
	stage = Stage.IDLE
	_target = ""
	set_process(false)
	set_process_input(false)
	transition_finished.emit(_success)

func _fit_viewport() -> void:
	var size := get_viewport().get_visible_rect().size
	_content.scale = size / Vector2(1920, 1080)
	_blocker.size = size


