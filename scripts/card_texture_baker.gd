extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")
const Card = preload("res://scripts/card_view.gd")
const Symbols = preload("res://scripts/card_symbols.gd")

static func bake(parent: Node, table: Node3D, ui_theme: Theme, textures: Dictionary, dark_ink: ShaderMaterial, light_ink: ShaderMaterial) -> void:
 # Bake each definition once; all placed instances share its texture/material.
 var pending:Dictionary={}
 var bake_ids: Array = Catalog.runtime_ids()
 for front_id in Catalog.runtime_ids(): bake_ids.append("reverse:" + str(front_id))
 for front_id in Catalog.runtime_ids(): bake_ids.append("opponent:" + str(front_id))
 bake_ids.append_array(["back_white","back_black"])
 for raw_id in bake_ids:
  var id: String=str(raw_id)
  var canvas:=SubViewport.new();canvas.size=Vector2i(316,456)
  canvas.transparent_bg=true;canvas.disable_3d=true
  canvas.render_target_update_mode=SubViewport.UPDATE_ONCE
  parent.add_child(canvas)
  var definition: Dictionary=_definition(id)
  var sample:=Card.new();sample.theme=ui_theme;canvas.add_child(sample)
  sample.setup({"uid":-1},definition,Symbols.texture_for(definition, textures.get(definition.icon)),light_ink if bool(definition.dark) else dark_ink,textures["back_black" if bool(definition.dark) else "back_white"])
  sample.pivot_offset=Vector2.ZERO;sample.scale=Vector2(2,2);sample.locked=true
  sample.set_face_up(not str(id).begins_with("back_"))
  sample.outline_style.shadow_size=0
  if str(id).begins_with("opponent:"):
   sample.outline_style.bg_color=Color("101211") if bool(definition.dark) else Color("c8cac4")
  pending[id]=canvas
 await RenderingServer.frame_post_draw
 for id in pending:
  var canvas:SubViewport=pending[id]
  var pixels:=canvas.get_texture().get_image()
  pixels.generate_mipmaps()
  if str(id).begins_with("back_"):table.set_back_texture(id,ImageTexture.create_from_image(pixels))
  else:table.set_card_texture(id,ImageTexture.create_from_image(pixels))
  canvas.queue_free()

static func _definition(id: String) -> Dictionary:
 if id.begins_with("reverse:"):
  return Catalog.back_card(id.trim_prefix("reverse:"))
 if id.begins_with("back_"):
  return Catalog.table_card("guard" if id=="back_white" else "strike")
 return Catalog.table_card(id.trim_prefix("opponent:"))
