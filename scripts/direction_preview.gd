extends RefCounted

# Presentation-only trial data. No combat rule consumes these directions.
const MAGENTA := Color("f348bd")
const OFFSETS := {"up":Vector2.UP, "right":Vector2.RIGHT, "down":Vector2.DOWN, "left":Vector2.LEFT}
const BY_ICON := {
 "void":["right"], "eye":["up", "right"], "guard":["up"],
 "memory":["left"], "cycle":["down"], "link":["left", "right"],
}

static func for_definition(data: Dictionary) -> Array:
 if str(data.get("effect", "")) == "pending_back": return []
 return BY_ICON.get(str(data.get("icon", "")), [])
