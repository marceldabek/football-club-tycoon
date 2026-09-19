# Blender headless GLB exporter for the FCT kit (v3: uses pre-built texcache).  usage: blender -b --python export_glb_v3.py -- jobs.json
import bpy, os, sys, json, re, glob, difflib
argv = sys.argv[sys.argv.index("--")+1:]
J = json.load(open(argv[0]))
SPM = J.get("studs_per_meter", 2.75)
OUT = J["out_dir"]; os.makedirs(OUT, exist_ok=True)
CACHE = J["texcache"]
report = []
def log(*a): print("[export]", *a)

def cache_sets(res):
    sets = {}
    for p in glob.glob(os.path.join(CACHE, res, "*.jpg")) + glob.glob(os.path.join(CACHE, res, "*.png")):
        b = os.path.splitext(os.path.basename(p))[0]
        m = re.match(r"(.+?)_(D|N|R|M|E|O)$", b)
        if m: sets.setdefault(m.group(1), {})[m.group(2)] = p
    return sets
SETS = {"1k": cache_sets("1k"), "2k": cache_sets("2k")}
OVERRIDES = J.get("material_overrides", {})
def resolve_prefix(matname, sets):
    if matname in OVERRIDES: return OVERRIDES[matname]
    n = matname.lower().replace("_", "")
    if n.startswith("mi"): n = n[2:]
    n = re.sub(r"(shader|mat|material)$", "", n)
    n = re.sub(r"glass$", "", n)
    keys = {k.lower().replace("_", ""): k for k in sets}
    if n in keys: return keys[n]
    c = difflib.get_close_matches(n, list(keys.keys()), n=1, cutoff=0.6)
    return keys[c[0]] if c else None

def load_img(path, srgb):
    img = bpy.data.images.load(path, check_existing=True)
    img.colorspace_settings.name = 'sRGB' if srgb else 'Non-Color'
    return img

def build_pbr(m, ts, glass):
    m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial"); bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    if "D" in ts:
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = load_img(ts["D"], True); nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
        if ts["D"].lower().endswith(".png"):
            nt.links.new(t.outputs["Alpha"], bsdf.inputs["Alpha"])
            try: m.surface_render_method = 'DITHERED'
            except Exception: pass
            try: m.blend_method = 'CLIP'; m.alpha_threshold = 0.5
            except Exception: pass
    if "R" in ts:
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = load_img(ts["R"], False); nt.links.new(t.outputs["Color"], bsdf.inputs["Roughness"])
    else:
        bsdf.inputs["Roughness"].default_value = 0.7
    if "M" in ts:
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = load_img(ts["M"], False); nt.links.new(t.outputs["Color"], bsdf.inputs["Metallic"])
    else:
        bsdf.inputs["Metallic"].default_value = 0.0
    if "N" in ts:
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = load_img(ts["N"], False)
        nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(t.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if "E" in ts:
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = load_img(ts["E"], True); nt.links.new(t.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.0
    if glass:
        bsdf.inputs["Alpha"].default_value = 0.35
        try: m.surface_render_method = 'BLENDED'
        except Exception: pass
        try: m.blend_method = 'BLEND'
        except Exception: pass

def build_uksp_materials(job):
    res = "1k" if job.get("max_tex", 2048) <= 1024 else "2k"
    sets = SETS[res]
    for m in bpy.data.materials:
        if not m.users: continue
        prefix = resolve_prefix(m.name, sets)
        if not prefix or prefix not in sets:
            log("no texture set for", m.name); continue
        build_pbr(m, sets[prefix], "glass" in m.name.lower())
        m["fct_prefix"] = prefix

def build_meh_materials(job):
    ts = job.get("trimsheet", 1); sets = SETS["2k"]
    key = "TrimSheet_0%d" % ts
    if key not in sets: log("missing trimsheet cache", key); return
    for m in bpy.data.materials:
        if m.users and m.name.startswith("M_Modular"):
            build_pbr(m, sets[key], False); m["fct_prefix"] = key

def shrink_and_pack_images(objs, job):
    max_tex = job.get("max_tex", 2048); done = set()
    for o in objs:
        for m in o.data.materials:
            if not m or not m.use_nodes: continue
            for n in m.node_tree.nodes:
                if n.type != 'TEX_IMAGE' or not n.image or n.image.name in done: continue
                img = n.image; done.add(img.name)
                if img.size[0] == 0:
                    try: img.reload()
                    except Exception: pass
                if img.size[0] == 0: log("image has no data:", img.name); continue
                changed = False
                if img.size[0] > max_tex or img.size[1] > max_tex:
                    f = max_tex / max(img.size); img.scale(max(1, int(img.size[0]*f)), max(1, int(img.size[1]*f))); changed = True
                is_float = img.file_format in ('OPEN_EXR', 'OPEN_EXR_MULTILAYER', 'HDR') or img.is_float
                if is_float or changed:
                    # write an 8-bit JPEG copy next to the cache and swap the node to it (keeps GLBs small)
                    cache_dir = os.path.join(CACHE, "conv"); os.makedirs(cache_dir, exist_ok=True)
                    base = re.sub(r"[^A-Za-z0-9_.-]", "_", os.path.splitext(img.name)[0]) + "_%d.jpg" % max_tex
                    outp = os.path.join(cache_dir, base)
                    try:
                        img.file_format = 'JPEG'
                        img.save(filepath=outp, quality=90)
                        cs = img.colorspace_settings.name
                        new = bpy.data.images.load(outp, check_existing=True)
                        new.colorspace_settings.name = cs
                        n.image = new
                    except Exception as e:
                        log("jpeg convert failed", img.name, e)
                        img.file_format = 'PNG'
                        try: img.pack()
                        except Exception as e2: log("pack failed", img.name, e2)

def load_source(job):
    src = job["source"]
    if src.lower().endswith(".blend"):
        bpy.ops.wm.open_mainfile(filepath=src, load_ui=False)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=src)

def deselect_all():
    # 32 of the 68 Modular English Housing piece .blend files were saved with their
    # object in Edit Mode. bpy.ops.object.select_all then fails its poll ("context is
    # incorrect") and the whole job errors out, which is why only 13 MEH pieces had
    # ever been exported. Setting select_set directly does not need the operator poll.
    for _ob in bpy.context.view_layer.objects:
        _ob.select_set(False)

def prep_object(o, job):
    if o.mode != 'OBJECT':
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.mode_set(mode='OBJECT')
    deselect_all(); o.select_set(True); bpy.context.view_layer.objects.active = o
    if o.parent: bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    s = SPM / job.get("source_units_per_meter", 1.0)
    o.scale = (s, s, s); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    # keep only the render UV layer: Roblox samples the last UV set, and lightmap UVs break trim sheets
    uvl = o.data.uv_layers
    if len(uvl) > 1:
        keep = None
        for l in uvl:
            if l.active_render: keep = l.name
        for l in [l for l in uvl if l.name != keep]:
            uvl.remove(l)
    vs = o.data.vertices
    if len(vs) == 0: return 0
    mn = [min(v.co[i] for v in vs) for i in range(3)]; mx = [max(v.co[i] for v in vs) for i in range(3)]
    if job.get("ground", True):
        o.location = (-(mn[0]+mx[0])/2, -(mn[1]+mx[1])/2, -mn[2]); bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    me = o.data; me.calc_loop_triangles(); tris = len(me.loop_triangles)
    limit = job.get("tri_limit", 19000)
    if tris > limit:
        mod = o.modifiers.new("dec", "DECIMATE"); mod.ratio = limit / tris * 0.95
        bpy.ops.object.modifier_apply(modifier=mod.name); me.calc_loop_triangles(); tris = len(me.loop_triangles)
    return tris

def export_selected(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
        export_texcoords=True, export_normals=True, export_materials='EXPORT', export_image_format='AUTO',
        export_animations=False, export_skins=False, export_morph=False)

for job in J["jobs"]:
    try:
        load_source(job)
        objs = [o for o in bpy.data.objects if o.type == 'MESH']
        inc = job.get("objects"); rx = job.get("object_regex")
        if inc: objs = [o for o in objs if o.name in inc]
        if rx: objs = [o for o in objs if re.search(rx, o.name)]
        if not objs:
            report.append({"job": job["name"], "error": "no objects"}); continue
        mode = job.get("mode")
        if mode == "uksp": build_uksp_materials(job)
        elif mode == "meh": build_meh_materials(job)
        shrink_and_pack_images(objs, job)
        if job.get("split"):
            for o in objs:
                tris = prep_object(o, job)
                if tris == 0: continue
                deselect_all(); o.select_set(True)
                safe = re.sub(r"[^A-Za-z0-9_.-]", "_", o.name)
                outp = os.path.join(OUT, "%s__%s.glb" % (job['name'], safe)); export_selected(outp)
                report.append({"job": job["name"], "object": o.name, "file": os.path.basename(outp), "tris": tris, "dims_studs": [round(x, 2) for x in o.dimensions], "size_MB": round(os.path.getsize(outp)/1e6, 2), "mats": [m.name + "->" + str(m.get("fct_prefix")) for m in o.data.materials if m]})
        else:
            tris = 0
            for o in objs: tris += prep_object(o, job)
            deselect_all()
            for o in objs: o.select_set(True)
            outp = os.path.join(OUT, job["name"] + ".glb"); export_selected(outp)
            report.append({"job": job["name"], "objects": [o.name for o in objs], "file": os.path.basename(outp), "tris": tris, "dims_studs": [round(x, 2) for x in objs[0].dimensions], "size_MB": round(os.path.getsize(outp)/1e6, 2)})
    except Exception as e:
        import traceback; report.append({"job": job["name"], "error": str(e), "trace": traceback.format_exc()[-800:]})
json.dump(report, open(os.path.join(OUT, "_export_report.json"), "w"), indent=1)
errs = [r for r in report if "error" in r]
big = [r for r in report if r.get("size_MB", 0) > 18]
print("[export] done: %d entries, %d errors, %d over 18MB" % (len(report), len(errs), len(big)))
for r in errs: print("[export] ERROR", r["job"], r["error"])
for r in big: print("[export] BIG", r.get("file"), r.get("size_MB"))
