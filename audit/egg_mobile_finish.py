import bpy, math
from pathlib import Path
from mathutils import Vector
# em is supplied by the generator or an MCP caller.
scene=bpy.context.scene
coll=bpy.data.collections.new('Studio')
scene.collection.children.link(coll)
em.setup_render(scene)
scene.view_settings.look='AgX - Medium High Contrast'
scene.view_settings.exposure=0.15
scene.eevee.taa_render_samples=48
scene.render.resolution_x=1280
scene.render.resolution_y=960
scene.render.resolution_percentage=100
scene.use_nodes=False
world=bpy.data.worlds.new('Neutral Studio')
scene.world=world
world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.23,.25,.28,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.6
for name,loc,power,size in [('Key',(-9,12,-8),2300,8),('Fill',(9,8,-2),1800,7),('Rim',(1,11,8),2600,6)]:
    light=bpy.data.lights.new(name,'AREA');light.energy=power;light.shape='DISK';light.size=size
    ob=bpy.data.objects.new(name,light);coll.objects.link(ob)
    em.aim(ob,loc,(0,3.5,0))
floor=em.simple_mat('Studio Floor',(106,113,123),rough=.8)
em.add_mesh('Ground',[(-200,0,-200),(200,0,-200),(200,0,200),(-200,0,200)],[(0,1,2,3)],floor,coll,False)
target=(0,3.7,0)
cam=em.add_camera('Camera_Front',em.orbit(-65,16,19,target),target,42,coll)
scene.camera=cam
for name,az,el in [('Camera_Rear',-150,32),('Camera_FrontStraight',0,15),('Camera_Side',-90,12)]:
    em.add_camera(name,em.orbit(az,el,19,target),target,42,coll)
# Apply the generated image only to roughness so the original color palette is preserved.
tex=bpy.data.images.load(str(em.OUT/'textures/Enamel_Microdetail.png'),check_existing=True)
tex.colorspace_settings.name='Non-Color'
tex.pack()
for name in ['EM_HullWhite','EM_HullBlack','EM_Metal','EM_Chrome','EM_Seat','EM_TrimYellow']:
    mat=bpy.data.objects[name].data.materials[0];nt=mat.node_tree;bsdf=nt.nodes.get('Principled BSDF')
    image=nt.nodes.new('ShaderNodeTexImage');image.image=tex;image.projection='BOX';image.projection_blend=.25
    co=nt.nodes.new('ShaderNodeTexCoord');nt.links.new(co.outputs['Generated'],image.inputs['Vector'])
    ramp=nt.nodes.new('ShaderNodeMapRange');ramp.inputs['From Min'].default_value=0;ramp.inputs['From Max'].default_value=1
    ramp.inputs['To Min'].default_value=.10 if name!='EM_Seat' else .23
    ramp.inputs['To Max'].default_value=.24 if name!='EM_Seat' else .37
    nt.links.new(image.outputs['Color'],ramp.inputs['Value']);nt.links.new(ramp.outputs['Result'],bsdf.inputs['Roughness'])
    if name=='EM_HullWhite':
        bsdf.inputs['Metallic'].default_value=.05
        bsdf.inputs['Coat Weight'].default_value=.45
    if name in ['EM_Metal','EM_Chrome']:
        bsdf.inputs['Metallic'].default_value=.75
em.aim(bpy.data.objects['Camera_Front'],em.orbit(-42,19,21.5,(0,3.65,0)),(0,3.65,0))
em.aim(bpy.data.objects['Camera_FrontStraight'],em.orbit(0,19,21.5,(0,3.65,0)),(0,3.65,0))
bpy.data.objects['Camera_Front'].data.lens=50
bpy.data.objects['Camera_FrontStraight'].data.lens=50
scene.eevee.taa_render_samples=96
scene.render.resolution_x=1600
scene.render.resolution_y=1200
for key,cam in [('front','Camera_Front'),('rear','Camera_Rear'),('centered_lamp','Camera_FrontStraight')]:
    scene.camera=bpy.data.objects[cam]
    scene.render.filepath=str(em.PREV/(key+'.png'))
    bpy.ops.render.render(write_still=True)
scene.camera=bpy.data.objects['Camera_Front']
bpy.ops.wm.save_as_mainfile(filepath=str(em.OUT/'EggMobile_Corrected.blend'))
