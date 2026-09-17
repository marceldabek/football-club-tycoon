"""Upload kit GLBs to Roblox through the Open Cloud Assets API and record the asset ids.

Usage (PowerShell):
    $env:ROBLOX_API_KEY = "<key with Assets read/write>"
    python tools/upload_kit.py --user 74667306 --list assets/kit/_export/upload_list.txt

The list file holds one GLB filename per line (relative to assets/kit/_export/glb/).
Results are appended to assets/kit/_export/asset_ids.json as {"file": {"assetId": ..., "name": ...}}
so re-runs skip files that already uploaded. Files over 20 MB are skipped (API limit).

Image mode (textures from tools/kit/make_facades.py):
    python tools/upload_kit.py --user 74667306 --images assets/kit/_export/upload_textures.txt

The list holds PNG filenames relative to assets/kit/_export/textures/. They upload as assetType
"Image" and the ids go to assets/kit/_export/asset_ids_textures.json (same skip-if-done rule).
"""
import argparse, json, os, sys, time, urllib.request, urllib.error, uuid

API = "https://apis.roblox.com/assets/v1"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GLB_DIR = os.path.join(ROOT, "assets", "kit", "_export", "glb")
IDS_PATH = os.path.join(ROOT, "assets", "kit", "_export", "asset_ids.json")
TEX_DIR = os.path.join(ROOT, "assets", "kit", "_export", "textures")
TEX_IDS_PATH = os.path.join(ROOT, "assets", "kit", "_export", "asset_ids_textures.json")


def multipart(fields, file_field, filename, data, content_type):
    boundary = "----fct" + uuid.uuid4().hex
    body = b""
    for k, v in fields.items():
        body += ("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % (boundary, k, v)).encode()
    body += ("--%s\r\nContent-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n" % (boundary, file_field, filename, content_type)).encode()
    body += data + ("\r\n--%s--\r\n" % boundary).encode()
    return body, "multipart/form-data; boundary=" + boundary


def request(method, url, key, body=None, content_type=None):
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", key)
    if content_type:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        return e.code, {"error": e.read().decode()[:500]}


def upload_one(path, key, user_id, display_name, asset_type="Model", content_type="model/gltf-binary"):
    data = open(path, "rb").read()
    req_json = json.dumps({
        "assetType": asset_type,
        "displayName": display_name[:50],
        "description": "Football Club Tycoon kit asset",
        "creationContext": {"creator": {"userId": str(user_id)}},
    })
    body, ctype = multipart({"request": req_json}, "fileContent", os.path.basename(path), data, content_type)
    status, resp = request("POST", API + "/assets", key, body, ctype)
    if status != 200:
        return None, "create failed %s %s" % (status, resp)
    op = resp.get("path") or ("operations/" + resp.get("operationId", ""))
    for _ in range(60):
        time.sleep(2)
        status, r = request("GET", API + "/" + op, key)
        if status == 200 and r.get("done"):
            if "response" in r and "assetId" in r["response"]:
                return r["response"]["assetId"], None
            return None, "operation finished without assetId: %s" % json.dumps(r)[:300]
    return None, "timed out waiting for operation " + op


def main():
    global IDS_PATH
    ap = argparse.ArgumentParser()
    ap.add_argument("--user", required=True)
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--list", help="GLB names in assets/kit/_export/glb/, uploaded as Model")
    mode.add_argument("--images", help="PNG names in assets/kit/_export/textures/, uploaded as Image")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--ids", default=None, help="ids json to read/write (use one per worker)")
    ap.add_argument("--skip", default="", help="comma-separated extra ids json files whose entries are treated as done")
    args = ap.parse_args()
    key = os.environ.get("ROBLOX_API_KEY")
    if not key:
        sys.exit("set ROBLOX_API_KEY first")
    images = args.images is not None
    IDS_PATH = args.ids or (TEX_IDS_PATH if images else IDS_PATH)
    src_dir = TEX_DIR if images else GLB_DIR
    list_path = args.images if images else args.list
    ids = json.load(open(IDS_PATH)) if os.path.exists(IDS_PATH) else {}
    for extra in [p for p in args.skip.split(",") if p]:
        if os.path.exists(extra):
            for k in json.load(open(extra)):
                ids.setdefault(k, {"assetId": None, "name": "(uploaded by another worker)"})
    names = [l.strip() for l in open(list_path) if l.strip() and not l.startswith("#")]
    done = 0
    for name in names:
        if name in ids:
            continue
        path = os.path.join(src_dir, name)
        if not os.path.exists(path):
            print("missing", name); continue
        if os.path.getsize(path) > 20 * 1024 * 1024:
            print("skip >20MB", name); continue
        display = os.path.splitext(name)[0].replace("__", " ")
        if images:
            asset_id, err = upload_one(path, key, args.user, "FCT " + display, "Image", "image/png")
        else:
            asset_id, err = upload_one(path, key, args.user, display)
        if err:
            print("FAIL", name, err)
        else:
            ids[name] = {"assetId": asset_id, "name": display}
            json.dump(ids, open(IDS_PATH, "w"), indent=1)
            print("ok", name, asset_id)
            done += 1
        if args.limit and done >= args.limit:
            break
        time.sleep(1)
    print("uploaded", done, "total recorded", len(ids))


if __name__ == "__main__":
    main()
