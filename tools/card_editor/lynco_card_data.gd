class_name LyncoEditedCard
extends Resource
@export var id: String = ""
@export var card_name: String = ""
@export_multiline var description: String = ""
@export var kind: String = ""
@export var action_cost: int = -1
@export_range(-1,5) var table_cost: int = -1
@export var dark: bool = false
@export var icon: Texture2D
@export var face: String = "front"
@export var source_id: String = ""
@export var effect_id: String = "pending"
@export var effect_value: int = 0
@export var status: String = "pending"
@export var directions: PackedStringArray = []
@export var base_effect: String = ""
@export var link_effect: String = ""
@export var link_condition: String = ""
@export var link_trigger: String = ""
@export var base_value: int = 0
@export var link_value: int = 0
@export var investment_cost: int = 0
@export var invest_bonus: int = 0
@export var deck_starter: int = 0
@export var deck_remnant: int = 0
@export var requires_investment: bool = false
const OFFSETS := {"up":Vector2i(0,-1),"up_right":Vector2i(1,-1),"right":Vector2i(1,0),"down_right":Vector2i(1,1),"down":Vector2i(0,1),"down_left":Vector2i(-1,1),"left":Vector2i(-1,0),"up_left":Vector2i(-1,-1)}
func target_cells(origin: Vector2i, board_size: Vector2i = Vector2i(6,5)) -> Array[Vector2i]:
 var result: Array[Vector2i]=[]
 for key in directions:
  if not OFFSETS.has(key):continue
  var cell: Vector2i=origin+OFFSETS[key]
  if cell.x>=0 and cell.y>=0 and cell.x<board_size.x and cell.y<board_size.y and cell not in result:result.append(cell)
 return result
func as_dictionary() -> Dictionary:
 return {"id":id,"name":card_name,"kind":kind,"text":description,"detail":description,"cost":action_cost,"table_cost":table_cost,"dark":dark,"face":face,"source_id":source_id,"effect":effect_id,"value":effect_value,"status":status,"directions":Array(directions),"base_effect":base_effect,"base_value":base_value,"link_effect":link_effect,"link_value":link_value,"link_condition":link_condition,"link_trigger":link_trigger,"investment_cost":investment_cost,"invest_bonus":invest_bonus,"requires_investment":requires_investment}
