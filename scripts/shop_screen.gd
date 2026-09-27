extends Control

const UI = preload("res://scripts/screen_style.gd")
const Session = preload("res://scripts/collection_session.gd")
const Catalog = preload("res://scripts/catalog.gd")
var stage: Control
var balance: Label
var notice: Label
var buttons: Dictionary = {}

func _ready() -> void:
 theme = UI.make_theme()
 var bg := ColorRect.new()
 bg.color = UI.PAPER
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(bg)
 stage = Control.new(); stage.size = Vector2(1600,900); add_child(stage)
 resized.connect(_fit); _fit()
 UI.label(stage,"LYNCO / 덱 상점",Rect2(80,48,900,60),38)
 var back := UI.button(stage,"← 메인으로",Rect2(1270,48,250,54))
 back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
 balance = UI.label(stage,"",Rect2(80,142,1400,42),26)
 UI.label(stage,"덱 전체를 해금하고 다음 대전에서 사용하세요.",Rect2(80,196,1300,35),23,UI.MUTED)
 var i := 0
 for id in Session.DECKS:
  var data: Dictionary = Session.DECKS[id]
  var panel := UI.panel(stage,Rect2(80+i*735,275,705,410),Color.WHITE)
  UI.label(panel,str(data.name),Rect2(30,26,645,48),30)
  UI.label(panel,"덱 주인 · %s   /   %d장" % [data.owner,data.cards.size()],Rect2(30,86,645,36),22,UI.MUTED)
  var counts: Dictionary = {}
  for card_id in data.cards: counts[card_id] = int(counts.get(card_id,0))+1
  var lines := PackedStringArray()
  for card_id in counts: lines.append("%s ×%d" % [Catalog.card(card_id).name,counts[card_id]])
  var content := UI.label(panel," · ".join(lines),Rect2(30,145,630,122),22)
  content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  var button := UI.button(panel,"",Rect2(30,310,645,64),true)
  button.add_theme_color_override("font_disabled_color",UI.MUTED)
  button.add_theme_stylebox_override("disabled",UI.style(Color("e4e6df")))
  button.pressed.connect(_activate.bind(id)); buttons[id] = button
  i += 1
 notice = UI.label(stage,"",Rect2(80,722,1420,45),23)
 UI.label(stage,"시험용 가격·보상 / 골드와 해금은 앱 종료 시 초기화됩니다.",Rect2(80,812,1450,38),20,UI.MUTED)
 _refresh()

func _fit() -> void:
 var ratio := minf(size.x/1600.0,size.y/900.0)
 stage.scale = Vector2.ONE*ratio; stage.position = (size-stage.size*ratio)*0.5

func _activate(id: String) -> void:
 if id in Session.unlocked:
  Session.equip(id); notice.text = "다음 대전에서 %s 사용" % Session.DECKS[id].name
 else:
  var result := Session.purchase(id)
  notice.text = str(result.reason)
 _refresh()

func _refresh() -> void:
 balance.text = "보유 골드 %d  /  사용 덱 · %s" % [Session.gold,Session.DECKS[Session.selected].name]
 for id in buttons:
  var button: Button = buttons[id]
  button.disabled = id == Session.selected
  button.text = "사용 중" if id == Session.selected else ("이 덱 사용" if id in Session.unlocked else "%d 골드 · 덱 전체 해금" % Session.DECKS[id].price)
  if id not in Session.unlocked:
   button.disabled = Session.gold < int(Session.DECKS[id].price)
   button.tooltip_text = "골드가 부족합니다" if button.disabled else "덱 전체를 사용 목록에 추가합니다"

func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled()
  get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
