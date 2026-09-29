"""LYNCO theatre props. Run with Blender --background --factory-startup --python.
Godot table geometry is intentionally NOT created, exported, or replaced.
"""
import bpy, math, random, json, os
from mathutils import Vector, Matrix
from pathlib import Path

ROOT = Path('D:/Lynco')
OUT = ROOT / 'assets/theatre_3d'
SOURCE = ROOT / 'tools/blender'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
random.seed(29)
# This isolated factory-startup process owns only its default scene.
for obj in list(bpy.data.objects): bpy.data.objects.remove(obj, do_unlink=True)

def material(name, color, metal=0, emission=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=.82
    p.inputs['Metallic'].default_value=metal
    if emission:
        p.inputs['Emission Color'].default_value=(*color,1)
        p.inputs['Emission Strength'].default_value=emission
    return m

wood=material('Ink stained walnut',(.065,.024,.015))
red=material('Vermilion worn velvet',(.29,.023,.013))
red_light=material('Velvet raised grain',(.36,.037,.019))
gold=material('Tarnished antique brass',(.36,.22,.075),.5)
ivory=material('Old ivory wax',(.7,.56,.34))
stone=material('Warm carved stone',(.28,.23,.16))
flame=material('Quiet warm flame', (1,.43,.08),0,3)
dark=material('Near black iron',(.018,.014,.011),.2)
leafmat=material('Dry crimson leaves',(.19,.02,.014))

def mesh(name, verts, faces, mat):
    d=bpy.data.meshes.new(name);d.from_pydata(verts,[],faces);d.update()
    o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o)
    if mat:d.materials.append(mat)
    return o

def box(name, center, size, mat):
    x,y,z=center;a,b,c=[v/2 for v in size]
    vs=[(x+i*a,y+j*b,z+k*c) for i,j,k in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    return mesh(name,vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat)

def lathe(name, profile, mat, center=(0,0,0), n=16):
    vs=[];fs=[]
    for z,r in profile:
        vs += [(center[0]+r*math.cos(i*2*math.pi/n),center[1]+r*math.sin(i*2*math.pi/n),center[2]+z) for i in range(n)]
    for j in range(len(profile)-1):
        for i in range(n):a=j*n+i;b=j*n+(i+1)%n;fs.append((a,b,b+n,a+n))
    fs += [tuple(reversed(range(n))),tuple((len(profile)-1)*n+i for i in range(n))]
    return mesh(name,vs,fs,mat)

def tube(name, points, radius, mat, n=8):
    vs=[];fs=[]
    for j,p in enumerate(points):
        t=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(j-1,0)])
        t.normalize();u=t.cross(Vector((0,0,1)))
        if u.length<.01:u=t.cross(Vector((0,1,0)))
        u.normalize();v=t.cross(u)
        for i in range(n):vs.append(Vector(p)+radius*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n)))
    for j in range(len(points)-1):
        for i in range(n):a=j*n+i;b=j*n+(i+1)%n;fs.append((a,b,b+n,a+n))
    return mesh(name,vs,fs,mat)

def extrude(name, outline, depth, mat, y=0):
    vs=[(x,y+d,z) for d in [-depth/2,depth/2] for x,z in outline];n=len(outline)
    fs=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,vs,fs,mat)

def diamond(name, x,y,z, sx,sz,mat):
    return extrude(name,[(x,z+sz),(x+sx,z),(x,z-sz),(x-sx,z)],.035,mat,y)

def velvet_material():
    m=material('Crimson velvet pile',(.42,.028,.044))
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Roughness'].default_value=.94
    p.inputs['Sheen Weight'].default_value=.25
    im=bpy.data.images.new('Woven crimson velvet',width=512,height=512)
    rng=random.Random(831);pixels=[]
    for y in range(512):
        for x in range(512):
            grain=rng.uniform(-.13,.13)+.035*math.sin(x*2.1)+.025*math.sin(y*2.8)
            cloud=.05*math.sin(x*.047)*math.sin(y*.039)
            pixels.extend([.46*(1+grain+cloud),.035*(1+grain),.055*(1+grain),1])
    im.pixels.foreach_set(pixels);im.pack()
    tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im
    m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
    normal=bpy.data.images.new('Velvet micro pile normal',width=512,height=512)
    normal.colorspace_settings.name='Non-Color'
    rng=random.Random(811);pixels=[]
    for k in range(512*512):
        pixels.extend([.5+rng.uniform(-.16,.16),.5+rng.uniform(-.16,.16),.98,1])
    normal.pixels.foreach_set(pixels);normal.pack()
    nt=m.node_tree.nodes.new('ShaderNodeTexImage');nt.image=normal
    nm=m.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.45
    m.node_tree.links.new(nt.outputs['Color'],nm.inputs['Color'])
    m.node_tree.links.new(nm.outputs['Normal'],p.inputs['Normal'])
    return m

def smooth(o):
    for p in o.data.polygons:p.use_smooth=True
    return o

def chair():
    velvet=velvet_material()
    # Dark narrow timber rails and turned, slightly splayed legs.
    for y in [-.99,.99]:box('Narrow walnut seat rail',(0,y,1.63),(2.55,.17,.24),wood)
    for x in [-1.18,1.18]:box('Side walnut rail',(x,0,1.63),(.17,2.1,.24),wood)
    profile=[(0,.065),(.13,.09),(.25,.075),(.95,.09),(1.16,.14),(1.29,.105),(1.47,.12),(1.59,.13)]
    for x in [-1.06,1.06]:
        for y in [-.87,.87]:
            o=lathe('Turned tapered walnut leg',profile,wood,(x,y,0),12)
            for v in o.data.vertices:
                v.co.x+=x*.16*(1-v.co.z/1.6)
                v.co.y+=y*.16*(1-v.co.z/1.6)
            smooth(o)
    box('Solid seat beneath loose cushion',(0,0,1.69),(2.36,2.0,.12),wood)
    before_cushion=set(bpy.data.objects)
    # Five deep button tufts and radial folds on a closed padded cushion.
    buttons=[(0,0),(-.57,-.49),(.57,-.49),(-.57,.49),(.57,.49)]
    def height(x,y):
        u=x/1.23;v=y/1.055
        puff=max(0,(1-u*u)*(1-v*v))**.42
        z=2.20+.40*puff
        for bx,by in buttons:
            dx=x-bx;dy=y-by;r=math.hypot(dx,dy);a=math.atan2(dy,dx)
            z-=.235*math.exp(-(r/.17)**2)
            z-=.025*(.5+.5*math.cos(a*7+r*18))*math.exp(-(r/.38)**2)*min(1,r/.10)
        edge=max(abs(u),abs(v))
        z+=.018*math.sin(x*36+y*7)*math.sin(y*25)*edge**8
        return z
    n=64;vs=[];fs=[]
    for j in range(n+1):
        for i in range(n+1):
            x=(i/n*2-1)*1.23;y=(j/n*2-1)*1.055
            vs.append((x,y,height(x,y)))
    for j in range(n):
        for i in range(n):
            a=j*(n+1)+i;fs.append((a,a+1,a+n+2,a+n+1))
    perimeter=list(range(n+1))+[j*(n+1)+n for j in range(1,n+1)]+[n*(n+1)+i for i in range(n-1,-1,-1)]+[j*(n+1) for j in range(n-1,0,-1)]
    # Rounded vertical gusset: visible thickness even from low side views.
    previous=perimeter
    for step in range(1,9):
        t=step/8;start=len(vs)
        bulge=1+.055*math.sin(t*math.pi)
        vs.extend([(vs[a][0]*bulge,vs[a][1]*bulge,2.20-.48*t) for a in perimeter])
        for k,a in enumerate(previous):
            q=(k+1)%len(perimeter);fs.append((a,start+k,start+q,previous[q]))
        previous=list(range(start,start+len(perimeter)))
    fs.append(tuple(reversed(previous)))
    o=smooth(mesh('Padded velvet cushion with five deep tufts',vs,fs,velvet))
    uv=o.data.uv_layers.new(name='Velvet weave UV')
    for p in o.data.polygons:
        for li in p.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co
            uv.data[li].uv=(co.x/2.46+.5,co.y/2.11+.5)
    for x,y in buttons:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=(x,y,height(x,y)+.05))
        o=bpy.context.object;o.name='Cloth covered tuft button';o.scale=(.09,.09,.035);o.data.materials.append(velvet);smooth(o)
    ring=[(vs[a][0]*1.06,vs[a][1]*1.06,2.02) for a in perimeter];ring.append(ring[0])
    smooth(tube('Antique gold cushion piping',ring,.024,gold,6))
    # Fine hanging cord loops and silk tassels, all four edges.
    for axis in [0,1]:
        for sign in [-1,1]:
            for k in range(7):
                t=-.91+k*.303
                x,y=(t,sign*1.065) if axis==0 else (sign*1.24,t*.94)
                smooth(lathe('Tassel brass bead',[(0,.018),(.025,.044),(.07,.037),(.10,.016)],gold,(x,y,1.52),8))
                for q in range(8):
                    a=q*math.tau/8
                    tube('Velvet tassel silk strand',[(x+.019*math.cos(a),y+.019*math.sin(a),1.55),(x+.035*math.cos(a),y+.035*math.sin(a),1.40),(x+.065*math.cos(a),y+.065*math.sin(a),1.29+.018*math.sin(q))],.009,velvet if q%3 else gold,4)
                # Gold scalloped braid above the hanging bead.
                pts=[]
                for q in range(13):
                    d=(q/12-.5)*.29
                    pts.append((x+d if axis==0 else x,y if axis==0 else y+d,1.78-.10*math.sin(q/12*math.pi)))
                tube('Scalloped gold braid',pts,.011,gold,4)
    # Fit the entire loose cushion and its trim INSIDE the timber seat.
    bpy.context.view_layer.update()
    cushion_objects=set(bpy.data.objects)-before_cushion
    cushion_max_z=-100
    for o in cushion_objects:
        # Bake existing button scale/location before fitting the complete assembly.
        for v in o.data.vertices:
            co=o.matrix_world @ v.co
            v.co=(co.x*.87,co.y*.78-.15,1.76+(co.z-1.72)*.74)
            cushion_max_z=max(cushion_max_z,v.co.z)
        o.matrix_world=Matrix.Identity(4)
    assert cushion_max_z<2.48, f'Cushion must stay below back upholstery: {cushion_max_z}'
    # Tall slim frame: arched crest, three red vertical upholstered channels.
    for side in [-1,1]:
        smooth(tube('Tall curved back post',[(side*1.06,.9,1.65),(side*1.10,1.03,2.9),(side*1.14,1.19,4.82)],.09,wood,10))
        smooth(lathe('Antique gold flame finial',[(0,.065),(.06,.105),(.16,.13),(.28,.065),(.40,0)],gold,(side*1.14,1.19,4.81),12))
    outline=[(-1.01,2.02),(-1.01,4.38),(-.85,4.58),(-.53,4.70),(0,4.88),(.53,4.70),(.85,4.58),(1.01,4.38),(1.01,2.02)]
    extrude('Arched walnut back frame',outline,.20,wood,1.12)
    for panel in [-1,0,1]:
        vs=[];fs=[];nx=12;nz=30
        for j in range(nz+1):
            t=j/nz
            for i in range(nx+1):
                u=i/nx;x=panel*.59+(u-.5)*.575
                cap=4.68-.30*(abs(x)/.9)**1.5
                z=2.52+(cap-2.52)*t
                y=.80-.34*math.sin(u*math.pi)**.55*math.sin(t*math.pi)**.35
                vs.append((x,y,z))
        for j in range(nz):
            for i in range(nx):
                a=j*(nx+1)+i;fs.append((a,a+1,a+nx+2,a+nx+1))
        # Close each upholstered pad with sidewalls and a solid back.
        front_count=len(vs)
        vs.extend([(x,1.06,z) for x,y,z in list(vs)])
        front_faces=list(fs)
        fs.extend([tuple(front_count+k for k in reversed(face)) for face in front_faces])
        border=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,nz+1)]+[nz*(nx+1)+i for i in range(nx-1,-1,-1)]+[j*(nx+1) for j in range(nz-1,0,-1)]
        for k,a in enumerate(border):
            b=border[(k+1)%len(border)];fs.append((a,a+front_count,b+front_count,b))
        o=smooth(mesh('Vertical padded back channel',vs,fs,velvet))
        uv=o.data.uv_layers.new(name='Back velvet UV')
        for p in o.data.polygons:
            for li in p.loop_indices:
                co=o.data.vertices[o.data.loops[li].vertex_index].co;uv.data[li].uv=(co.x*.7,co.z*.5)
    tube('Swept walnut crest',[(x,.965,z) for x,z in outline[1:-1]],.075,wood,10)


def candelabra():
    lathe('Candelabra base',[(0,.7),(.14,.72),(.25,.44),(.38,.3),(.6,.15),(2.8,.1),(2.92,.24),(3.06,.16)],gold)
    for side in [-1,1]:
        tube('Swept candle arm',[(0,0,2.65),(side*.35,0,2.62),(side*.72,0,2.85),(side*.95,0,3.2),(side*.95,0,3.6)],.075,gold)
    for x,z in [(-.95,3.6),(0,4.1),(.95,3.6)]:
        if x==0:tube('Center stem',[(0,0,3),(0,0,4.1)],.07,gold)
        lathe('Wax saucer',[(0,.12),(.04,.28),(.12,.29),(.18,.14)],gold,(x,0,z))
        lathe('Ivory candle',[(0,.12),(.64,.125),(.71,.09)],ivory,(x,0,z+.16))
        for k in range(3):
            a=k*2.1
            tube('Wax drip',[(x+.122*math.cos(a),.122*math.sin(a),z+.8),(x+.126*math.cos(a),.126*math.sin(a),z+.48+k*.05)],.025,ivory)
        lathe('Flame',[(0,.025),(.1,.095),(.24,.055),(.44,0)],flame,(x,0,z+.87),8)

def curtain():
    vs=[];fs=[];nx=48;nz=18
    for j in range(nz+1):
        z=j/nz*12
        for i in range(nx+1):
            u=i/nx
            x=(u-.5)*5.8+(1-z/12)**2*.5*math.sin(u*math.pi)
            y=.28*math.cos(u*math.tau*7)+.15*math.sin(z*.4)
            vs.append((x,y,z+.10*math.cos(u*math.tau*7)))
    for j in range(nz):
        for i in range(nx):a=j*(nx+1)+i;fs.append((a,a+1,a+nx+2,a+nx+1))
    o=mesh('Vermilion curtain folds',vs,fs,red);o.data.materials.append(red_light)
    for p in o.data.polygons:p.material_index=1 if random.random()<.12 else 0
    tube('Curtain gold hem',[(v[0],v[1]-.03,v[2]+.12) for v in vs[:nx+1]],.04,gold)
    tube('Tie back cord',[(-2.9,-.35,4.8),(-1.6,-.53,4.3),(0,-.55,4.1),(1.6,-.53,4.3),(2.9,-.35,4.8)],.07,gold)
    lathe('Cord tassel',[(0,.19),(.5,.1),(.58,.16),(.73,.04)],gold,(1.7,-.56,3.55))

def pendant():
    tube('Pendant cord',[(0,0,0),(0,0,3.5)],.017,gold)
    diamond('Four point star',0,0,0,.55,.9,gold)
    diamond('Star inner',0,-.035,0,.16,.3,ivory)

def vase():
    box('Pedestal foot',(0,0,.12),(1.65,1.65,.24),stone)
    box('Pedestal shaft',(0,0,1.18),(1.1,1.1,1.94),stone)
    box('Pedestal crown',(0,0,2.26),(1.6,1.6,.22),stone)
    for x in [-.36,0,.36]:tube('Pedestal flute',[(x,-.564,.5),(x,-.564,1.95)],.035,gold)
    lathe('Ivory urn',[(0,.32),(.16,.28),(.4,.6),(.75,.54),(1.05,.25),(1.25,.35),(1.34,.39)],ivory,(0,0,2.37),20)
    for j in range(7):
        a=j*2.4;r=.45+(j%3)*.15;h=4.6+(j%3)*.4
        tip=(math.cos(a)*r,math.sin(a)*r,h)
        tube('Dry stem',[(0,0,3.4),(tip[0]*.6,tip[1]*.6,4),tip],.024,wood)
        for t in [.55,.78,1.0]:
            x=tip[0]*t;y=tip[1]*t;z=3.4+(h-3.4)*t
            diamond('Crimson leaf',x,y,z,.19,.28,leafmat)

manifest={}
for name,build in [('chair',chair),('candelabra',candelabra),('curtain',curtain),('star_pendant',pendant),('pedestal_vase',vase)]:
    before=set(bpy.data.objects)
    build();objects=list(set(bpy.data.objects)-before)
    for o in bpy.context.selected_objects:o.select_set(False)
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if name=='chair':
        # One mesh, three material surfaces: avoid hundreds of draw calls per chair.
        bpy.ops.object.join()
        objects=[bpy.context.view_layer.objects.active]
        objects[0].name='LYNCO upholstered theatre chair'
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),use_selection=True)
    # Keep source models separated on an asset review stage.
    offset=len(manifest)*7
    for o in objects:o.location.x+=offset
    manifest[name]={'objects':len(objects),'triangles':sum(max(0,len(p.vertices)-2) for o in objects for p in o.data.polygons)}

# Portable material textures made inside Blender, used on the ORIGINAL Godot tables.
for name,base in [('felt',(.17,.038,.029)),('walnut',(.12,.049,.023))]:
    size=512;im=bpy.data.images.new(name,width=size,height=size)
    px=[]
    for y in range(size):
        for x in range(size):
            n=random.random()*.11-.055
            grain=(math.sin(x*.11+math.sin(y*.025)*1.5)*.055 if name=='walnut' else ((x%2)*.012+(y%2)*.01))
            px.extend([max(0,min(1,c*(1+n+grain))) for c in base]+[1])
    im.pixels.foreach_set(px);im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save()

scene=bpy.context.scene
try:scene.render.engine='CYCLES'
except TypeError:pass
if hasattr(scene,'cycles'):scene.cycles.samples=16
scene.render.resolution_x=1500;scene.render.resolution_y=700;scene.render.resolution_percentage=100
scene.world.color=(.05,.05,.05)
box('Review floor',(14,0,-.18),(42,20,.3),dark)
cam_data=bpy.data.cameras.new('Review Camera');cam=bpy.data.objects.new('Review Camera',cam_data);scene.collection.objects.link(cam)
cam.location=(16,-35,19);target=Vector((14,0,4.4));cam.rotation_euler=(target-Vector(cam.location)).to_track_quat('-Z','Y').to_euler();scene.camera=cam
cam_data.type='ORTHO';cam_data.ortho_scale=39
for name,loc,power,size in [('Key',(7,-9,16),3800,12),('Fill',(25,-5,11),2500,10)]:
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((14,0,3))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'lynco_theatre_props.blend'))
(OUT/'manifest.json').write_text(json.dumps({'blender':bpy.app.version_string,'assets':manifest,'table_geometry':'Not modified or exported'},indent=2),encoding='utf-8')
scene.render.filepath=str(ROOT/'test-results/blender_theatre_props.png')
bpy.ops.render.render(write_still=True)
print('LYNCO_BLENDER_BUILD_PASS',manifest)

# Close-up preview for upholstery and reference chair silhouette.
scene.render.resolution_x=1000;scene.render.resolution_y=1100
cam.location=(7,-10,7);target=Vector((0,0,2.5))
cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
cam_data.ortho_scale=6.7
scene.render.filepath=str(ROOT/'test-results/blender_chair_detail.png')
bpy.ops.render.render(write_still=True)