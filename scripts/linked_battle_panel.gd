extends Panel
const UI=preload("res://scripts/screen_style.gd")
var battle: Control
var balance: Label
var selection: Label
var invest_button: Button
var recover_button: Button
var preview_label: Label
var last_text := ""

func setup(host: Control) -> void:
 battle=host
 position=Vector2(28,155);size=Vector2(420,268);z_index=75
 mouse_filter=Control.MOUSE_FILTER_STOP
 add_theme_stylebox_override("panel",UI.style(Color(0.97,0.97,0.94,0.96),Color.TRANSPARENT,0,14))
 balance=UI.label(self,"",Rect2(16,10,388,68),18)
 selection=UI.label(self,"테이블 카드를 클릭해 투자 / 회수",Rect2(16,81,388,64),16)
 selection.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 invest_button=UI.button(self,"투자",Rect2(16,153,187,40))
 recover_button=UI.button(self,"회수",Rect2(215,153,187,40))
 invest_button.pressed.connect(func():battle._linked_action(false))
 invest_button.add_theme_font_size_override("font_size",17)
 recover_button.add_theme_font_size_override("font_size",17)
 recover_button.pressed.connect(func():battle._linked_action(true))
 preview_label=UI.label(self,"",Rect2(16,202,388,57),15)
 preview_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var timer:=Timer.new();timer.wait_time=0.1;timer.timeout.connect(refresh);add_child(timer);timer.start()

func refresh() -> void:
 if not is_instance_valid(battle) or battle.model.rules.is_empty():return
 var m=battle.model
 var current_cell: Vector2i=battle.table.selected_cell
 balance.text="큐브  내 %d (+투자 %d)  /  상대 %d (+투자 %d)\n성과  내 %d / 상대 %d   ·   최대 %d턴" % [m.cubes.player,m.invested_total("player"),m.cubes.opponent,m.invested_total("opponent"),m.performance.player,m.performance.opponent,m.rules.max_turns]
 var locked: bool=battle.busy or battle.inspector_open or battle.help_panel.visible or is_instance_valid(battle.inventory_layer) or battle.drag_uid>=0 or m.finished
 var why_invest: String=m.investment_reason(current_cell)
 var why_recover: String=m.investment_reason(current_cell,true)
 invest_button.disabled=locked or not why_invest.is_empty()
 recover_button.disabled=locked or not why_recover.is_empty()
 invest_button.tooltip_text=why_invest;recover_button.tooltip_text=why_recover
 if m.cell_map.has(current_cell):
  var r: Dictionary=m.cell_map[current_cell];var c: Dictionary=m.definitions[r.entry.id]
  selection.text="%s · %s\n투자 %d · %s" % ["내 카드" if r.owner=="player" else "상대 카드",c.name,r.invested,why_recover if not why_recover.is_empty() else "회수 가능"]
  invest_button.text="투자 %d 큐브" % int(c.investment_cost)
  recover_button.text="회수 (비용 최대 %d)" % int(m.rules.recover_fee)
 else:
  selection.text="테이블 카드를 클릭해 투자 / 회수\n상대 카드도 방향 조건으로 연결 가능"
  invest_button.text="투자";recover_button.text="회수"
 var uid: int=battle.drag_uid if battle.drag_uid>=0 else battle.selected_uid
 var message: String="내 카드 선택 → 투자·회수 · 연결 효과는 대상 주인에게"
 if uid>=0:
  var point: Vector2=battle.stage.get_global_transform_with_canvas().affine_inverse()*battle.get_viewport().get_mouse_position()
  message=m.preview_at(uid,battle.table.cell_at(point))
 if message!=last_text:preview_label.text=message;last_text=message
