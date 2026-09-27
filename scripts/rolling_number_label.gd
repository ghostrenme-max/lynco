extends Label

static var reduced_motion := false
static var number_pattern: RegEx
var observed_text := ""
var initialized := false
var reels: Array[Control] = []
var number_material: ShaderMaterial
var changing := false
var tokens: Array[RegExMatch] = []
var layout_dirty := false
var active_mask := 0
var layout_updates := 0

class Reel extends Control:
 class Ink extends Control:
  func _draw() -> void:get_parent().paint(self)
 var strip: Control
 var font: Font
 var font_size: int
 var ink: Color
 var outline: Color
 var outline_size: int
 var start_value := 0.0
 var target_value := 0.0
 var steps := 1
 var decimals := 0
 var padding := 0
 var motion: Tween
 var active := false
 var progress := 0.0:
  set(value):
   progress=value
   queue_redraw()

 func _ready() -> void:
  strip=Ink.new()
  strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
  add_child(strip)

 func shown_value() -> float:
  return lerpf(start_value,target_value,progress/float(steps))

 func roll(from_value: float, to_value: float, format_text: String, quick: bool) -> void:
  if active:from_value=shown_value()
  if motion and motion.is_valid():motion.kill()
  start_value=from_value;target_value=to_value
  decimals=format_text.length()-format_text.find(".")-1 if "." in format_text else 0
  padding=format_text.length() if decimals==0 and format_text.begins_with("0") else 0
  steps=clampi(ceili(absf(to_value-from_value)*pow(10,decimals)),1,12)
  progress=0.0;active=true;show()
  motion=create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
  motion.tween_property(self,"progress",float(steps),0.08 if quick else 0.22+float(steps-1)*0.018)
  motion.finished.connect(func():active=false;hide())

 func finish() -> void:
  if motion and motion.is_valid():motion.kill()
  active=false;progress=float(steps);hide()

 func _draw() -> void:
  if is_instance_valid(strip):strip.queue_redraw()

 func paint(canvas: Control) -> void:
  if not active or font==null:return
  var index:=floori(progress)
  var fraction:=progress-float(index)
  var direction:=1.0 if target_value>=start_value else -1.0
  var ascent:=font.get_ascent(font_size)
  for row in range(index,index+2):
   if row>steps:continue
   var value: float=lerpf(start_value,target_value,float(row)/float(steps))
   var content: String=("%.*f" % [decimals,value]) if decimals>0 else str(roundi(value)).pad_zeros(padding)
   var width: float=font.get_string_size(content,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
   var fit: float=minf(1.0,size.x/maxf(width,1.0))
   var offset: float=(float(row-index)-fraction)*size.y*direction
   canvas.draw_set_transform(Vector2(0,offset),0,Vector2(fit,1))
   if outline_size>0:canvas.draw_string_outline(font,Vector2(0,ascent),content,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,outline_size,outline)
   canvas.draw_string(font,Vector2(0,ascent),content,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,ink)
  canvas.draw_set_transform(Vector2.ZERO)

func _ready() -> void:
 add_to_group("rolling_number_labels")
 if number_pattern==null:
  number_pattern=RegEx.new()
  number_pattern.compile("[0-9]+(?:\\.[0-9]+)?")
 observed_text=text
 tokens=number_pattern.search_all(text)
 initialized=not text.is_empty()
 resized.connect(_invalidate_layout)
 theme_changed.connect(_invalidate_layout)
 draw.connect(_invalidate_layout)

func _invalidate_layout() -> void:
 layout_dirty=true

func _process(_delta: float) -> void:
 if text!=observed_text:
  _change_text()
 if changing:
  var next_mask := 0
  for i in range(reels.size()):
   if reels[i].active:next_mask |= 1 << i
  if layout_dirty or next_mask!=active_mask:
   active_mask=next_mask
   _layout_reels()
  changing=next_mask!=0
  if not changing and number_material:number_material.set_shader_parameter("mask_count",0)

func _change_text() -> void:
 var before: Array[RegExMatch]=tokens
 var after: Array[RegExMatch]=number_pattern.search_all(text)
 tokens=after
 var animate: bool=initialized and is_visible_in_tree() and before.size()==after.size()
 observed_text=text;initialized=true
 if not animate:
  for reel in reels:reel.finish()
  if number_material:number_material.set_shader_parameter("mask_count",0)
  changing=false
  return
 for i in range(mini(after.size(),16)):
  if i>=reels.size():
   var reel:=Reel.new()
   reel.mouse_filter=Control.MOUSE_FILTER_IGNORE;reel.clip_contents=true
   add_child(reel);reels.append(reel);reel.hide()
  if before[i].get_string()==after[i].get_string():continue
  if number_material==null:
   number_material=ShaderMaterial.new()
   number_material.shader=preload("res://asset/number_mask.gdshader")
   material=number_material
  reels[i].roll(float(before[i].get_string()),float(after[i].get_string()),after[i].get_string(),reduced_motion)
 changing=reels.any(func(reel):return reel.active)
 _layout_reels()

func _layout_reels() -> void:
 layout_dirty=false
 if number_material==null:return
 layout_updates+=1
 var masks:=PackedVector4Array()
 for i in range(reels.size()):
  var reel=reels[i]
  if not reel.active or i>=tokens.size():continue
  var token: RegExMatch=tokens[i]
  var bounds: Rect2=get_character_bounds(token.get_start())
  for character in range(token.get_start()+1,token.get_end()):bounds=bounds.merge(get_character_bounds(character))
  if not bounds.has_area():reel.finish();continue
  reel.position=bounds.position
  reel.size=bounds.size
  reel.font=get_theme_font("font")
  reel.font_size=get_theme_font_size("font_size")
  reel.ink=get_theme_color("font_color")
  reel.outline=get_theme_color("font_outline_color")
  reel.outline_size=get_theme_constant("outline_size")
  reel.queue_redraw()
  masks.append(Vector4(bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y))
 number_material.set_shader_parameter("mask_count",masks.size())
 masks.resize(16)
 number_material.set_shader_parameter("masks",masks)

func finish_rolls() -> void:
 for reel in reels:reel.finish()
 changing=false
 if number_material:number_material.set_shader_parameter("mask_count",0)
