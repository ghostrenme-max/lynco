extends RefCounted

# Original supplied PNGs: light card -> black ink; dark card -> white ink.
# These are revealed-face symbols, never identifiers on the concealed card back.
const SPECIAL := {
 "king": [preload("res://assets/icons/king_black.png"), preload("res://assets/icons/king_white.png")],
 "joker": [preload("res://assets/icons/joker_black.png"), preload("res://assets/icons/joker_white.png")],
}

static var _textures: Dictionary = {}

static func is_special(data: Dictionary) -> bool:
 return SPECIAL.has(str(data.get("icon", "")))

static func texture_for(data: Dictionary, fallback: Texture2D = null) -> Texture2D:
 if is_special(data):
  return SPECIAL[str(data.icon)][1 if bool(data.get("dark", false)) else 0]
 if fallback != null: return fallback
 var icon: String = str(data.icon)
 if not _textures.has(icon):
  _textures[icon] = load("res://assets/icons/%s.png" % icon)
 return _textures[icon]

static func material_for(data: Dictionary, fallback: Material) -> Material:
 # Preserve the supplied artwork, including its alpha and antialiasing.
 return null if is_special(data) else fallback
