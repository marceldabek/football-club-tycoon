"""Order-insensitive Studio/disk parity (X345).

tools/studio_parity.py hashes the whole stripped file, so a script whose lines
were pasted into Studio in a different order reads as "DIFFERS" - 57 of 194 did,
and every one I checked by hand was only a reordering. That noise is why the
X344 bug (`scoutLevel += 1` on one side only) sat unnoticed.

This compares a *digest* instead: the number of code lines, and the sum of their
fingerprints. Reordering cannot change either, so anything this reports is a
real difference in the code.

    print(require(game.ServerStorage.ParityProbe).digests())   -- in Studio
    python tools/parity_digest.py <that output saved to a file>

Then, for each script it names:

    print(require(game.ServerStorage.ParityProbe).lineHashes("<dot.path>"))
    python tools/line_parity.py <disk path> <that output saved to a file>
"""

import importlib.util
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("sp", os.path.join(ROOT, "tools", "studio_parity.py"))
sp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sp)

ROOTS = [("src/shared", "Shared"), ("src/server", "Server"), ("src/client", "Client"), ("tests", "Tests")]
# where each root lives in the data model, for the follow-up lineHashes call
PATHS = {
    "Shared": "ReplicatedStorage.Shared",
    "Server": "ServerScriptService.Server",
    "Client": "StarterPlayer.StarterPlayerScripts.Client",
    "Tests": "ServerStorage.Tests",
}


def digest(source: str):
    """(code lines, sum of their fingerprints). Mirrored in ParityProbe."""
    count, total = 0, 0
    for line in source.splitlines():
        code = sp.strip(line)
        if code:
            count += 1
            total = (total + sp.fnv1a(code)) % 2**32
    return count, total


def disk_digests():
    out = {}
    for folder, key in ROOTS:
        directory = os.path.join(ROOT, folder)
        if not os.path.isdir(directory):
            continue
        for filename in sorted(os.listdir(directory)):
            if filename.endswith(".luau"):
                with open(os.path.join(directory, filename), encoding="utf-8") as f:
                    out["%s.%s" % (key, sp.studio_name(filename))] = (
                        digest(f.read()),
                        "%s/%s" % (folder, filename),
                    )
    return out


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    studio = {}
    for line in open(sys.argv[1], encoding="utf-8"):
        parts = line.split()
        if len(parts) == 3 and parts[1] != "MISSING":
            studio[parts[0]] = (int(parts[1]), int(parts[2]))
    mine = disk_digests()

    bad = []
    for name, ((count, total), path) in sorted(mine.items()):
        if name not in studio:
            bad.append("MISSING IN STUDIO  %s" % name)
            continue
        scount, stotal = studio[name]
        if (count, total) != (scount, stotal):
            bad.append("DIFFERS  %-38s disk %d lines, studio %d lines  (%s)"
                       % (name, count, scount, path))
    for name in sorted(studio):
        if name not in mine:
            bad.append("MISSING ON DISK    %s" % name)

    print("parity: %d scripts on disk, %d in studio" % (len(mine), len(studio)))
    if not bad:
        print("every script matches line for line (order aside)")
        return 0
    print("\n".join(bad))
    print()
    print("%d differ. For each one:" % len(bad))
    for line in bad:
        if line.startswith("DIFFERS"):
            name = line.split()[1]
            root, short = name.split(".", 1)
            print('  print(require(game.ServerStorage.ParityProbe).lineHashes("%s.%s"))'
                  % (PATHS[root], short))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
