"""Which lines of a script differ between disk and Studio (X345).

tools/studio_parity.py says *that* a script differs; this says *where*, without
Studio's text ever having to be pasted back - only its fingerprints.

In Studio (Edit datamodel):

    print(require(game.ServerStorage.ParityProbe).lineHashes("<dot.path>"))

writes one 8-hex hash per code line (the whole-line `strip`, so comments and
whitespace cannot matter). Save that to a file, then:

    python tools/line_parity.py src/shared/Config.luau <that file>

It compares the two as *multisets*, because Studio's copies were pasted by hand
and lines are often in a different order - a reordering is not a difference in
the code. What it prints:

  * every disk line whose fingerprint is nowhere in Studio (with the text), and
  * the fingerprints Studio has that disk does not - read those back with
    `ParityProbe.linesWithHashes("<dot.path>", "<hashes>")`, which is how the
    X344 `scoutLevel += 1` line would have been found in seconds.
"""

import collections
import importlib.util
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("sp", os.path.join(ROOT, "tools", "studio_parity.py"))
sp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sp)


def disk_lines(path: str):
    """(hash, line number, text) per code line, as the probe normalises them."""
    out = []
    with open(path, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            code = sp.strip(line)
            if code:
                out.append(("%08x" % sp.fnv1a(code), n, line.rstrip("\n")))
    return out


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    rel = sys.argv[1].replace("\\", "/")
    disk = disk_lines(os.path.join(ROOT, rel))
    studio = open(sys.argv[2], encoding="utf-8").read().split()

    left = collections.Counter(h for h, _, _ in disk)
    right = collections.Counter(studio)
    only_disk = left - right
    only_studio = right - left

    shown = 0
    seen = collections.Counter()
    for h, n, text in disk:
        if only_disk[h] > seen[h]:
            seen[h] += 1
            shown += 1
            print("disk only   %s:%d  %s" % (rel, n, text.strip()[:160]))
    if only_studio:
        print()
        print("studio only (%d lines) - read them back with ParityProbe.linesWithHashes:" % sum(only_studio.values()))
        print(" ".join(sorted(only_studio.elements())))
    print()
    print("%d disk lines, %d studio lines: %d only on disk, %d only in studio%s"
          % (len(disk), len(studio), shown, sum(only_studio.values()),
             "" if (shown or only_studio) else " - the same code, in a different order"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
