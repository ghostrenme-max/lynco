extends SceneTree
var checked := 0

func _initialize() -> void:
 for folder in ["res://scripts","res://effects","res://tests/support"]:
  scan(folder)
 print("SCRIPT_PARSE_PASS scripts=",checked)
 quit()

func scan(folder: String) -> void:
 for name in DirAccess.get_files_at(folder):
  if not name.ends_with(".gd"):continue
  var script=load(folder.path_join(name)) as GDScript
  assert(script!=null and script.can_instantiate(),"Invalid script: "+folder.path_join(name))
  checked+=1
 for name in DirAccess.get_directories_at(folder):
  if not name.begins_with("."):scan(folder.path_join(name))
