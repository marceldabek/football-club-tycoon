# Pre-downscale and re-encode kit textures so GLBs stay small (Open Cloud limit is 20 MB per file).
# UKSP: <prefix>_<map>.png/tif -> texcache/{1k,2k}/<prefix>_<map>.jpg (normal maps green-flipped DirectX->OpenGL)
# MEH:  TrimSheet_0N_<Map>.png -> texcache/2k/TrimSheet_0N_<Map>.jpg
import os, re, glob, sys, json, time
from PIL import Image
Image.MAX_IMAGE_PIXELS = None
RAW = r"F:\dev\football-club-tycoon\assets\kit\_raw"
OUT = r"F:\dev\football-club-tycoon\assets\kit\_export\texcache"
UK = os.path.join(RAW, "UKStreetProps", "RoadTrafficProps")
MEH = os.path.join(RAW, "ModularEnglishHousing", "Modular_English_Housing._Textures")
os.makedirs(os.path.join(OUT, "1k"), exist_ok=True); os.makedirs(os.path.join(OUT, "2k"), exist_ok=True)
log = []
def has_alpha(im):
    if im.mode in ("RGBA", "LA"):
        a = im.getchannel("A"); lo, hi = a.getextrema(); return lo < 250
    return False
def save(im, path_noext, kind, flip_green):
    if kind == "N" and flip_green:
        r, g, b = im.convert("RGB").split()
        g = g.point(lambda v: 255 - v)
        im = Image.merge("RGB", (r, g, b))
    if kind in ("R", "M", "AO", "O"):
        im = im.convert("L"); im.save(path_noext + ".jpg", quality=85, optimize=True); return path_noext + ".jpg"
    if kind == "D" and has_alpha(im):
        im.save(path_noext + ".png", optimize=True); return path_noext + ".png"
    im = im.convert("RGB"); im.save(path_noext + ".jpg", quality=(92 if kind == "N" else 88), optimize=True); return path_noext + ".jpg"
def process(src, name, kind, sizes, flip_green):
    try:
        im = Image.open(src); im.load()
    except Exception as e:
        log.append("ERR open %s %s" % (src, e)); return
    for res in sizes:
        target = 1024 if res == "1k" else 2048
        w, h = im.size; f = min(1.0, target / max(w, h))
        im2 = im.resize((max(1, int(w * f)), max(1, int(h * f))), Image.LANCZOS) if f < 1 else im
        outp = os.path.join(OUT, res, name + "_" + kind)
        if not (os.path.exists(outp + ".jpg") or os.path.exists(outp + ".png")):
            save(im2, outp, kind, flip_green)
t0 = time.time()
files = glob.glob(os.path.join(UK, "*.png")) + glob.glob(os.path.join(UK, "*.tif"))
for i, p in enumerate(files):
    b = os.path.splitext(os.path.basename(p))[0]
    m = re.match(r"(.+?)_(D|N|R|M|AO|E|O)$", b)
    if not m: continue
    if m.group(2) == "AO": continue  # Roblox has no AO slot
    process(p, m.group(1), m.group(2), ("1k", "2k"), flip_green=True)
    if i % 40 == 0: print("uksp", i, "/", len(files), round(time.time() - t0), "s", flush=True)
for p in glob.glob(os.path.join(MEH, "*", "*.png")):
    b = os.path.basename(p)[:-4]  # TrimSheet_01_BaseColor
    m = re.match(r"(TrimSheet_0\d)_(BaseColor|Normal|Roughness|Metallic)$", b)
    if not m: continue
    kind = {"BaseColor": "D", "Normal": "N", "Roughness": "R", "Metallic": "M"}[m.group(2)]
    process(p, m.group(1), kind, ("2k",), flip_green=False)
print("done in", round(time.time() - t0), "s;", len(log), "errors"); print("\n".join(log))
