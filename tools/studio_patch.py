#!/usr/bin/env python3
"""Turn the working tree's Luau changes into a small execute_luau snippet.

When the Rojo plugin stops applying patches (see the Studio workflow notes)
the fallback used to be pasting whole files into `.Source`, which for a
40 KB HUD is a lot of text to push through MCP. This prints Luau that makes
only the changed hunks: each one is an old block with enough surrounding
lines to be unique, and its replacement. The snippet checks every old block
occurs exactly once in Studio's copy before touching anything, so a Studio
script that has drifted from `base` is reported, not half-patched.

    python tools/studio_patch.py            # changes against HEAD
    python tools/studio_patch.py HEAD~2     # against another commit
    python tools/studio_patch.py HEAD a.luau b.luau  # only these files

Paste the output into execute_luau (Edit mode). Only files that exist in
both `base` and the working tree are handled; new or deleted scripts are
listed so they can be made by hand.
"""

import difflib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def mounts():
    """(disk dir, instance path) pairs from default.project.json."""
    tree = json.loads((ROOT / "default.project.json").read_text(encoding="utf-8"))["tree"]
    out = []

    def walk(node, path):
        for key, child in node.items():
            if key.startswith("$") or not isinstance(child, dict):
                continue
            here = path + [key]
            if "$path" in child:
                out.append((child["$path"].rstrip("/"), here))
            walk(child, here)

    walk(tree, [])
    return out


def instance_path(rel: str):
    for disk, inst in mounts():
        if rel.startswith(disk + "/"):
            parts = rel[len(disk) + 1 :].split("/")
            name = parts[-1]
            for suffix in (".server.luau", ".client.luau", ".luau"):
                if name.endswith(suffix):
                    name = name[: -len(suffix)]
                    break
            parts[-1] = name
            if name == "init":
                parts.pop()
            return inst + parts
    return None


def git(*args) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, encoding="utf-8").stdout


def hunks(old: str, new: str):
    a = old.split("\n")
    b = new.split("\n")
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    out = []
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal":
            continue
        # grow context until the old block is unique in the old text
        pre = post = 1
        while True:
            lo, hi = max(i1 - pre, 0), min(i2 + post, len(a))
            block = "\n".join(a[lo:hi])
            if old.count(block) == 1 or (lo == 0 and hi == len(a)):
                break
            pre += 1
            post += 1
        rep = "\n".join(a[lo:i1] + b[j1:j2] + a[i2:hi])
        out.append((block, rep))
    return out


def long_string(s: str) -> str:
    level = 1
    while ("]" + "=" * level + "]") in s:
        level += 1
    eq = "=" * level
    # a leading newline right after [==[ is dropped by Lua, so add one to keep it
    return "[" + eq + "[\n" + s + "]" + eq + "]"


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")  # the Windows console default mangles em-dashes
    args = sys.argv[1:]
    base = args[0] if args else "HEAD"
    only = set(args[1:])
    changed = [line for line in git("diff", "--name-only", base, "--", "*.luau").splitlines() if line]
    if only:
        changed = [c for c in changed if c in only]
    skipped = []
    files = []
    for rel in changed:
        path = ROOT / rel
        before = git("show", f"{base}:{rel}")
        inst = instance_path(rel)
        if not path.exists() or before == "" or inst is None:
            skipped.append(rel)
            continue
        after = path.read_text(encoding="utf-8")
        before = before.replace("\r\n", "\n")
        after = after.replace("\r\n", "\n")
        files.append((rel, inst, hunks(before, after)))

    lines = [
        "local function find(path)",
        "\tlocal node = game",
        "\tfor i, name in path do",
        "\t\tnode = if i == 1 then game:GetService(name) else node:FindFirstChild(name)",
        "\t\tif not node then return nil end",
        "\tend",
        "\treturn node",
        "end",
        "local function count(s, sub)",
        "\tlocal n, at = 0, 1",
        "\twhile true do",
        "\t\tlocal i, j = string.find(s, sub, at, true)",
        "\t\tif not i then return n end",
        "\t\tn += 1",
        "\t\tat = j + 1",
        "\tend",
        "end",
        "local jobs = {}",
    ]
    for rel, inst, hs in files:
        lines.append("table.insert(jobs, { %s, { %s }, {" % (json.dumps(rel), ", ".join(json.dumps(p) for p in inst)))
        for old, new in hs:
            lines.append("\t{ %s, %s }," % (long_string(old), long_string(new)))
        lines.append("} })")
    lines += [
        "local report, plans = {}, {}",
        "for _, job in jobs do",
        "\tlocal rel, script, edits = job[1], find(job[2]), job[3]",
        "\tif not script then table.insert(report, rel .. ': not in Studio'); continue end",
        "\tlocal src = script.Source",
        "\tlocal crlf = string.find(src, '\\r\\n', 1, true) ~= nil",
        "\tlocal text = if crlf then string.gsub(src, '\\r\\n', '\\n') else src",
        "\tlocal ok = true",
        "\tfor k, e in edits do",
        "\t\tif count(text, e[2]) == 1 and count(text, e[1]) == 0 then continue end -- already applied",
        "\t\tlocal n = count(text, e[1])",
        "\t\tif n ~= 1 then table.insert(report, ('%s: hunk %d found %d times'):format(rel, k, n)); ok = false; break end",
        "\t\tlocal i, j = string.find(text, e[1], 1, true)",
        "\t\ttext = string.sub(text, 1, i - 1) .. e[2] .. string.sub(text, j + 1)",
        "\tend",
        "\tif ok then table.insert(plans, { script, if crlf then string.gsub(text, '\\n', '\\r\\n') else text, rel }) end",
        "end",
        "if #report > 0 then return 'NOTHING CHANGED: ' .. table.concat(report, '; ') end",
        "for _, p in plans do p[1].Source = p[2]; table.insert(report, p[3]) end",
        "return 'patched: ' .. table.concat(report, ', ')",
    ]
    print("\n".join(lines))
    if skipped:
        print("-- not handled (new, deleted or unmapped): " + ", ".join(skipped), file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
