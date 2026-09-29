@tool
extends Node3D
@export_range(0.0, 4.0) var speed: float = 3.5
@export var phase: float = 0.0
@export var playing: bool = true
var elapsed: float = 0.0

func _ready() -> void:
	$Surface.material_override = $Surface.material_override.duplicate()
	seek(0.0)

func _process(delta: float) -> void:
	if playing:
		seek(elapsed + delta * speed)

func seek(seconds: float) -> void:
	elapsed = seconds
	$Surface.material_override.set_shader_parameter("flame_time", elapsed + phase)
