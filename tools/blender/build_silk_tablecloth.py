"""Blender 5.x: static, shared low-poly cloth; no simulation or subdivision."""
import bpy, math, json
import numpy as np
from pathlib import Path

ROOT = Path(r'D:\Lynco')
OUT = ROOT / 'assets/theatre_3d'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# Periodic woven satin textures. Normal is tangent-space OpenGL (+Y).
N=1024
y,x=np.mgrid[0:N,0:N].astype(np.float32)/N
tau=math.tau
weave=np.sin(tau*(x*96+.12*np.sin(tau*y*7)))*np.sin(tau*y*96)
fold=np.sin(tau*(3*x+2*y))*.5 + np.sin(tau*(7*x-y))*.16
height=.000045*weave+.0014*fold
dx=(np.roll(height,-1,1)-np.roll(height,1,1))*N*.5
dy=(np.roll(height,-1,0)-np.roll(height,1,0))*N*.5
normal=np.stack((-dx,-dy,np.ones_like(x)),axis=-1)
normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
def texture(name,rgb,linear=False):
    if rgb.ndim==2: rgb=np.repeat(rgb[:,:,None],3,axis=2)
    rgba=np.concatenate((rgb,np.ones((N,N,1),dtype=np.float32)),axis=2)
    im=bpy.data.images.new(name,width=N,height=N,alpha=False)
    if linear: im.colorspace_settings.name='Non-Color'
    im.pixels.foreach_set(rgba.astype(np.float32).ravel())
    im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save()
    return im
normal_im=texture('silk_normal',normal*.5+.5,True)
rough_im=texture('silk_roughness',np.clip(.52+.025*weave+.02*fold,0,1),True)
base=np.array([.29,.047,.063],dtype=np.float32)
color_im=texture('silk_crimson',np.clip(base[None,None,:]*(1+.005*weave[:,:,None]+.015*fold[:,:,None]),0,1))

silk=bpy.data.materials.new('Crimson silk');silk.use_nodes=True
bs= silk.node_tree.nodes.get('Principled BSDF')
bs.inputs['Base Color'].default_value=(.12,.01,.02,1)
bs.inputs['Roughness'].default_value=.43
bs.inputs['Sheen Weight'].default_value=.22
gold=bpy.data.materials.new('Antique gold hem');gold.diffuse_color=(.34,.20,.055,1)
gold.use_nodes=True
g=gold.node_tree.nodes.get('Principled BSDF');g.inputs['Base Color'].default_value=gold.diffuse_color
g.inputs['Metallic'].default_value=.35;g.inputs['Roughness'].default_value=.48

hx,hy=11.27,16.62
points=[]
for a,b,n in [((-hx,-hy),(hx,-hy),48),((hx,-hy),(hx,hy),64),((hx,hy),(-hx,hy),48),((-hx,hy),(-hx,-hy),64)]:
    for j in range(n):
        t=j/n;points.append((a[0]*(1-t)+b[0]*t,a[1]*(1-t)+b[1]*t))
count=len(points)
lengths=[0.0]
for i in range(1,count):lengths.append(lengths[-1]+math.dist(points[i-1],points[i]))
perimeter=lengths[-1]+math.dist(points[-1],points[0])
vertices=[(0,0,.003)]+[(px,py,.003) for px,py in points]
faces=[];uvs=[];mats=[]
# Topology concentrates rings on the shoulder and lower seam.
depths=[0,.025,.08,.20,.40,.65,.84,.975,1.0]
for r,t in enumerate(depths[1:],1):
    for i,(px,py) in enumerate(points):
        theta=tau*lengths[i]/perimeter
        drape=1.85+.24*math.cos(theta*4)+.12*math.sin(theta*7)
        corner=min(abs(px)/hx,abs(py)/hy)**12
        drape+=.20*corner
        fold=(math.sin(theta*22)+.36*math.sin(theta*35+.8))
        outward=.035+(.20+.13*fold)*(1-math.exp(-t*9))
        # Push away from table edges: even fold troughs remain outside wood.
        nx=math.copysign(max(0,(abs(px)/hx-.85)/.15),px)
        ny=math.copysign(max(0,(abs(py)/hy-.85)/.15),py)
        norm=math.hypot(nx,ny);nx/=norm;ny/=norm
        vertices.append((px+nx*outward,py+ny*outward,.003-t*drape))
# Keep the interior flat; shoulder normals affect only a narrow edge strip.
inner_start=len(vertices)
vertices.extend([(px*.965,py*.965,.003) for px,py in points])
def top_uv(index):
    v=vertices[index];return (v[0]/(2*hx)+.5,v[1]/(2*hy)+.5)
for i in range(count):
    j=(i+1)%count
    for face in [(0,inner_start+i,inner_start+j),(inner_start+i,1+i,1+j,inner_start+j)]:
        faces.append(face);mats.append(0);uvs.append([top_uv(k) for k in face])
for r in range(len(depths)-1):
    for i in range(count):
        j=(i+1)%count
        faces.append((1+r*count+i,1+(r+1)*count+i,1+(r+1)*count+j,1+r*count+j))
        mats.append(1 if r==len(depths)-2 else 0)
        u0=lengths[i]/(2*hx);u1=(lengths[j] if j else perimeter)/(2*hx)
        v0=depths[r]*2/(2*hy);v1=depths[r+1]*2/(2*hy)
        uvs.append([(u0,v0),(u0,v1),(u1,v1),(u1,v0)])
mesh=bpy.data.meshes.new('StaticSilkMesh');mesh.from_pydata(vertices,[],faces);mesh.update()
mesh.materials.append(silk);mesh.materials.append(gold)
uv=mesh.uv_layers.new(name='UVMap')
for poly,coords,mat in zip(mesh.polygons,uvs,mats):
    poly.use_smooth=True;poly.material_index=mat
    for loop,coord in zip(poly.loop_indices,coords):uv.data[loop].uv=coord
obj=bpy.data.objects.new('SilkTablecloth',mesh);bpy.context.collection.objects.link(obj)
bpy.context.view_layer.objects.active=obj;obj.select_set(True)
mesh.calc_loop_triangles()
stats={'vertices':len(mesh.vertices),'triangles':len(mesh.loop_triangles),'material_surfaces':2,'textures':'3 x 1024 PNG, one continuous tablecloth','simulation':False,'top_height':.003,'lowest_height':min(v[2] for v in vertices)}
(OUT/'tablecloth_manifest.json').write_text(json.dumps(stats,indent=2),encoding='utf8')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tools/blender/lynco_silk_tablecloth.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'silk_tablecloth.glb'),export_format='GLB',use_selection=True,export_tangents=True,export_yup=True)
print('SILK_BUILD',json.dumps(stats))
