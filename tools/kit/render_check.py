# Render quick Workbench thumbnails of a few exported GLBs to verify textures/normals before upload.
import bpy, os, sys, math
files = sys.argv[sys.argv.index("--")+1:]
OUT = r"C:\Users\mdabe\AppData\Local\Temp\fct-research\img\glbcheck"
os.makedirs(OUT, exist_ok=True)
for f in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f)
    objs = [o for o in bpy.data.objects if o.type == 'MESH']
    if not objs: continue
    # bounds
    import mathutils
    mn = mathutils.Vector((1e9,1e9,1e9)); mx = mathutils.Vector((-1e9,-1e9,-1e9))
    for o in objs:
        for v in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(v)
            mn = mathutils.Vector((min(mn.x,w.x),min(mn.y,w.y),min(mn.z,w.z))); mx = mathutils.Vector((max(mx.x,w.x),max(mx.y,w.y),max(mx.z,w.z)))
    c = (mn+mx)/2; r = (mx-mn).length/2
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam)
    d = r*2.6
    cam.location = c + mathutils.Vector((d*0.7, -d*0.7, d*0.45))
    direction = c - cam.location; cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    scene.camera = cam
    light_data = bpy.data.lights.new("sun", 'SUN'); light_data.energy = 3.0
    light = bpy.data.objects.new("sun", light_data); scene.collection.objects.link(light); light.rotation_euler = (math.radians(50), 0, math.radians(30))
    scene.render.engine = 'BLENDER_EEVEE' if hasattr(bpy.types, 'RenderEngine') else 'BLENDER_WORKBENCH'
    try:
        scene.render.engine = 'BLENDER_EEVEE_NEXT'
    except Exception:
        scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 640; scene.render.resolution_y = 480; scene.render.resolution_percentage = 100
    scene.world = bpy.data.worlds.new("w"); scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background"); bg.inputs[0].default_value = (0.6, 0.7, 0.85, 1); bg.inputs[1].default_value = 1.0
    scene.render.filepath = os.path.join(OUT, os.path.splitext(os.path.basename(f))[0] + ".png")
    bpy.ops.render.render(write_still=True)
    print("[render]", scene.render.filepath)
