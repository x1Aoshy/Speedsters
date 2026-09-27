import bpy, math, random, json, struct, shutil, ast, bmesh
from pathlib import Path
from mathutils import Vector, Matrix
random.seed(94)
BASE=Path(__file__).resolve().parent;OUT=BASE/'Regenerated'
for p in [OUT,OUT/'textures',OUT/'Roblox_LocalAssets',OUT/'Referencias']:p.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;mats={}
for name in('Dirt','Grass','Cliff','Bark'):
 src=BASE/'textures'/f'{name}.png';shutil.copy2(src,OUT/'textures'/src.name);shutil.copy2(src,OUT/'Roblox_LocalAssets'/src.name)
 im=bpy.data.images.load(str(OUT/'textures'/src.name));im.pack();m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.82;t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=im;m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color']);mats[name]=m
for name,c in [('Leaf',(.07,.32,.014)),('LeafLight',(.22,.46,.028)),('Gold',(.95,.52,.015)),('Heart',(.12,.045,.012)),('Stem',(.075,.25,.015)),('Rock',(.28,.23,.14)),('Red',(.68,.022,.012)),('Steel',(.13,.17,.19)),('PetalWhite',(.95,.87,.68))]:
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*c,1);m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*c,1);mats[name]=m
class Mesh:
 def __init__(self,name,material):self.name=name;self.material=material;self.v=[];self.f=[];self.uv=[]
 def face(self,pts,uv=None):
  k=len(self.v);self.v.extend([tuple(p) for p in pts]);self.f.append(tuple(range(k,k+len(pts))));self.uv.append(uv or [(0,0),(1,0),(1,1),(0,1)][:len(pts)])
 def end(self):
  if not self.f:return
  me=bpy.data.meshes.new(self.name);me.from_pydata(self.v,[],self.f);me.update();o=bpy.data.objects.new(self.name,me);scene.collection.objects.link(o);me.materials.append(mats[self.material]);uv=me.uv_layers.new()
  for p,coords in zip(me.polygons,self.uv):
   for li,co in zip(p.loop_indices,coords):uv.data[li].uv=co
  return o
def tube(mesh,a,b,r1,r2,n=10):
 a=Vector(a);b=Vector(b);z=(b-a).normalized();x=z.cross(Vector((0,1,.03))).normalized();y=z.cross(x)
 for j in range(n):
  t=j*math.tau/n;u=(j+1)*math.tau/n;q=x*math.cos(t)+y*math.sin(t);w=x*math.cos(u)+y*math.sin(u)
  mesh.face([a+q*r1,a+w*r1,b+w*r2,b+q*r2],[(j/n,0),((j+1)/n,0),((j+1)/n,(b-a).length/8),(j/n,(b-a).length/8)])
 mesh.face([b+x*r2,b+y*r2,b-x*r2,b-y*r2])
def ellipsoid(mesh,c,r,seg=12,rings=6):
 c=Vector(c)
 for k in range(rings):
  a=-math.pi/2+k*math.pi/rings;b=-math.pi/2+(k+1)*math.pi/rings
  for j in range(seg):
   t=j*math.tau/seg;u=(j+1)*math.tau/seg
   def p(v,h):return c+Vector((r[0]*math.cos(v)*math.cos(h),r[1]*math.cos(v)*math.sin(h),r[2]*math.sin(v)))
   mesh.face([p(a,t),p(a,u),p(b,u),p(b,t)])
def smooth(o):
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=.001);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
 for p in o.data.polygons:p.use_smooth=True
 return o
def closed_leaf(mesh,center,direction,side,length,width,drop):
 # Arched, closed, folded frond with real thickness; no overlapping reversed faces.
 points=[]
 for k in range(11):
  u=k/10;c=center+direction*(length*u)+Vector((0,0,5*math.sin(u*math.pi)-drop*u*u));w=max(.025,width*math.sin(math.pi*(.03+.96*u)))
  serration=(.82 if k%2 else 1);w*=serration
  points.append((c-side*w,c+Vector((0,0,.38)),c+side*w))
 for k in range(10):
  a,b=points[k],points[k+1]
  for j in range(2):
   mesh.face([a[j],b[j],b[j+1],a[j+1]])
   mesh.face([a[j+1]-Vector((0,0,.14)),b[j+1]-Vector((0,0,.14)),b[j]-Vector((0,0,.14)),a[j]-Vector((0,0,.14))])
  mesh.face([a[0]-Vector((0,0,.14)),b[0]-Vector((0,0,.14)),b[0],a[0]])
  mesh.face([a[2],b[2],b[2]-Vector((0,0,.14)),a[2]-Vector((0,0,.14))])
 for row in (points[0],points[-1]):mesh.face([row[0],row[2],row[2]-Vector((0,0,.14)),row[0]-Vector((0,0,.14))])
def palm(pos,height,ang):
 global palm_index
 idx=palm_index;palm_index+=1;p=Vector(pos);bend=Vector((math.cos(ang)*height*.15,math.sin(ang)*height*.15,0));top=p+Vector((0,0,height))+bend
 tr=Mesh(f'Palm_{idx:02}_Trunk','Bark')
 for k in range(10):
  a=p+Vector((0,0,height*k/10))+bend*(k/10)**2;b=p+Vector((0,0,height*(k+1)/10))+bend*((k+1)/10)**2
  tube(tr,a,b,1.9-k*.09,1.9-(k+1)*.09,14)
 trunk=smooth(tr.end());parts=[(trunk,'trunk',p)]
 for j in range(9):
  a=ang+j*math.tau/9;d=Vector((math.cos(a),math.sin(a),0));s=Vector((-d.y,d.x,0));length=height*random.uniform(.48,.63)
  lf=Mesh(f'Palm_{idx:02}_Frond_{j:02}','Leaf' if j%3 else 'LeafLight');closed_leaf(lf,top,d,s,length,random.uniform(3,4.7),random.uniform(7,11));o=smooth(lf.end());parts.append((o,'frond',top))
 # Crown fruit hides the junction naturally.
 fruit=Mesh(f'Palm_{idx:02}_Crown','Bark')
 for j in range(4):ellipsoid(fruit,top+Vector((math.cos(j*1.57)*1.5,math.sin(j*1.57)*1.5,-.5)),(1.5,1.5,1.8),14,8)
 fruit=smooth(fruit.end());parts.append((fruit,'crown',top))
 for ob,kind,pivot in parts:
  ob['wind_tree']=idx;ob['wind_kind']=kind;ob['wind_base']=list(p);ob['wind_crown']=list(top);ob['wind_phase']=idx*.83
  ob.shape_key_add(name='Basis')
  for axis,name in [(0,'Wind_X'),(1,'Wind_Y')]:
   key=ob.shape_key_add(name=name);key.slider_min=-1;key.slider_max=1
   for v,k in zip(ob.data.vertices,key.data):
    t=max(0,min(1.25,(v.co.z-p.z)/height));strength=(1.3 if kind=='trunk' else 2.5)*t*t
    if kind=='frond':strength+=.7*(v.co-top).length/height
    k.co[axis]+=strength
   driver=key.driver_add('value').driver;driver.expression=f'sin(frame*{.035 if axis==0 else .043}+{idx*.83+axis*1.8})'
  wind.append({'name':ob.name,'tree':idx,'kind':kind,'base':list(p),'crown':list(top),'phase':idx*.83})
def height(s):
 h=0
 for a,b,amp in [(120,450,4.5),(580,930,6),(1020,1400,4),(1510,1820,5)]:
  if a<s<b:h+=amp*math.sin(math.pi*(s-a)/(b-a))**2
 return h
def g(s):return (height(s+.01)-height(s-.01))/.02
def width(s):return 69+7*math.sin(s*.017)+4*math.sin(s*.031)
samples=[-64]+list(range(-60,2121,20))
# Straight 72-stud surface, no horizontal deviation; same heights exported for collision tests.
for chunk in range(10):
 lo=-64+chunk*220;hi=min(2120,lo+220);road=Mesh(f'Road_{chunk:02}','Dirt');grass=Mesh(f'Verge_{chunk:02}','Grass');cliff=Mesh(f'Embankment_{chunk:02}','Cliff')
 s=lo
 while s<hi:
  n=min(hi,s+8)
  for a,b in [(-36,-18),(-18,0),(0,18),(18,36)]:
   road.face([(a,s,height(s)),(b,s,height(s)),(b,n,height(n)),(a,n,height(n))],[(a/22,s/22),(b/22,s/22),(b/22,n/22),(a/22,n/22)])
  for sign in(-1,1):
   bands=[36,42,width(s)];bn=[36,42,width(n)]
   for k in range(2):
    pts=[(sign*bands[k],s,height(s)+(.1 if k else 0)),(sign*bands[k+1],s,height(s)+.3),(sign*bn[k+1],n,height(n)+.3),(sign*bn[k],n,height(n)+(.1 if k else 0))]
    if sign<0:pts.reverse()
    grass.face(pts,[(p[0]/18,p[1]/18) for p in pts])
   pts=[(sign*width(s),s,height(s)+.3),(sign*width(n),n,height(n)+.3),(sign*(width(n)+3),n,-14),(sign*(width(s)+3),s,-14)]
   uv=[(s/56,(height(s)+.3)/56),(n/56,(height(n)+.3)/56),(n/56,-14/56),(s/56,-14/56)]
   if sign>0:pts.reverse();uv.reverse()
   cliff.face(pts,uv)
  s=n
 road.end();grass.end();cliff.end()
# Dry rolling grass valley below the track.
valley=Mesh('Dry_Valley','Grass')
for x in range(-700,700,70):
 for s in range(-200,2400,65):
  def v(a,b):return(a,b,-17+2*math.sin(a*.02)*math.cos(b*.012))
  pts=[v(x,s),v(x+70,s),v(x+70,s+65),v(x,s+65)];valley.face(pts,[(p[0]/22,p[1]/22) for p in pts])
smooth(valley.end())
# Landscaped side mesas, outside the race corridor.
def mesa(name,x,y,rx,ry,h):
 rock=Mesh(name+'_Rock','Cliff');cap=Mesh(name+'_Grass','Grass');ring=[];per=0
 for j in range(32):
  a=j*math.tau/32;r=1+.07*math.sin(5*a)+.035*math.cos(3*a);ring.append(Vector((x+rx*r*math.cos(a),y+ry*r*math.sin(a),h)))
 for j in range(32):
  p,q=ring[j],ring[(j+1)%32];ds=(q-p).length;cap.face([(x,y,h+.5),p,q],[(x/18,y/18),(p.x/18,p.y/18),(q.x/18,q.y/18)])
  for k in range(3):
   z1=-17+(h+17)*k/3;z2=-17+(h+17)*(k+1)/3;f1=1+.04*math.sin(k*2);f2=1+.04*math.sin((k+1)*2)
   pts=[(x+(p.x-x)*f1,y+(p.y-y)*f1,z1),(x+(q.x-x)*f1,y+(q.y-y)*f1,z1),(x+(q.x-x)*f2,y+(q.y-y)*f2,z2),(x+(p.x-x)*f2,y+(p.y-y)*f2,z2)]
   rock.face(pts,[(per/56,z1/56),((per+ds)/56,z1/56),((per+ds)/56,z2/56),(per/56,z2/56)])
  cap.face([p,q,q-Vector((0,0,2)),p-Vector((0,0,2))]);per+=ds
 rock.end();cap.end()
for i,(x,s,rx,ry,h) in enumerate([(-125,50,48,63,25),(145,155,50,70,32),(-190,270,55,85,56),(210,450,75,60,65),(-155,650,57,80,34),(150,850,45,85,44),(-195,1100,85,65,56),(160,1250,54,80,34),(-125,1510,47,65,24),(210,1680,74,84,58),(-160,1880,59,70,36),(140,2060,46,66,32)]):mesa(f'Mesa_{i:02}',x,s,rx,ry,h)
# Curated palms: 24, no rows, with individually animatable fronds in Blender.
wind=[];palm_index=0
for side,s,count in [(-1,18,2),(1,175,1),(-1,375,2),(1,590,2),(-1,810,1),(1,1040,2),(-1,1270,2),(1,1505,1),(-1,1740,2),(1,1940,1)]:
 for j in range(count):
  ss=s+j*17;x=side*(54+j*7);palm((x,ss,height(ss)+1),random.uniform(29,38),random.random()*math.tau)
for x,s,h in [(-125,50,25),(145,155,32),(-155,650,34),(150,850,44),(-125,1510,24),(140,2060,32)]:palm((x,s,h+1),34,random.random()*math.tau)
# Dense low plants in clusters, rounded geometry; grouped by region for mobile.
for zone in range(10):
 bushes=Mesh(f'Bushes_{zone:02}','Leaf');leaves=Mesh(f'Ferns_{zone:02}','LeafLight');flowers=Mesh(f'Flowers_{zone:02}','Gold');center=Mesh(f'FlowerCenters_{zone:02}','Heart');stem=Mesh(f'FlowerStems_{zone:02}','Stem');rocks=Mesh(f'Rocks_{zone:02}','Rock')
 for s in range(zone*210,(zone+1)*210,18):
  for sign in(-1,1):
   x=sign*random.uniform(46,width(s)-3);p=Vector((x,s,height(s)+.3))
   for j in range(2):ellipsoid(bushes,p+Vector((random.uniform(-2,2),random.uniform(-3,3),1.3)),(random.uniform(2,3.8),random.uniform(2,3.5),random.uniform(1.6,2.8)),12,7)
   if s%36==0:
    for j in range(5):
     a=j*math.tau/5;d=Vector((math.cos(a),math.sin(a),0));side=Vector((-d.y,d.x,0));closed_leaf(leaves,p+Vector((0,0,1)),d,side,random.uniform(4,6),1.4,2)
   if s%54==0:
    p=Vector((sign*45,s,height(s)+.5));top=p+Vector((0,0,4.7));tube(stem,p,top,.18,.14,7);ellipsoid(center,top,(.85,.35,.85),14,8)
    for j in range(9):
     a=j*math.tau/9;d=Vector((math.sin(a),0,math.cos(a)));c=top+d*1.35;before=len(flowers.v);ellipsoid(flowers,c,(.43,.20,.85),10,6);rot=Matrix.Rotation(a,3,'Y')
     for k in range(before,len(flowers.v)):flowers.v[k]=tuple(c+rot@(Vector(flowers.v[k])-c))
   if s%72==0:ellipsoid(rocks,(sign*(width(s)-2),s,height(s)+1),(3.7,2.5,2.7),14,8)
 for mesh in(bushes,leaves,flowers,center,stem,rocks):
  ob=mesh.end()
  if ob:smooth(ob)
def box(mesh,x,y,z,w,d,h):
 a=[Vector((x-w/2,y-d/2,z)),Vector((x+w/2,y-d/2,z)),Vector((x+w/2,y+d/2,z)),Vector((x-w/2,y+d/2,z))];b=[p+Vector((0,0,h)) for p in a];mesh.face(b)
 for k in range(4):mesh.face([a[k],a[(k+1)%4],b[(k+1)%4],b[k]])
# Pads match exact contract names in the native place, visible raised chevrons toward forward (-Z in Roblox).
boosts=[]
for num,s in enumerate([60,480,990,1450,1850]):
 red=Mesh(f'Pad_{num}_Red','Red');gold=Mesh(f'Pad_{num}_Gold','Gold');steel=Mesh(f'Pad_{num}_Steel','Steel');h=height(s);box(red,0,s,h+.04,16,20,.12)
 for x in(-8.3,8.3):box(steel,x,s,h+.02,1,21,.20)
 for off in(-5,0,5):
  for sign in(-1,1):
   pts=[(sign*5.5,s+off-1,h+.19),(0,s+off+1.7,h+.19),(0,s+off+3,h+.19),(sign*5.5,s+off+.3,h+.19)]
   if sign>0:pts.reverse()
   gold.face(pts)
 for mesh in(red,gold,steel):mesh.end()
 boosts.append({'s':s,'height':h,'boost':1.25,'seconds':1.5})
# Render setup: colorful clear sky and softened sunlight.
scene.world.use_nodes=True;bg=scene.world.node_tree.nodes.get('Background');bg.inputs[0].default_value=(.055,.32,.95,1);bg.inputs[1].default_value=.75
bpy.ops.object.light_add(type='SUN');sun=bpy.context.object;sun.rotation_euler=(.45,-.55,-.4);sun.data.energy=3;sun.data.angle=.17
def camera(name,pos,target,lens):
 bpy.ops.object.camera_add(location=pos);o=bpy.context.object;o.name=name;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();o.data.lens=lens;o.data.clip_end=9000;return o
hero=camera('Cam_Entrada',(12,-70,21),(0,240,10),24);aerial=camera('Cam_Recorrido',(260,-150,290),(0,630,5),27);detail=camera('Cam_Palmeras',(-14,-18,16),(-39,62,17),28)
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True;scene.render.resolution_x=1600;scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=.5
scene.frame_start=1;scene.frame_end=240;scene.render.fps=30;scene.frame_set(1);scene.camera=hero
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'RaceArena_Recta.blend'))
for cam,file in[(hero,'Render_Entrada.png'),(aerial,'Render_Recorrido.png'),(detail,'Render_Palmeras.png')]:scene.camera=cam;scene.render.filepath=str(OUT/file);bpy.ops.render.render(write_still=True)
# Export each tree as just a trunk and canopy for Roblox (animated once per tree by one LocalScript).
def rv(p):return(p[0],p[2],-p[1])
groups={}
for ob in scene.objects:
 if ob.type!='MESH':continue
 key=ob.name
 if 'wind_tree' in ob:key=f'Palm_{ob["wind_tree"]:02}_'+('Trunk' if ob['wind_kind']=='trunk' else 'Canopy')
 groups.setdefault(key,[]).append(ob)
manifest=[]
for name,objects in groups.items():
 # Different materials remain separate where necessary, canopy baked to one green material.
 verts=[o.matrix_world@v.co for o in objects for v in o.data.vertices];center=(Vector(tuple(min(p[i] for p in verts) for i in range(3)))+Vector(tuple(max(p[i] for p in verts) for i in range(3))))/2;vv=[];ff=[]
 for ob in objects:
  me=ob.data;me.calc_loop_triangles();uv=me.uv_layers.active
  for tri in me.loop_triangles:
   if tri.area<1e-8:continue
   ids=[]
   for li in tri.loops:
    v=me.vertices[me.loops[li].vertex_index];pos=ob.matrix_world@v.co-center;n=ob.matrix_world.to_3x3()@(v.normal if me.polygons[tri.polygon_index].use_smooth else tri.normal);n.normalize();co=uv.data[li].uv;ids.append(len(vv));vv.append((*rv(pos),*rv(n),co[0],1-co[1],0))
   ff.append(ids)
 if len(ff)>9500:raise RuntimeError(f'Mesh too dense: {name} {len(ff)}')
 raw=b'version 2.00\n'+struct.pack('<HBBII',12,36,12,len(vv),len(ff))+b''.join(struct.pack('<9f',*v) for v in vv)+b''.join(struct.pack('<3I',*f) for f in ff);(OUT/'Roblox_LocalAssets'/(name+'.mesh')).write_bytes(raw)
 ob=objects[0];material=ob.data.materials[0];canopy=name.endswith('Canopy');textured=material.name in('Dirt','Grass','Cliff','Bark') and not canopy;color=[1,1,1] if textured else list(mats['Leaf'].diffuse_color[:3] if canopy else material.diffuse_color[:3]);color=[12.92*c if c<=.0031308 else 1.055*c**(1/2.4)-.055 for c in color]
 entry={'name':name,'center':rv(center),'texture_file':material.name+'.png' if textured else None,'color':color,'triangles':len(ff),'file':name+'.mesh'}
 if 'wind_tree' in ob:entry['wind']={'tree':ob['wind_tree'],'kind':'canopy' if canopy else 'trunk','base':rv(ob['wind_base']),'crown':rv(ob['wind_crown']),'phase':ob['wind_phase']}
 manifest.append(entry)
(OUT/'mesh_manifest.json').write_text(json.dumps(manifest))
data={'length':2000,'width':72,'staging':64,'runout':120,'palms':palm_index,'origin':[6000,12000,0],'samples':[{'s':s,'h':height(s)} for s in samples],'boosts':boosts,'max_slope_degrees':max(math.degrees(abs(math.atan(g(s)))) for s in range(2121)),'triangles':sum(m['triangles'] for m in manifest)}
(OUT/'map_data.json').write_text(json.dumps(data))
# Verify actual deformation differs at two timeline frames, preserving the root.
test=bpy.data.objects['Palm_00_Frond_00'];scene.frame_set(1);dg=bpy.context.evaluated_depsgraph_get();a=test.evaluated_get(dg).to_mesh();v1=[v.co.copy() for v in a.vertices];test.evaluated_get(dg).to_mesh_clear();scene.frame_set(60);dg=bpy.context.evaluated_depsgraph_get();b=test.evaluated_get(dg).to_mesh();delta=max((v.co-v1[i]).length for i,v in enumerate(b.vertices));test.evaluated_get(dg).to_mesh_clear();assert delta>.1
scene.camera=detail;scene.render.resolution_percentage=50;scene.cycles.samples=12
for frame in(1,60,120):scene.frame_set(frame);scene.render.filepath=str(OUT/f'Wind_{frame:03}.png');bpy.ops.render.render(write_still=True)
print('STRAIGHT_COMPLETE',len(manifest),'meshes',palm_index,'palms',data['triangles'],'triangles',data['max_slope_degrees'],'slope',delta,'wind displacement')
