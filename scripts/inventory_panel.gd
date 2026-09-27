extends Control
signal closed
const Session=preload("res://scripts/collection_session.gd")
var stage: Control
var title_label: Label
var description_label: Label
var source_label: Label
var preview: TextureRect
var placeholder: Label
var item_list: Control
var carousel_tween: Tween
var scroll_bar: VScrollBar
var selected_index: int=-1
var item_buttons: Array[Button]=[]

func label(parent: Node, text: String, pos: Vector2, box: Vector2, font_size: int) -> Label:
 var node:=preload("res://scripts/rolling_number_label.gd").new();node.text=text;node.position=pos;node.size=box
 node.add_theme_font_size_override("font_size",font_size)
 node.add_theme_color_override("font_color",Color("eeeee8"))
 node.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(node)
 return node

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_STOP
 var backdrop:=ColorRect.new()
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop.color=Color.WHITE
 var blur:=ShaderMaterial.new();blur.shader=preload("res://asset/inventory_blur.gdshader")
 backdrop.material=blur;backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(backdrop)
 stage=Control.new();stage.size=Vector2(1600,900);add_child(stage)
 var panel:=Panel.new();panel.position=Vector2(225,40);panel.size=Vector2(1150,820)
 var style:=StyleBoxFlat.new();style.bg_color=Color("171b18");style.set_corner_radius_all(10)
 panel.add_theme_stylebox_override("panel",style);stage.add_child(panel)
 label(panel,"보유 아이템",Vector2(55,35),Vector2(650,44),28)
 var line:=ColorRect.new();line.position=Vector2(190,95);line.size=Vector2(565,3);line.color=Color("73786e")
 line.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(line)
 var frame:=Panel.new();frame.position=Vector2(300,150);frame.size=Vector2(370,330)
 var border:=StyleBoxFlat.new();border.bg_color=Color("1b201c");border.border_color=Color("bfc5b9");border.set_border_width_all(2)
 frame.add_theme_stylebox_override("panel",border);panel.add_child(frame)
 preview=TextureRect.new();preview.position=Vector2(38,35);preview.size=Vector2(294,260)
 preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(preview)
 placeholder=label(frame,"◇",Vector2(0,55),Vector2(370,200),110)
 placeholder.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 title_label=label(panel,"",Vector2(135,530),Vector2(700,50),30)
 title_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 source_label=label(panel,"",Vector2(135,586),Vector2(700,32),17)
 source_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 source_label.add_theme_color_override("font_color",Color("969f91"))
 description_label=label(panel,"",Vector2(155,640),Vector2(660,110),21)
 description_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 description_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 item_list=Control.new();item_list.position=Vector2(845,118);item_list.size=Vector2(210,626)
 item_list.clip_contents=true;panel.add_child(item_list)
 scroll_bar=VScrollBar.new();scroll_bar.position=Vector2(1080,138);scroll_bar.size=Vector2(10,586)
 scroll_bar.step=1;scroll_bar.page=0
 var rail:=StyleBoxFlat.new();rail.bg_color=Color("4b514a");rail.content_margin_left=4;rail.content_margin_right=4
 scroll_bar.add_theme_stylebox_override("scroll",rail)
 var thumb:=StyleBoxFlat.new();thumb.bg_color=Color("90958a");thumb.content_margin_top=28;thumb.content_margin_bottom=28
 for state in ["grabber","grabber_highlight","grabber_pressed"]:scroll_bar.add_theme_stylebox_override(state,thumb)
 panel.add_child(scroll_bar)
 scroll_bar.value_changed.connect(func(value: float):select_item(int(value)))
 label(panel,"F / Esc · 닫기",Vector2(900,772),Vector2(200,25),15)
 resized.connect(_fit);_fit();refresh()

func _fit() -> void:
 var ratio:=minf(size.x/1600.0,size.y/900.0)
 stage.scale=Vector2.ONE*ratio;stage.position=(size-stage.size*ratio)*0.5

func refresh() -> void:
 if carousel_tween:carousel_tween.kill()
 for child in item_list.get_children():item_list.remove_child(child);child.queue_free()
 item_buttons.clear()
 for i in range(Session.items.size()):
  var entry: Dictionary=Session.items[i]
  var button:=Button.new();button.size=Vector2(180,118);button.pivot_offset=button.size*0.5
  button.clip_contents=true
  button.text=str(entry.get("name","아이템"))
  button.add_theme_font_size_override("font_size",18)
  var icon_path: String=str(entry.get("icon",""))
  if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
   button.text=""
   var thumbnail:=TextureRect.new()
   thumbnail.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
   thumbnail.texture=load(icon_path);thumbnail.position=Vector2(49,10);thumbnail.size=Vector2(80,78)
   thumbnail.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
   thumbnail.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(thumbnail)
   var caption:=label(button,str(entry.get("name","아이템")),Vector2(6,90),Vector2(166,24),13)
   caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  button.toggle_mode=true
  var normal:=StyleBoxFlat.new();normal.bg_color=Color("62695f");normal.set_corner_radius_all(4)
  button.add_theme_stylebox_override("normal",normal)
  var active: StyleBoxFlat=normal.duplicate();active.bg_color=Color("62695f");active.border_color=Color("e2e7d8");active.set_border_width_all(2)
  button.add_theme_stylebox_override("pressed",active)
  button.add_theme_stylebox_override("hover",normal)
  button.add_theme_stylebox_override("hover_pressed",active)
  button.pressed.connect(select_item.bind(i));item_list.add_child(button);item_buttons.append(button)
 scroll_bar.max_value=maxi(0,Session.items.size()-1)
 scroll_bar.visible=Session.items.size()>1
 if Session.items.is_empty():
  selected_index=-1;preview.texture=null;placeholder.text="—";placeholder.show()
  title_label.text="보유한 아이템이 없습니다"
  source_label.text=""
  description_label.text="일반 상점이나 암시장에서 획득한 아이템이 여기에 표시됩니다."
 else:
  select_item(clampi(selected_index,0,Session.items.size()-1))
  _layout_items(false)

func select_item(index: int) -> void:
 if index<0 or index>=Session.items.size():return
 selected_index=index
 var entry: Dictionary=Session.items[index]
 title_label.text=str(entry.get("name","아이템"))
 description_label.text=str(entry.get("description",""))
 source_label.text="암시장" if str(entry.get("source","shop"))=="black_market" else "일반 상점"
 var icon_path: String=str(entry.get("icon",""))
 preview.texture=load(icon_path) if not icon_path.is_empty() and ResourceLoader.exists(icon_path) else null
 placeholder.text="◇";placeholder.visible=preview.texture==null
 for i in range(item_buttons.size()):item_buttons[i].set_pressed_no_signal(i==index)
 scroll_bar.set_value_no_signal(index)
 _layout_items(true)

func _input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP or event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
   var step:=1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1
   select_item(clampi(selected_index+step,0,Session.items.size()-1))
   get_viewport().set_input_as_handled()

func _layout_items(animate: bool) -> void:
 if carousel_tween:carousel_tween.kill()
 if animate:
  carousel_tween=create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
 for i in range(item_buttons.size()):
  var button:=item_buttons[i]
  var offset:=i-selected_index
  var distance:=absi(offset)
  var item_scale:=maxf(0.64,1.0-distance*0.16)
  var brightness:=maxf(0.32,1.0-distance*0.24)
  var target_position:=Vector2(15,254+offset*124)
  var target_color:=Color(brightness,brightness,brightness,1.0)
  button.mouse_filter=Control.MOUSE_FILTER_STOP if distance<=2 else Control.MOUSE_FILTER_IGNORE
  if animate:
   carousel_tween.tween_property(button,"position",target_position,0.18)
   carousel_tween.tween_property(button,"scale",Vector2.ONE*item_scale,0.18)
   carousel_tween.tween_property(button,"modulate",target_color,0.18)
  else:
   button.position=target_position;button.scale=Vector2.ONE*item_scale;button.modulate=target_color
