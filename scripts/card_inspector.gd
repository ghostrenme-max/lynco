extends CanvasLayer

# Presentation owns its controls; battle_ui owns card selection and game input.
const UI = preload("res://scripts/screen_style.gd")
const Symbols = preload("res://scripts/card_symbols.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Directions = preload("res://scripts/direction_preview.gd")
const DirectionDiagram = preload("res://scripts/direction_diagram.gd")
const INK := UI.INK
const MUTED := UI.MUTED
var textures: Dictionary
var dark_ink: ShaderMaterial
var light_ink: ShaderMaterial
var preview_icon: TextureRect
var preview_title: Label
var preview_cost: Label
var preview_text: Label
var preview_kind: Label
var preview_effect: Label
var inspector_root: Control
var inspector_card: Panel
var inspector_styles: Dictionary = {}
var inspector_demo: Panel
var inspector_comparison: Panel
var comparison_bands: Array[Panel] = []
var comparison_titles: Array[Label] = []
var comparison_effects: Array[Label] = []
var inspector_diagram: Control
var direction_note: Label
var inspector_score: Control

func _ready() -> void:
 layer=30
 inspector_root=Control.new();inspector_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(inspector_root)
 var copy:=BackBufferCopy.new();copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT
 inspector_root.add_child(copy)
 var backdrop:=ColorRect.new()
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var blur:=ShaderMaterial.new();blur.shader=preload("res://asset/card_inspector_blur.gdshader")
 backdrop.material=blur;inspector_root.add_child(backdrop)
 inspector_card=_panel(inspector_root,Vector2.ZERO,Vector2(440,620),Color.WHITE,24)
 inspector_styles[false]=_style(Color("fefefb"),24,Color("c5c8c1"),1)
 inspector_styles[true]=_style(Color("181a19"),24,Color("454943"),1)
 preview_cost=_label(inspector_card,"",Vector2(24,24),Vector2(50,58),42)
 preview_title=_label(inspector_card,"",Vector2(87,30),Vector2(188,48),32)
 preview_kind=_label(inspector_card,"",Vector2(87,84),Vector2(322,28),18)
 preview_icon=_icon(inspector_card,"eye",Vector2(130,145),Vector2(180,180))
 preview_text=_label(inspector_card,"",Vector2(30,358),Vector2(380,152),23)
 preview_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 preview_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 preview_effect=_label(inspector_card,"",Vector2(24,529),Vector2(392,52),19)
 preview_effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 preview_effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 inspector_score=preload("res://scripts/table_cost_badge.gd").new()
 inspector_score.position=Vector2(285,28);inspector_score.size=Vector2(132,44)
 inspector_card.add_child(inspector_score)
 var hint:=_label(inspector_card,"우클릭 · Esc · 바깥 클릭으로 닫기",Vector2(20,587),Vector2(400,24),14)
 hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 hint.name="CloseHint"
 inspector_demo=_panel(inspector_root,Vector2.ZERO,Vector2(350,386),Color("202322"),18)
 _label(inspector_demo,"방향 시연",Vector2(24,20),Vector2(302,36),24,Color("f6f6f2"))
 inspector_diagram=DirectionDiagram.new()
 inspector_diagram.position=Vector2(35,70);inspector_diagram.size=Vector2(280,242)
 inspector_demo.add_child(inspector_diagram)
 direction_note=_label(inspector_demo,"",Vector2(22,326),Vector2(306,46),16,Color("c5c8c1"))
 direction_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 inspector_comparison=_panel(inspector_root,Vector2.ZERO,Vector2(350,620),Color("161b18"),18)
 for i in range(2):
  var band:=Panel.new()
  band.position=Vector2(14,14+i*302);band.size=Vector2(322,290)
  band.add_theme_stylebox_override("panel",_style(Color("303832"),16,Color.TRANSPARENT,0))
  band.mouse_filter=Control.MOUSE_FILTER_IGNORE
  inspector_comparison.add_child(band)
  comparison_bands.append(band)
  var heading:=_label(inspector_comparison,"",Vector2(28,32+i*302),Vector2(294,68),22)
  heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  comparison_titles.append(heading)
  var effect:=_label(inspector_comparison,"",Vector2(28,110+i*302),Vector2(294,172),21)
  effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  comparison_effects.append(effect)
 var separator:=ColorRect.new()
 separator.position=Vector2(28,309);separator.size=Vector2(294,1)
 separator.color=Color("434c46");separator.mouse_filter=Control.MOUSE_FILTER_IGNORE
 inspector_comparison.add_child(separator)
 get_viewport().size_changed.connect(_fit_inspector)
 _fit_inspector();inspector_root.hide()

func _fit_inspector() -> void:
 if not is_instance_valid(inspector_card):return
 var viewport_size:Vector2=get_viewport().get_visible_rect().size
 var ratio:float=minf(viewport_size.x/1600.0,viewport_size.y/900.0)
 inspector_card.scale=Vector2.ONE*ratio
 inspector_card.position=(viewport_size-inspector_card.size*ratio)*0.5
 inspector_demo.scale=Vector2.ONE*ratio
 inspector_demo.position=viewport_size*0.5+Vector2(260,-193)*ratio
 inspector_comparison.scale=Vector2.ONE*ratio
 inspector_comparison.position=viewport_size*0.5+Vector2(-610,-310)*ratio

func present(data: Dictionary, source_id: String, reverse: bool, reduced_motion: bool) -> void:
 var dark:bool=bool(data.dark)
 var ink:Color=Color("f6f6f2") if dark else INK
 var secondary:Color=Color("bfc2ba") if dark else MUTED
 inspector_card.add_theme_stylebox_override("panel",inspector_styles[dark])
 for label in [preview_title,preview_cost,preview_text]:label.add_theme_color_override("font_color",ink)
 for label in [preview_kind,preview_effect,inspector_card.get_node("CloseHint")]:label.add_theme_color_override("font_color",secondary)
 preview_icon.material=Symbols.material_for(data, light_ink if dark else dark_ink)
 inspector_diagram.configure(data,reduced_motion)
 direction_note.text="출발 카드 방향 → 대상 주인\n발동 조건은 왼쪽에서 확인" if not Directions.for_definition(data).is_empty() else "이 카드에는 연결 방향이 없습니다"
 preview_text.tooltip_text=str(data.get("memo",""))
 inspector_score.dark=dark
 inspector_score.replay_count(str(data.get("table_cost","—")),reduced_motion)
 var title_font: Font=preview_title.get_theme_font("font")
 var title_width: float=title_font.get_string_size(preview_title.text,HORIZONTAL_ALIGNMENT_LEFT,-1,32).x
 preview_title.add_theme_font_size_override("font_size",mini(32,floori(32.0*188.0/maxf(title_width,1.0))))
 inspector_score.queue_redraw()
 inspector_root.show()
 _refresh_inspector_comparison(data,source_id,reverse)

func _refresh_inspector_comparison(data: Dictionary, source_id: String, reverse: bool) -> void:
 inspector_comparison.visible=str(data.get("identity","normal")) not in ["king","joker"]
 if not inspector_comparison.visible or source_id not in Catalog.runtime_ids():return
 var definitions: Array[Dictionary]=[Catalog.table_card(source_id),Catalog.back_card(source_id)]
 for i in range(2):
  var active: bool=reverse==(i==1)
  comparison_bands[i].self_modulate.a=1.0 if active else 0.08
  comparison_titles[i].self_modulate.a=1.0 if active else 0.10
  comparison_effects[i].self_modulate.a=1.0 if active else 0.10
  comparison_titles[i].text=("앞면" if i==0 else "뒷면")+" · "+str(definitions[i].name)
  comparison_titles[i].add_theme_color_override("font_color",Color("f5f7f2") if active else Color("6e7a71"))
  comparison_effects[i].text=str(definitions[i].get("rule_detail",definitions[i].text)) if i==0 else str(definitions[i].text)
  comparison_effects[i].add_theme_font_size_override("font_size",19)
  comparison_effects[i].add_theme_color_override("font_color",Color("f0f3ec") if active else Color("929d94"))

func _style(bg: Color, radius: int = 10, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
 return UI.style(bg,border,width,radius)

func _panel(parent: Node, pos: Vector2, box: Vector2, bg: Color, radius: int = 10, border: Color = Color.TRANSPARENT) -> Panel:
 var panel := Panel.new(); panel.position = pos; panel.size = box
 panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 panel.add_theme_stylebox_override("panel", _style(bg, radius, border, 1 if border.a > 0 else 0))
 parent.add_child(panel)
 return panel

func _label(parent: Node, text: String, pos: Vector2, box: Vector2, font_size: int = 18, color: Color = INK) -> Label:
 return UI.label(parent,text,Rect2(pos,box),font_size,color)

func _icon(parent: Node, key: String, pos: Vector2, box: Vector2, white: bool = false) -> TextureRect:
 var icon := TextureRect.new(); icon.position = pos; icon.size = box
 icon.texture = textures[key]; icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
 icon.material = light_ink if white else dark_ink
 parent.add_child(icon)
 return icon
