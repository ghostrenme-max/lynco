extends RefCounted

# Shared visual direction helpers. Live definitions supply the same directions used by linked rules.
const MAGENTA := Color("f348bd")
const Grid = preload("res://scripts/board_geometry.gd")
const OFFSETS := Grid.OFFSETS
const BY_ICON := {
 "void":["right"], "eye":["up", "right"], "guard":["up"],
 "memory":["left"], "cycle":["down"], "link":["left", "right"],
}

static func for_definition(data: Dictionary) -> Array:
 if str(data.get("effect", "")) == "pending_back": return []
 if data.has("directions"):
  var result: Array=[]
  for key in data.directions:
   if OFFSETS.has(key) and key not in result:result.append(key)
  return result
 return BY_ICON.get(str(data.get("icon", "")), [])
