#!/usr/bin/env python3
"""X329/X349: find calls to a `local function` from somewhere it is not visible.

Luau resolves a local by where it is *declared*, not by where it is called, so

    local function a()
        b()          -- b is nil here, at run time, with no compile error
    end
    local function b() end

throws "attempt to call a nil value" the first time `a` runs - and only then,
which is why three of these shipped before anyone noticed (X296's clampToPitch,
X322's updateSpots and X328's ageColour, which silently emptied the whole squad
screen).

X349 is the second shape, which the first version of this checker missed:

    function one()
        local function helper() end   -- nested: visible only inside `one`
        helper()                      -- fine
    end
    function two()
        helper()                      -- nil at run time
    end

That is what X331 did to the HUD's `cheapestStand`: it was pasted into the
middle of `refreshHintText`, so `midGameHint` - a separate function - called an
unbound global and threw the moment demand passed capacity, which is most of
the game. Indentation could not catch it, because the paste left the nested
function at column 0; scope has to be tracked with Lua's own block keywords.

Every `local function` (and every plain `local NAME` forward declaration) gets
the range of lines it is visible in - to the end of the file for a module-scope
one, to the end of the enclosing block for a nested one - and any call outside
every range that declares that name is a finding. Comments and string literals
are stripped first. Names declared `function NAME()` without `local` are
globals, resolved at call time, and are not checked.

If the block counter does not come back to zero at the end of a file, its idea
of scope is not trustworthy, so that file falls back to the module-scope-only
check and says so.

    python tools/late_locals.py            # whole repo, exit 1 if anything is found
    python tools/late_locals.py src/client # one directory
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DECL = re.compile(r"^(\s*)local\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
FORWARD = re.compile(r"^(\s*)local\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^=]*)?(?:=\s*nil\s*)?$")


def strip_noise(line: str) -> str:
    """Drop comments and string bodies so they cannot look like calls."""
    line = re.sub(r"--\[=*\[.*?\]=*\]", " ", line)
    line = re.sub(r"--.*$", "", line)
    line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
    line = re.sub(r"'(?:\\.|[^'\\])*'", "''", line)
    return line


def opens_and_closes(line: str):
    """How many blocks this line opens and closes.

    `function`, `do` and `repeat` always open one. `then` is the awkward one:
    it opens a block in an `if ... then` *statement*, but Luau's `if a then b
    else c` *expression* has no `end`, and this codebase is full of them - the
    first version counted those and drifted twenty blocks deep by the end of
    the HUD. So `then` only counts when the line reads like a statement: the
    line ends on it, or the line starts with `if `. `elseif` reopens a block
    rather than opening one."""
    stripped = line.strip()
    opens = (
        len(re.findall(r"\bfunction\b", line))
        + len(re.findall(r"\bdo\b", line))
        + len(re.findall(r"\brepeat\b", line))
    )
    if re.search(r"\bthen\b", stripped) and not stripped.startswith("elseif"):
        if stripped.endswith("then"):
            opens += 1  # `if ... then` / `and ... then`, body on the lines below
        elif stripped.startswith("if ") and re.search(r"\bend\b", stripped):
            opens += 1  # a one-liner `if x then y end`; its own `end` closes it
        # anything else starting with `if` and carrying an `else` is one of
        # Luau's if-*expressions*, which has no `end` - the HUD builds a table
        # out of them, and counting those drifted the whole file two deep
    closes = len(re.findall(r"\bend\b", line)) + len(re.findall(r"\buntil\b", line))
    return opens, closes


def block_depths(lines):
    """The block depth *before* each line, and whether the count balanced."""
    depths = []
    depth = 0
    for line in lines:
        depths.append(depth)
        opens, closes = opens_and_closes(line)
        depth = max(depth + opens - closes, 0)
    return depths, depth == 0


def scope_end(depths, start: int) -> int:
    """The last line a local declared on `start` is visible on: the line before
    the block holding it closes."""
    depth = depths[start]
    for i in range(start + 1, len(depths)):
        if depths[i] < depth:
            return i - 1
    return len(depths) - 1


def check(path: Path):
    raw = path.read_text(encoding="utf-8").splitlines()
    clean = [strip_noise(line) for line in raw]
    depths, balanced = block_depths(clean)

    # name -> the line ranges it is visible in
    visible = {}
    declared_at = {}
    for i, line in enumerate(clean):
        m = DECL.match(line) or FORWARD.match(line)
        if not m:
            continue
        name = m.group(2)
        nested = len(m.group(1)) > 0 or depths[i] > 0
        if nested and not balanced:
            continue  # cannot trust the scope of a nested one in this file
        stop = scope_end(depths, i) if balanced else len(clean) - 1
        visible.setdefault(name, []).append((i, stop))
        declared_at.setdefault(name, []).append(i + 1)

    findings = []
    for name, ranges in visible.items():
        call = re.compile(r"(?<![A-Za-z0-9_.:])" + re.escape(name) + r"\s*\(")
        for j, line in enumerate(clean):
            if not call.search(line):
                continue
            if any(start <= j <= stop for start, stop in ranges):
                continue
            findings.append((name, j + 1, declared_at[name]))
    findings.sort(key=lambda f: f[1])
    return findings, balanced


def main() -> int:
    targets = sys.argv[1:] or ["src", "tests", "tools"]
    total, unbalanced = 0, []
    for target in targets:
        base = ROOT / target
        files = sorted(base.rglob("*.luau")) if base.is_dir() else [base]
        for path in files:
            findings, balanced = check(path)
            rel = path.relative_to(ROOT).as_posix()
            if not balanced:
                unbalanced.append(rel)
            for name, used, declared in findings:
                where = ", ".join(str(d) for d in declared)
                print(f"{rel}:{used}: calls `{name}`, which is only in scope at line {where}")
                total += 1
    if unbalanced:
        print("(module scope only, the block count did not balance: %s)" % ", ".join(unbalanced))
    if total == 0:
        print("no late locals")
        return 0
    print(f"\n{total} call(s) to a local that is not in scope there")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
