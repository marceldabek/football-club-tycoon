import bpy, os, json, sys, glob
RAW=r"F:\dev\football-club-tycoon\assets\kit\_raw"
OUT=r"C:\Users\mdabe\AppData\Local\Temp\fct-research\inv"
def mesh_stats(obj):
    me=obj.data
    me.calc_loop_triangles()
    tris=len(me.loop_triangles)
    mats=[m.name for m in me.materials if m]
    imgs=set()
    for m in me.materials:
        if m and m.use_nodes:
            for n in m.node_tree.nodes:
                if n.type=='TEX_IMAGE' and n.image: imgs.add(n.image.name)
    dims=[round(x,2) for x in obj.dimensions]
    return {"name":obj.name,"tris":tris,"verts":len(me.vertices),"mats":mats,"images":sorted(imgs),"dims":dims}
result={"meh":{},"uksp":{}}
# --- Modular English Housing blends
for f in sorted(glob.glob(os.path.join(RAW,"ModularEnglishHousing","Modular_English_Housing.blend","**","*.blend"),recursive=True)):
    bpy.ops.wm.open_mainfile(filepath=f, load_ui=False)
    objs=[mesh_stats(o) for o in bpy.data.objects if o.type=='MESH']
    rel=os.path.relpath(f,RAW)
    result["meh"][rel]={"objects":objs,"total_tris":sum(o["tris"] for o in objs)}
# --- UK Street Props FBX
for f in sorted(glob.glob(os.path.join(RAW,"UKStreetProps","RoadTrafficProps","*.fbx"))):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        bpy.ops.import_scene.fbx(filepath=f)
    except Exception as e:
        result["uksp"][os.path.basename(f)]={"error":str(e)}; continue
    objs=[mesh_stats(o) for o in bpy.data.objects if o.type=='MESH']
    result["uksp"][os.path.basename(f)]={"objects":objs,"total_tris":sum(o["tris"] for o in objs)}
json.dump(result,open(os.path.join(OUT,"inventory.json"),"w"),indent=1)
# summary
lines=[]
for k in ("meh","uksp"):
    lines.append(f"=== {k}")
    for rel,v in result[k].items():
        if "error" in v: lines.append(f"{rel}: ERROR {v['error']}"); continue
        big=[o for o in v["objects"] if o["tris"]>20000]
        lines.append(f"{rel}: objs={len(v['objects'])} tris={v['total_tris']} over20k={[ (o['name'],o['tris']) for o in big]}")
open(os.path.join(OUT,"summary.txt"),"w").write("\n".join(lines))
print("\n".join(lines))
