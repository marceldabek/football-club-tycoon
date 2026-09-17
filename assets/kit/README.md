# Asset kit pipeline

Everything under `assets/kit/` except this README and MANIFEST.md is gitignored.

1. **Raw downloads** go in `_raw/` (see MANIFEST.md for sources and licences).
2. **Texture cache** — `prep_textures.py` (currently in `%LOCALAPPDATA%\Temp\fct-research\inv\`) writes
   `_export/texcache/{1k,2k}/` as JPEG (PNG only where alpha matters). Studio-Lab normal maps are
   green-flipped there (DirectX to OpenGL).
3. **GLB export** — Blender 5.1 headless:
   `blender -b --python export_glb_v3.py -- jobs_full.json`
   One GLB per object, 1 unit = 1 stud (2.75 studs/m), pivot at the ground centre, decimated to the
   per-job triangle limit, materials rebuilt from the cache. Report: `_export/glb/_export_report.json`.
4. **Upload** — `python tools/upload_kit.py --user 74667306 --list _export/upload_list.txt` with
   `ROBLOX_API_KEY` set (Open Cloud key, Assets read/write). Asset ids land in `_export/asset_ids.json`.
5. **Insert** — in Studio via the MCP `insert_asset` tool (or InsertService) using the recorded ids.

Roblox limits: 20k triangles per mesh, 20 MB per uploaded file, one material per mesh.
