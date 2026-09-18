"""Which words a script has on one side and not the other (X345).

The last resort when a script differs and the line diff is useless because
Studio's copy is condensed (a table written over twenty lines on disk sits on
one line there). Word counts survive both condensing and reordering, so what
this prints is a real difference in the code every time.

    print(require(game.ServerStorage.ParityProbe).wordCounts("<dot.path>"))
    python tools/word_parity.py <disk path> <that output saved to a file>
"""

import collections
import importlib.util
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("sp", os.path.join(ROOT, "tools", "studio_parity.py"))
sp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sp)


def spaced(source: str) -> str:
    """`studio_parity.strip`, but whitespace becomes one separator so the words
    either side of a newline do not run together. Mirrors ParityProbe.spaced."""
    out = []
    i, n = 0, len(source)
    quote = None
    while i < n:
        c = source[i]
        if quote:
            out.append(c)
            if quote in ("'", '"'):
                if c == "\\":
                    if i + 1 < n:
                        out.append(source[i + 1])
                        i += 2
                        continue
                elif c == quote:
                    quote = None
            elif source.startswith(quote, i):
                out.append(source[i + 1 : i + len(quote)])
                i += len(quote)
                quote = None
                continue
            i += 1
            continue
        if source.startswith("--", i):
            rest = source[i + 2 :]
            if rest.startswith("["):
                level = 0
                j = i + 3
                while j < n and source[j] == "=":
                    level += 1
                    j += 1
                if j < n and source[j] == "[":
                    close = "]" + "=" * level + "]"
                    end = source.find(close, j)
                    i = n if end == -1 else end + len(close)
                    out.append(" ")
                    continue
            end = source.find("\n", i)
            i = n if end == -1 else end
            out.append(" ")
            continue
        if c in "'\"":
            out.append(c)
            quote = c
            i += 1
            continue
        if c == "[":
            level = 0
            j = i + 1
            while j < n and source[j] == "=":
                level += 1
                j += 1
            if j < n and source[j] == "[":
                out.append(source[i : j + 1])
                quote = "]" + "=" * level + "]"
                i = j + 1
                continue
        out.append(" " if c.isspace() else c)
        i += 1
    return "".join(out)


def words(source: str):
    return collections.Counter(re.findall(r"[\w_]+", spaced(source)))


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    with open(os.path.join(ROOT, sys.argv[1]), encoding="utf-8") as f:
        disk = words(f.read())
    studio = collections.Counter()
    with open(sys.argv[2], encoding="utf-8") as f:
        for pair in f.read().split():
            word, _, count = pair.rpartition(":")
            if word:
                studio[word] = int(count)

    only_disk = disk - studio
    only_studio = studio - disk
    if only_disk:
        print("on disk only:")
        for word, n in sorted(only_disk.items(), key=lambda kv: (-kv[1], kv[0])):
            print("  %-34s x%d" % (word, n))
    if only_studio:
        print("in studio only:")
        for word, n in sorted(only_studio.items(), key=lambda kv: (-kv[1], kv[0])):
            print("  %-34s x%d" % (word, n))
    if not only_disk and not only_studio:
        print("the same words, the same number of times - condensing or order only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
