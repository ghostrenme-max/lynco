extends Control

const IVORY := Color("f5e7c8")
const GOLD := Color("b69559")
var remaining := 8
var maximum := 8
var reduced_motion := false
var round_number := -1
var previous_remaining := 8
var motion_time := 2.0
var round_time := 2.0
const MOTION_DURATION := 1.15
const BURST_GRAVITY := 240.0
const BURST_DISTANCE := 120.0
var sparks: Array[Dictionary]=[]
var flashes: Array[Dictionary]=[]
var compressions: Array[Dictionary]=[]
const COMPRESSION_TIME := 0.06
var effect_layer: Node2D
var glow_layer: Node2D
var glow_texture: ImageTexture

func _ready() -> void:
 var pixel:=Image.create(1,1,false,Image.FORMAT_RGBA8)
 pixel.fill(Color.WHITE)
 glow_texture=ImageTexture.create_from_image(pixel)
 glow_layer=Node2D.new()
 glow_layer.z_index=9
 var glow_material:=ShaderMaterial.new()
 glow_material.shader=preload("res://scripts/turn_glow.gdshader")
 glow_layer.material=glow_material
 add_child(glow_layer)
 glow_layer.draw.connect(_draw_turn_glow)
 effect_layer=Node2D.new()
 effect_layer.z_index=10
 add_child(effect_layer)
 effect_layer.draw.connect(_draw_bursts)
 set_process(false)

func _draw_turn_glow() -> void:
 for i in range(mini(remaining,maximum)):
  var pulse:=1.0
  if not reduced_motion and motion_time<MOTION_DURATION:
   var t:=maxf(0.0,motion_time-float(maximum-1-i)*0.025)
   pulse+=0.25*sin(t*19.0)*exp(-t*7.0)
  var extent: float=(28.0 if maximum<=10 else 14.0)*pulse
  glow_layer.draw_texture_rect(glow_texture,Rect2(dot_position(i)-Vector2.ONE*extent,Vector2.ONE*extent*2.0),false)
 for compression in compressions:
  var t: float=clampf(compression.age/COMPRESSION_TIME,0.0,1.0)
  var extent: float=(28.0 if maximum<=10 else 14.0)*lerpf(1.0,0.68,t)
  glow_layer.draw_texture_rect(glow_texture,Rect2(compression.position-Vector2.ONE*extent,Vector2.ONE*extent*2.0),false,Color(1,1,1,1.0+t*1.6))
 for flash in flashes:
  var t: float=flash.age/0.24
  var extent: float=22.0+48.0*sin(t*PI*0.5)
  glow_layer.draw_texture_rect(glow_texture,Rect2(flash.position-Vector2.ONE*extent,Vector2.ONE*extent*2.0),false,Color(1,1,1,pow(1.0-t,1.6)))
 for spark in sparks:
  var alpha:=spark_alpha(spark)
  var extent: float=13.0 if spark.hero else 6.0
  glow_layer.draw_texture_rect(glow_texture,Rect2(spark.position-Vector2.ONE*extent,Vector2.ONE*extent*2.0),false,Color(1,1,1,alpha*0.7))

func noise_value(seed_value: float) -> float:
 return fposmod(sin(seed_value*127.1+311.7)*43758.5453,1.0)

func spark_alpha(spark: Dictionary) -> float:
 var life: float=spark.life
 var age: float=spark.age
 var base: float=(1.0-smoothstep(float(spark.travel)*0.65,float(spark.travel),float(spark.distance)))*(1.0-smoothstep(life*0.62,life,age))
 if spark.afterglow:
  base*=1.0+1.8*exp(-pow((age-life*0.78)/0.055,2.0))
 return base

func is_burst_active() -> bool:
 return not compressions.is_empty() or not sparks.is_empty() or not flashes.is_empty()

func prepare_burst(index: int) -> void:
 compressions.append({"index":index,"position":dot_position(index),"age":0.0})
 set_process(true)

func dot_position(index: int) -> Vector2:
 var columns:=mini(maximum,10)
 var rows:=ceili(float(maximum)/10.0)
 return Vector2(522+float(index%10)*182.0/maxf(1.0,float(columns-1)),94+14.0*float(index/10+1)/float(rows+1))

func burst_dot(index: int) -> void:
 var origin:=dot_position(index)
 flashes.append({"position":origin,"age":0.0})
 for j in range(36):
  # Independent stratified directions and speeds prevent aligned rows or spirals.
  var seed_value:=float(j+index*53)
  var angle:=TAU*(float(j)+noise_value(seed_value))/36.0
  var hero:=j%6==0
  var afterglow:=j in [0,12,24]
  var speed: float=(150.0 if hero else 65.0)+noise_value(seed_value+70.0)*(85.0 if hero else 65.0)
  var life: float=(0.86+noise_value(seed_value+340.0)*0.10) if afterglow else ((0.64+noise_value(seed_value+340.0)*0.14) if hero else (0.32+noise_value(seed_value+340.0)*0.25))
  sparks.append({"origin":origin,"position":origin,"velocity":Vector2(cos(angle),sin(angle))*speed,
   "distance":0.0,"age":0.0,"size":3.1 if hero else 0.8+noise_value(seed_value+200.0)*1.3,"hero":hero,
   "life":life,"afterglow":afterglow,"travel":170.0 if hero else 65.0})
 set_process(true)

func _draw_bursts() -> void:
 for flash in flashes:
  var t: float=flash.age/0.24
  var p: Vector2=flash.position
  effect_layer.draw_arc(p,4.0+33.0*t,0,TAU,56,Color(0.36,0.79,1.0,0.5*pow(1.0-t,2.0)),1.0,true)
  for j in range(7):
   var direction:=Vector2.from_angle(TAU*float(j)/7.0+0.2)
   var normal:=direction.orthogonal()
   var length:=24.0+55.0*t
   effect_layer.draw_polygon(PackedVector2Array([p-normal*2.5,p+direction*length,p+normal*2.5]),PackedColorArray([Color(0.35,0.7,1.0,0.38*(1.0-t)),Color(0.2,0.5,1.0,0.0),Color(0.35,0.7,1.0,0.38*(1.0-t))]))
 for spark in sparks:
  var alpha:=spark_alpha(spark)
  var radius: float=spark.size
  var p: Vector2=spark.position
  if spark.hero:
   var direction: Vector2=spark.velocity.normalized()
   var normal:=direction.orthogonal()
   var tail: Vector2=p-direction*minf(23.0,float(spark.age)*110.0)
   effect_layer.draw_polygon(PackedVector2Array([p-normal*2.0,p+normal*2.0,tail]),PackedColorArray([Color(0.3,0.85,1.0,alpha*0.65),Color(0.3,0.85,1.0,alpha*0.65),Color(0.2,0.6,1.0,0.0)]))
   effect_layer.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-radius*1.6),p+Vector2(radius*0.35,-radius*0.35),p+Vector2(radius*1.6,0),p+Vector2(radius*0.35,radius*0.35),p+Vector2(0,radius*1.6),p+Vector2(-radius*0.35,radius*0.35),p+Vector2(-radius*1.6,0),p+Vector2(-radius*0.35,-radius*0.35)]),Color(0.8,0.97,1.0,alpha))
  else:
   effect_layer.draw_rect(Rect2(p-Vector2.ONE*radius,Vector2.ONE*radius*2.0),Color(0.66,0.9,1.0,alpha))
 effect_layer.draw_set_transform(Vector2.ZERO)

func set_round(value: int) -> void:
 if value==round_number:return
 if round_number>=0 and value>round_number and not reduced_motion:
  round_time=0.0
  set_process(true)
 round_number=value
 queue_redraw()

func set_reduced_motion(value: bool) -> void:
 reduced_motion=value
 if value:
  motion_time=2.0;round_time=2.0
  sparks.clear();flashes.clear();compressions.clear()
  if is_instance_valid(effect_layer):effect_layer.queue_redraw()
  set_process(false)
 queue_redraw()

func _process(delta: float) -> void:
 motion_time+=delta
 round_time+=delta
 for compression in compressions:
  compression.age+=delta
  if compression.age>=COMPRESSION_TIME:burst_dot(int(compression.index))
 compressions=compressions.filter(func(item):return item.age<COMPRESSION_TIME)
 for spark in sparks:
  # Fast launch, then lateral drag and downward acceleration; no orbit or spin.
  var drag: float=1.0-exp(-5.0*delta)
  spark.velocity.x=lerpf(float(spark.velocity.x),0.0,drag)
  var displacement: Vector2=spark.velocity*delta+Vector2(0,0.5*BURST_GRAVITY*delta*delta)
  spark.position+=displacement
  spark.velocity+=Vector2(0,BURST_GRAVITY*delta)
  spark.distance+=displacement.length()
  spark.age+=delta
 sparks=sparks.filter(func(spark):return spark.distance<spark.travel and spark.age<spark.life)
 for flash in flashes:flash.age+=delta
 flashes=flashes.filter(func(flash):return flash.age<0.24)
 effect_layer.queue_redraw()
 queue_redraw()
 if motion_time>=MOTION_DURATION and round_time>=MOTION_DURATION and not is_burst_active():set_process(false)

func edge_point(progress: float) -> Vector2:
 var points: Array[Vector2]=[Vector2(360,2),Vector2(398,40),Vector2(360,78),Vector2(322,40),Vector2(360,2)]
 var distance:=clampf(progress,0.0,0.99999)*4.0
 var index:=int(distance)
 return points[index].lerp(points[index+1],fmod(distance,1.0))

func draw_round_light() -> void:
 if reduced_motion or round_time>=MOTION_DURATION:return
 var progress:=minf(round_time/0.86,1.0)
 var fade:=1.0-smoothstep(0.86,MOTION_DURATION,round_time)
 # A short luminous tail follows the four straight edges clockwise.
 for i in range(34):
  var a:=progress-float(i)*0.012
  if a<=0.0:continue
  var strength:=pow(1.0-float(i)/34.0,2.0)*fade
  var from:=edge_point(maxf(0.0,a-0.012))
  var to:=edge_point(a)
  draw_line(from,to,Color(1.0,0.59,0.16,0.18*strength),20,true)
  draw_line(from,to,Color(1.0,0.73,0.28,0.48*strength),11,true)
  draw_line(from,to,Color(1.0,0.97,0.83,strength),4.0,true)
 var head:=edge_point(progress)
 draw_circle(head,9.0,Color(1.0,0.71,0.22,0.20*fade),true,-1,true)
 draw_circle(head,4.0,Color(1.0,0.88,0.51,0.65*fade),true,-1,true)
 draw_circle(head,2.0,Color(1.0,0.99,0.91,fade),true,-1,true)
 # Analytic particles: no nodes, no gameplay random-number consumption.
 for i in range(16):
  var born:=float(i)*0.047
  var age:=round_time-born
  if age<0.0 or age>0.36:continue
  var origin:=edge_point(born/0.86)
  var direction:=(origin-Vector2(360,40)).normalized().rotated(sin(float(i)*2.3)*0.65)
  var point:=origin+direction*age*(20.0+float(i%4)*9.0)+Vector2(0,age*age*16.0)
  var alpha:=pow(1.0-age/0.36,2.0)
  draw_circle(point,3.0,Color(1.0,0.74,0.37,alpha*0.12),true,-1,true)
  diamond(point,1.0+float(i%2)*0.4,Color(1.0,0.89,0.62,alpha))

func set_turns(value: int, total: int) -> void:
 if remaining==value and maximum==total:return
 if not reduced_motion and round_number>=0 and maximum==total and value<remaining:
  for i in range(maxi(0,value),mini(remaining,maximum)):prepare_burst(i)
 previous_remaining=remaining
 motion_time=2.0 if reduced_motion or round_number<0 else 0.0
 if motion_time==0.0:set_process(true)
 remaining=value
 maximum=maxi(1,total)
 queue_redraw()

func plate(rect: Rect2) -> void:
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("21171b")
 style.border_color=Color("655035")
 style.set_border_width_all(1);style.set_corner_radius_all(7)
 draw_style_box(style,rect)
 # Deterministic woven threads confined to each plate.
 for y in range(int(rect.position.y)+5,int(rect.end.y)-5,3):
  var alpha:=0.025+0.015*sin(float(y)*1.7)
  draw_line(Vector2(rect.position.x+7,y),Vector2(rect.end.x-7,y),Color(0.9,0.7,0.48,alpha),1)
 draw_line(rect.position+Vector2(10,3),Vector2(rect.end.x-10,rect.position.y+3),Color(0.85,0.68,0.4,0.25),1,true)

func diamond(center: Vector2, radius: float, color: Color, outline: bool=false) -> void:
 var points:=PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0)])
 if outline:
  points.append(points[0]);draw_polyline(points,color,1,true)
 else:draw_colored_polygon(points,color)

func _draw() -> void:
 if is_instance_valid(glow_layer):glow_layer.queue_redraw()
 # Cut-corner treasury plaque, with two independent numeric columns.
 var plaque:=PackedVector2Array([Vector2(22,12),Vector2(202,12),Vector2(212,22),Vector2(212,100),Vector2(202,110),Vector2(22,110),Vector2(12,100),Vector2(12,22)])
 draw_colored_polygon(plaque,Color("1c161a"))
 plaque.append(plaque[0]);draw_polyline(plaque,Color("927447"),1,true)
 draw_line(Vector2(28,17),Vector2(196,17),Color(0.85,0.68,0.4,0.28),1,true)

 for y in range(23,102,4):
  draw_line(Vector2(20,y),Vector2(204,y),Color(0.7,0.54,0.4,0.025),1)
 for x in [112.0]:
  draw_line(Vector2(x-23,94),Vector2(x+23,94),Color("655035"),1,true)
  diamond(Vector2(x,94),2,GOLD)
 # Countdown dial and a separate wax-seal action, held by one gold baseline.
 plate(Rect2(510,12,97,79))
 draw_arc(Vector2(662,55),43,0,TAU,64,Color("80623d"),1,true)
 for angle in [-PI*0.5,0.0,PI*0.5,PI]:
  diamond(Vector2(662,55)+Vector2(cos(angle),sin(angle))*43,2,GOLD)
 draw_line(Vector2(519,111),Vector2(710,111),Color("655035"),1,true)
 for left in [true,false]:
  var x:=215.0 if left else 418.0
  draw_line(Vector2(x,47),Vector2(x+87,47),Color("80623d"),1,true)
  diamond(Vector2(x+43,47),3,GOLD)
  draw_line(Vector2(x+12,51),Vector2(x+75,51),Color(0.7,0.55,0.3,0.2),1,true)
 # Gilt bevel, garnet enamel, and harlequin facets.
 diamond(Vector2(360,42),41,Color("171012"))
 diamond(Vector2(360,40),38,GOLD)
 diamond(Vector2(360,40),32,Color("622534"))
 draw_colored_polygon(PackedVector2Array([Vector2(360,8),Vector2(392,40),Vector2(360,40)]),Color("793444"))
 draw_colored_polygon(PackedVector2Array([Vector2(360,72),Vector2(328,40),Vector2(360,40)]),Color("401c2a"))
 diamond(Vector2(360,40),29,Color(0.95,0.79,0.48,0.28),true)
 diamond(Vector2(360,4),3,IVORY)
 plate(Rect2(275,84,170,30))
 draw_round_light()
 for i in range(maximum):
  var p:=dot_position(i)
  var radius:=3.0 if maximum<=10 else 1.8
  var color:=Color("a3e6ff") if i<remaining else Color("303b48")
  if not reduced_motion and motion_time<MOTION_DURATION:
   var t:=maxf(0.0,motion_time-float(maximum-1-i)*0.025)
   var spring:=sin(t*19.0)*exp(-t*7.0)
   radius*=1.0+0.40*spring
  # Live dots are rendered entirely by the soft additive glow shader.
  if i>=remaining:draw_circle(p,radius,color,true,-1,true)
