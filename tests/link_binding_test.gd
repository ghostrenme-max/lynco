extends SceneTree

func _initialize() -> void:run.call_deferred()

func run() -> void:
 create_timer(40).timeout.connect(func():push_error("Link binding test timed out");quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 var ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 assert(ui._verification_runner==null,"Ordinary startup must not construct test harnesses")
 ui._set_reduced_motion(true)
 var model=ui.model
 var table=ui.table
 assert(table.link_eligibility.is_valid())
 for cell in [Vector2i(-1,0),Vector2i(6,0),Vector2i(0,5)]:assert(not table.free_cell(cell))
 model.energy=100
 model.hand.assign([{"id":"observe","uid":700},{"id":"guard","uid":701}])
 var definition: Dictionary=model.definitions.observe
 definition.base_effect="none";definition.link_effect="score";definition.link_condition="ally"
 definition.link_trigger="any";definition.requires_investment=true
 definition.directions=["up","right"]
 var source:=Vector2i(2,2);var target:=Vector2i(3,2)
 assert(model.play_at(700,source).ok and model.play_at(701,target).ok)
 table.place("observe",source,true);table.place("guard",target,true)
 table.select_influence(source)
 assert(table.influenced_cells.is_empty(),"Unfunded required-investment link must not glow")
 table.sync_investment_markers(model.cell_map)
 for cell in [source,target]:
  assert(table.cards[cell].get_node_or_null("InvestmentLabel")==null,"No empty label allocation")
 model.cubes.player=100
 assert(model.invest(source).ok)
 table.refresh_link_rules();table.sync_investment_markers(model.cell_map)
 assert(target in table.influenced_cells,"Investment enables the actual model link")
 var marker=table.cards[source].get_node("InvestmentLabel")
 assert(marker.visible)
 model.cell_map[target].owner="opponent"
 table.mark_owner(target,"opponent");table.refresh_link_rules()
 assert(table.influenced_cells.is_empty(),"Ally restriction must not highlight an opponent")
 definition.link_condition="enemy";table.refresh_link_rules()
 assert(target in table.influenced_cells)
 model.turn+=int(model.rules.recover_delay)
 assert(model.recover(source).ok)
 table.refresh_link_rules();table.sync_investment_markers(model.cell_map)
 assert(table.influenced_cells.is_empty() and not marker.visible)
 assert(table.cards[source].get_node("InvestmentLabel")==marker,"Reuse labels after recovery")
 print("LINK_BINDING_PASS model_callback investment owner_conditions bounds lazy_labels lazy_tests")
 quit()
