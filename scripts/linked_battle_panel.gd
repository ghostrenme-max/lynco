extends Panel
const UI=preload("res://scripts/screen_style.gd")
var battle: Control
var balance: Label
var selection: Label
var invest_button: Button
var recover_button: Button
var preview_label: Label
var stats_button: Button
var stats_panel: Panel
var socket_button: Button
var taught := false
var last_cell:=Vector2i(-1,-1)

func label_at(parent: Node, text: String, rect: Rect2, font_size: int=17) -> Label:
 var label:=Label.new();label.text=text;label.position=rect.position;label.size=rect.size
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",Color("efe5d2"))
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(label)
 return label

func setup(host: Control) -> void:
 battle=host
 size=Vector2(302,156);z_index=155
 mouse_filter=Control.MOUSE_FILTER_STOP
 add_theme_stylebox_override("panel",UI.style(Color("20171bf5"),Color("9c7e4b"),1,8))
 selection=label_at(self,"",Rect2(14,10,274,25),18)
 invest_button=UI.button(self,"＋ 투자",Rect2(14,46,132,38))
 recover_button=UI.button(self,"− 회수",Rect2(156,46,132,38))
 for button in [invest_button,recover_button]:button.add_theme_font_size_override("font_size",16)
 invest_button.pressed.connect(func():battle._linked_action(false))
 recover_button.pressed.connect(func():battle._linked_action(true))
 preview_label=label_at(self,"",Rect2(14,94,274,53),15)
 preview_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 stats_button=UI.button(battle.stage,"전투 현황",Rect2(28,88,122,34))
 stats_button.add_theme_font_size_override("font_size",16)
 stats_button.z_index=155
 stats_button.tooltip_text="보유·투자 큐브와 누적 성과"
 stats_panel=Panel.new();stats_panel.position=Vector2(28,132);stats_panel.size=Vector2(328,154);stats_panel.z_index=156
 stats_panel.add_theme_stylebox_override("panel",UI.style(Color("20171bf5"),Color("80633d"),1,8))
 battle.stage.add_child(stats_panel)
 balance=label_at(stats_panel,"",Rect2(16,12,296,134),17)
 stats_panel.hide()
 stats_button.pressed.connect(func():stats_panel.visible=not stats_panel.visible)
 socket_button=UI.button(battle.stage,"◇ ＋",Rect2(0,0,85,33))
 socket_button.z_index=156;socket_button.add_theme_font_size_override("font_size",16)
 socket_button.pressed.connect(func():
  var cell: Vector2i=battle.table.selected_cell
  if battle.model.cell_map.has(cell):battle._linked_action(int(battle.model.cell_map[cell].invested)>0))
 socket_button.hide();hide()
 var timer:=Timer.new();timer.wait_time=0.05;timer.timeout.connect(refresh);add_child(timer);timer.start()

func contains_ui(point: Vector2) -> bool:
 for control in [self,stats_button,stats_panel,socket_button]:
  if control.is_visible_in_tree() and control.get_global_rect().has_point(point):return true
 return false

func refresh() -> void:
 if not is_instance_valid(battle) or battle.model.rules.is_empty():return
 var m=battle.model
 var cell: Vector2i=battle.table.selected_cell
 balance.text="전투 현황             나 / 상대\n보유 큐브          %d / %d\n투자 큐브          %d / %d\n누적 성과          %d / %d\n성과는 최종 판정 점수와 별도" % [m.cubes.player,m.cubes.opponent,m.invested_total("player"),m.invested_total("opponent"),m.performance.player,m.performance.opponent]
 var locked: bool=battle.busy or battle.inspector_open or battle.help_panel.visible or is_instance_valid(battle.inventory_layer) or battle.drag_uid>=0 or m.finished
 stats_button.visible=not locked
 if locked:stats_panel.hide()
 visible=not locked and m.cell_map.has(cell)
 socket_button.visible=visible
 if not visible:return
 var record: Dictionary=m.cell_map[cell]
 var data: Dictionary=m.definitions[record.entry.id]
 var own: bool=record.owner=="player"
 var why_invest: String=m.investment_reason(cell)
 var why_recover: String=m.investment_reason(cell,true)
 invest_button.disabled=not why_invest.is_empty();recover_button.disabled=not why_recover.is_empty()
 var fee:=mini(int(record.invested),int(m.rules.recover_fee))
 invest_button.text="＋ 투자 %d" % int(data.investment_cost)
 recover_button.text="− 회수 %d" % maxi(0,int(record.invested)-fee)
 invest_button.tooltip_text=why_invest if not why_invest.is_empty() else "보유 큐브 %d개 투자 · 카드의 투자 조건 활성" % int(data.investment_cost)
 recover_button.tooltip_text=why_recover if not why_recover.is_empty() else "큐브 %d개 받음 · 회수 비용 %d" % [int(record.invested)-fee,fee]
 selection.text="%s · 투자 %d" % [str(data.name),record.invested]
 preview_label.text=("회수: "+why_recover) if record.invested>0 and not why_recover.is_empty() else ("투자: "+why_invest if not why_invest.is_empty() else "투자 %d큐브 · 회수 비용 최대 %d" % [data.investment_cost,m.rules.recover_fee])
 socket_button.text="◆ %d −" % int(record.invested) if record.invested>0 else "◇ ＋"
 socket_button.disabled=not (why_recover if record.invested>0 else why_invest).is_empty()
 socket_button.tooltip_text=recover_button.tooltip_text if record.invested>0 else invest_button.tooltip_text
 socket_button.visible=own
 var linked_enemy:=false
 for target in battle.table.influenced_cells:
  if m.cell_map.has(target) and m.cell_map[target].owner!=record.owner and m.link_allowed_at(cell,target):linked_enemy=true
 if linked_enemy:preview_label.text+="\n상대 카드도 연결 조건 충족 · 효과는 대상 주인에게"
 if not own and not linked_enemy:preview_label.text="상대 카드에는 투자·회수할 수 없습니다"
 var center: Vector2=battle.table.screen_position(cell)
 position=Vector2(clampf(center.x+114,12,1600-size.x-12),clampf(center.y-78,210,650-size.y))
 if center.x>1150:position.x=maxf(12,center.x-114-size.x)
 var holder: Node3D=battle.table.cards[cell]
 var socket_world: Vector3=holder.to_global(Vector3(0,0.20,0.65))
 var socket_point: Vector2=battle.stage.get_global_transform_with_canvas().affine_inverse()*battle.table.camera.unproject_position(socket_world)
 socket_button.position=Vector2(clampf(socket_point.x-42,12,1503),clampf(socket_point.y-16,206,620))
 if own and not taught:
  taught=true
  battle._toast("카드 옆 ＋ 투자 · 카드 위 ◇로도 투자 / ◆로 회수")
 last_cell=cell