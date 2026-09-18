#!/usr/bin/env python3
"""X329: find calls to a `local function` that happen above its declaration.

Luau resolves a local by where it is *declared*, not by where it is called, so

    local function a()
        b()          -- b is nil here, at run time, with no compile error
    end
    local function b() end

throws "attempt to call a nil value" the first time `a` runs - and only then,
which is why three of these shipped tonight before anyone noticed (X296's
clampToPitch, X322's updateSpots and X328's ageColour, which silently emptied
the whole squad screen).

The check is deliberately blunt: for every module-scope `local function NAME` in
a file, look for `NAME(` on an earlier line. Nested helpers are skipped (two
functions can each have their own `piece`), forward declarations (`local NAME`
on its own, or `local NAME: ...` above) are respected, and comments and string
literals are stripped first.

    python tools/late_locals.py            # whole repo, exit 1 if anything is found
    python tools/late_locals.py src/client # one directory
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DECL = re.compile(r"^(\s*)local\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
FORWARD = re.compile(r"^\s*local\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^=]*)?(?:=\s*nil\s*)?$")


def strip_noise(line: str) -> str:
    """Drop comments and string bodies so they cannot look like calls."""
    line = re.sub(r"--\[=*\[.*?\]=*\]", " ", line)
    line = re.sub(r"--.*$", "", line)
    line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
    line = re.sub(r"'(?:\\.|[^'\\])*'", "''", line)
    return line


def body_range(lines, start: int) -> int:
    """Line index just past the `end` that closes the function starting at `start`."""
    indent = len(lines[start]) - len(lines[start].lstrip())
    for i in range(start + 1, len(lines)):
        stripped = lines[i].strip()
        if not stripped:
            continue
        here = len(lines[i]) - len(lines[i].lstrip())
        if here <= indent and stripped.startswith("end"):
            return i
    return len(lines) - 1


def check(path: Path):
    text = path.read_text(encoding="utf-8")
    raw = text.splitlines()
    clean = [strip_noise(l) for l in raw]

    forwards = set()
    for line in clean:
        m = FORWARD.match(line)
        if m:
            forwards.add(m.group(1))

    findings = []
    for i, line in enumerate(clean):
        m = DECL.match(line)
        if not m:
            continue
        if m.group(1):
            # Only module-scope helpers. A `local function` nested inside another
            # function is a different binding, and two of them sharing a name
            # (EstateDresser's `piece`, WorldBuilder's `slab`) is not a bug.
            continue
        name = m.group(2)
        if name in forwards:
            continue  # declared above, assigned here: fine
        call = re.compile(r"(?<![A-Za-z0-9_.:])" + re.escape(name) + r"\s*\(")
        for j in range(0, i):
            if call.search(clean[j]):
                findings.append((name, j + 1, i + 1))
                break
    return findings


def main() -> int:
    targets = sys.argv[1:] or ["src", "tests", "tools"]
    total = 0
    for target in targets:
        base = ROOT / target
        files = sorted(base.rglob("*.luau")) if base.is_dir() else [base]
        for path in files:
            for name, used, declared in check(path):
                rel = path.relative_to(ROOT).as_posix()
                print(f"{rel}:{used}: calls `{name}`, declared at line {declared}")
                total += 1
    if total == 0:
        print("no late locals")
        return 0
    print(f"\n{total} late local call(s)")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
