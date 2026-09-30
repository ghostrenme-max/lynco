extends PanelContainer

var ui: Control
var caption: Label

func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("21171bf2")
 style.border_color=Color("80623d")
 style.set_border_width_all(1)
 style.set_corner_radius_all(6)
 style.content_margin_left=18;style.content_margin_right=18
 style.content_margin_top=9;style.content_margin_bottom=9
 add_theme_stylebox_override("panel",style)
 caption=Label.new()
 caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
 caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 caption.add_theme_font_size_override("font_size",18)
 add_child(caption)
 hide()

func _process(_delta: float) -> void:
 if not is_instance_valid(ui) or not is_instance_valid(ui.table):return
 var count: int=ui.model.placed.size()
 var capacity: int=ui.Model.CAPACITY
 var near_full:=count>=capacity-3
 var inspecting: bool=ui.table.top_view or ui.direction_hover_cell!=ui.Table.INVALID
 visible=(near_full or inspecting) and not ui.busy and not ui.model.finished and not ui.help_panel.visible and not ui.inspector_open
 if not visible:return
 caption.text="배치 %d / %d%s" % [count,capacity," · 빈칸 없음" if count>=capacity else (" · %d칸 남음" % (capacity-count) if near_full else "")]
 caption.add_theme_color_override("font_color",Color("f4d18b") if near_full else Color("eee3ce"))
 reset_size()
 var viewport_size:=get_viewport_rect().size
 if ui.table.top_view:
  position=Vector2((viewport_size.x-size.x)*0.5,viewport_size.y-size.y-24)
 else:
  var center: Vector2=ui.stage.get_global_transform_with_canvas()*Vector2(800,603)
  position=center-size*0.5
