extends RefCounted
static func load_cards(folder: String = "res://lynco_cards/cards") -> Dictionary:
 var result: Dictionary={}
 var directory:=DirAccess.open(folder)
 if directory==null:
  push_error("Card folder missing: "+folder)
  return result
 for file in directory.get_files():
  if file.ends_with(".remap"):file=file.trim_suffix(".remap")
  if file.ends_with(".tres"):
   var card=load(folder.path_join(file))
   if card!=null and card.has_method("as_dictionary"):result[card.id]=card
 return result
