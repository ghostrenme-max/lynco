extends Control

const UI = preload("res://scripts/theatre_style.gd")
const Session = preload("res://scripts/collection_session.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Symbols = preload("res://scripts/card_symbols.gd")
# Presentation-only fixtures: not added to Session.DECKS or battle/editor data.
const DUMMY_DECKS := [
 {"id":"preview_curtain","name":"붉은 커튼의 덱","owner":"미정","preview":true,"icon":"eye"},
 {"id":"preview_seat","name":"빈자리의 덱","owner":"미정","preview":true,"icon":"memory"}
]
var stage: Control
var balance: Label
var notice: Label
var buttons: Dictionary = {}
var scroll: ScrollContainer
var deck_grid: GridContainer
var deck_panels: Dictionary = {}
var back_button: Button

func _ready() -> void:
 theme=UI.make_theme()
 UI.background(self)
 stage=Control.new();stage.size=Vector2(1600,900);add_child(stage)
 UI.art(stage)
 resized.connect(_fit);_fit()
 UI.title(stage,"LYNCO  /  덱 상점",Rect2(120,32,790,76),48)
 back_button=UI.button(stage,"← 메인으로",Rect2(1270,48,210,52))
 back_button.pressed.connect(func():get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
 UI.rule(stage,Rect2(120,123,1360,1))
 balance=UI.label(stage,"",Rect2(120,143,1140,34),23,UI.PAPER)
 UI.label(stage,"덱 %d개  ·  아래로 스크롤 ↓" % (Session.DECKS.size()+DUMMY_DECKS.size()),Rect2(1180,145,310,30),18,UI.SOFT)
 scroll=ScrollContainer.new()
 scroll.name="DeckScroll"
 scroll.position=Vector2(120,200);scroll.size=Vector2(1360,590)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
 scroll.follow_focus=true
 stage.add_child(scroll)
 var bar:=scroll.get_v_scroll_bar()
 bar.custom_minimum_size.x=14
 bar.add_theme_stylebox_override("scroll",UI.style(Color("262017")))
 bar.add_theme_stylebox_override("grabber",UI.style(UI.YELLOW.darkened(0.3)))
 bar.add_theme_stylebox_override("grabber_highlight",UI.style(UI.YELLOW))
 bar.add_theme_stylebox_override("grabber_pressed",UI.style(UI.PAPER))
 deck_grid=GridContainer.new();deck_grid.columns=2
 deck_grid.add_theme_constant_override("h_separation",24)
 deck_grid.add_theme_constant_override("v_separation",24)
 scroll.add_child(deck_grid)
 for id in Session.DECKS:
  var data: Dictionary=Session.DECKS[id].duplicate(true)
  data["id"]=id;data["cards"]=Session.deck_cards(id)
  _deck(data)
 for data in DUMMY_DECKS:_deck(data)
 notice=UI.label(stage,"",Rect2(120,802,1360,32),20,UI.PAPER)
 UI.label(stage,"시험용 가격 · 골드와 해금은 실행 중에만 유지됩니다.   /   더미 덱은 전시용입니다.",Rect2(120,848,1360,30),17,UI.SOFT)
 _refresh()

func _deck(data: Dictionary) -> void:
 var id: String=str(data.id)
 var dummy: bool=bool(data.get("preview",false))
 var panel:=PanelContainer.new()
 panel.custom_minimum_size=Vector2(656,540)
 panel.add_theme_stylebox_override("panel",UI.style(Color("19150feF"),UI.YELLOW.darkened(0.4),1))
 deck_grid.add_child(panel);deck_panels[id]=panel
 var content:=Control.new();content.custom_minimum_size=Vector2(652,536)
 content.mouse_filter=Control.MOUSE_FILTER_PASS
 panel.add_child(content)
 var title:=UI.title(content,str(data.name),Rect2(28,20,596,45),30)
 title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var subtitle: String="더미 덱 · 전시용 / 구성 미정" if dummy else "덱 주인 · %s  /  %d장" % [data.owner,data.cards.size()]
 var owner:=UI.label(content,subtitle,Rect2(28,75,596,30),19,UI.SOFT)
 owner.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 UI.rule(content,Rect2(28,116,596,1))
 var art_dark: bool=id=="remnant" or id=="preview_seat"
 var pack:=UI.panel(content,Rect2(46,148,174,236),UI.RED.darkened(0.45) if art_dark else UI.RED)
 UI.rule(pack,Rect2(12,12,150,1));UI.rule(pack,Rect2(12,222,150,1))
 var icon_id: String=str(data.get("icon","void" if art_dark else "link"))
 UI.symbol(pack,load("res://assets/icons/"+icon_id+".png"),Rect2(37,58,100,100),true)
 var caption:=UI.label(pack,"LYNCO",Rect2(14,177,146,35),25,UI.PAPER)
 caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 UI.label(content,"구성 미정" if dummy else "구성 카드",Rect2(254,146,340,30),21,UI.PAPER)
 if dummy:
  UI.symbol(content,load("res://assets/icons/"+icon_id+".png"),Rect2(334,199,120,120),true)
  UI.label(content,"목록 확장과 스크롤 확인용",Rect2(254,352,350,36),19,UI.SOFT)
 else:
  var counts: Dictionary={}
  for card_id in data.cards:counts[card_id]=int(counts.get(card_id,0))+1
  var row:=0
  for card_id in counts:
   var card: Dictionary=Catalog.table_card(str(card_id))
   UI.symbol(content,Symbols.texture_for(card),Rect2(254,192+row*34,25,25),true)
   UI.label(content,"%s × %d" % [card.name,counts[card_id]],Rect2(294,188+row*34,316,30),20,UI.PAPER)
   row+=1
 var price:=UI.label(content,"전시용 · 구매 불가" if dummy else ("기본 제공" if int(data.price)==0 else "%d 골드" % int(data.price)),Rect2(28,410,596,28),20,UI.YELLOW)
 price.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var button:=UI.button(content,"전시용 더미 덱" if dummy else "",Rect2(28,453,596,58),true)
 if dummy:button.disabled=true
 else:button.pressed.connect(_activate.bind(id));buttons[id]=button

func _fit() -> void:
 UI.Base.fit_stage(stage,size)

func _activate(id: String) -> void:
 if not Session.DECKS.has(id):return
 if id in Session.unlocked:
  Session.equip(id);notice.text="다음 대전에서 %s 사용" % Session.DECKS[id].name
 else:
  var result: Dictionary=Session.purchase(id)
  notice.text=str(result.reason)
 _refresh()

func _refresh() -> void:
 balance.text="보유 골드 %d   /   사용 덱 · %s" % [Session.gold,Session.DECKS[Session.selected].name]
 for id in buttons:
  var button: Button=buttons[id]
  var insufficient: bool=id not in Session.unlocked and Session.gold<int(Session.DECKS[id].price)
  button.disabled=id==Session.selected or insufficient
  button.text="사용 중" if id==Session.selected else ("이 덱 사용" if id in Session.unlocked else ("골드 부족 · %d 골드" % Session.DECKS[id].price if insufficient else "%d 골드 · 덱 전체 해금" % Session.DECKS[id].price))
  button.tooltip_text="골드가 부족합니다" if insufficient else ""

func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled()
  get_tree().change_scene_to_file("res://scenes/main_menu.tscn")