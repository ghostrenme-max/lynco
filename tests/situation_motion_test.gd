extends SceneTree

func _initialize() -> void:call_deferred("run")

func run() -> void:
 change_scene_to_file("res://scenes/battle.tscn")
 await scene_changed
 var ui:=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var symbols: Control=ui.situation_symbols
 symbols.set_round(2)
 symbols.set_turns(7,8)
 assert(symbols.compressions.size()==1 and symbols.sparks.is_empty(),"compression precedes explosion")
 await create_timer(0.08).timeout
 assert(symbols.sparks.size()==36,"one consumed dot emits six stars and thirty sparks")
 assert(symbols.sparks.filter(func(p):return p.hero).size()==6,"six major stars")
 assert(symbols.sparks.filter(func(p):return p.afterglow).size()==3,"three lingering highlights")
 var initial_horizontal_speed: float=absf(symbols.sparks[0].velocity.x)
 var initial_vertical_speed: float=symbols.sparks[0].velocity.y
 await create_timer(0.25).timeout
 assert(symbols.round_time>0.0 and symbols.round_time<1.15,"round motion starts")
 assert(absf(symbols.sparks[0].velocity.x)<initial_horizontal_speed,"horizontal drag slows spread")
 assert(not symbols.sparks.is_empty() and symbols.sparks[0].velocity.y>initial_vertical_speed,"gravity pulls particles downward")
 for spark in symbols.sparks:assert(spark.distance<spark.travel,"particles stay within travel budget")
 var before: float=symbols.round_time
 symbols.set_round(2)
 symbols.set_turns(7,8)
 assert(symbols.round_time==before,"repeated refresh does not restart animation")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/motion_glow.png")
 await create_timer(1.2).timeout
 assert(not symbols.is_processing(),"animation sleeps after settling")
 assert(symbols.sparks.is_empty() and symbols.flashes.is_empty(),"burst fully expires")
 symbols.set_round(3)
 symbols.set_reduced_motion(true)
 assert(not symbols.is_processing(),"reduced motion cancels active effects")
 symbols.set_round(4)
 symbols.set_turns(5,8)
 assert(symbols.sparks.is_empty(),"reduced motion suppresses bursts")
 assert(not symbols.is_processing(),"reduced motion prevents new effects")
 ui._animate_seal(1.045)
 await create_timer(0.3).timeout
 assert(is_equal_approx(ui.end_button.scale.x,1.045),"hover spring settles")
 ui._animate_seal(0.93)
 ui._animate_seal(1.0)
 await create_timer(0.3).timeout
 assert(ui.end_button.scale.is_equal_approx(Vector2.ONE),"rapid interaction settles without stacking")
 print("SITUATION_MOTION_PASS")
 quit()
