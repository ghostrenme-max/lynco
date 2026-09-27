extends Control

const UI = preload("res://scripts/screen_style.gd")
const Card = preload("res://scripts/card_view.gd")
const Symbols = preload("res://scripts/card_symbols.gd")
var stage: Control

func _ready() -> void:
 theme = UI.make_theme()
 var background := ColorRect.new()
 background.color = UI.PAPER
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 background.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(background)
 stage = Control.new()
 stage.size = Vector2(1600, 900)
 add_child(stage)
 resized.connect(_fit)
 _fit()
 UI.label(stage, "LYNCO   /   킹 · 조커", Rect2(80, 53, 1440, 70), 42)
 UI.label(stage, "제공된 원본 로고 · 흰 카드에는 검정 심볼, 검정 카드에는 흰 심볼", Rect2(82, 136, 1440, 42), 23, UI.MUTED)
 var ink: ShaderMaterial = UI.ink_material()
 var white: ShaderMaterial = UI.ink_material(true)
 for i in range(4):
  var dark: bool = i >= 2
  var symbol: String = "king" if i % 2 == 0 else "joker"
  var title: String = "킹" if symbol == "king" else "조커"
  var definition := {"name":title, "cost":"—", "kind":"심볼 확인", "dark":dark, "icon":symbol, "text":"로고 적용 예시\n효과 · 비용 미정"}
  var x: float = 100 + i * 365
  UI.label(stage, ("검정 카드" if dark else "흰 카드") + " · " + title, Rect2(x, 222, 320, 43), 23)
  var card := Card.new()
  stage.add_child(card)
  card.setup({"uid":i}, definition, Symbols.texture_for(definition), white if dark else ink, null)
  card.pivot_offset = Vector2.ZERO
  card.position = Vector2(x, 292)
  card.scale = Vector2.ONE * 1.9
  card.locked = true
  card.mouse_filter = Control.MOUSE_FILTER_IGNORE
 UI.label(stage, "표시 전용 확인 씬입니다. 전투 카드나 효과를 추가하지 않습니다.", Rect2(82, 806, 1440, 40), 21, UI.MUTED)
 if OS.get_cmdline_user_args().has("--capture-symbols"):
  await get_tree().create_timer(0.4).timeout
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://test-results/king_joker_symbols_1440.png")
  get_window().size = Vector2i(1280, 720)
  await get_tree().create_timer(0.3).timeout
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://test-results/king_joker_symbols_1280.png")
  print("LYNCO_SYMBOL_PREVIEW_CAPTURED")
  get_tree().quit()

func _fit() -> void:
 var ratio: float = minf(size.x / 1600.0, size.y / 900.0)
 stage.scale = Vector2.ONE * ratio
 stage.position = (size - Vector2(1600, 900) * ratio) * 0.5
