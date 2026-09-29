extends Control
@export var next_scene: String
var curtain: CanvasLayer

func _ready() -> void:
	curtain = get_tree().root.get_node_or_null("CurtainTransition") as CanvasLayer
	if curtain == null:
		curtain = preload("res://effects/curtain_transition/curtain_transition.tscn").instantiate()
		get_tree().root.add_child.call_deferred(curtain)
	$Switch.pressed.connect(func(): curtain.transition_to(next_scene))
	$Replay.pressed.connect(func(): curtain.play())
