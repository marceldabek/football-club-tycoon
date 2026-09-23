#!/usr/bin/env python3
"""P1: find identifiers a Luau file reads but never declares where the read can see it.

X369 shipped because the crest builder removed WorldBuilder's `accent` local
and missed one use of it in `buildHonours`. Luau does not complain: an unknown
name is just a global, nil at run time, and the first club with a record
appearance holder failed to load. There is no Luau checker on this machine
(see the Studio workflow notes), so this script does the one job that matters:

    every name a file *reads* must be a local, parameter or loop variable in a
    scope that reaches the read, a global the file itself defines
    (`function name()`, or `name = ...` at the top of the file), or a
    Luau/Roblox global.

It tokenises the file properly (long strings, interpolated strings, comments)
and tracks scopes with the block keywords, including Luau's `if a then b else c`
*expressions*, which have no `end`. Type annotations, field names (`a.b`,
`a:b()`) and table-constructor keys are not reads. A read of a local declared
further down the file is reported too: at run time it is the same nil global,
which also covers what `tools/late_locals.py` checks. An assignment to an
undeclared name inside a block is reported as well: it is nearly always a
local whose `local` line went missing, and it would otherwise excuse every
read of that name.

Checked against history: it flags `accent` in WorldBuilder before 7335607
(X369) and `cheapestStand` in the HUD before 25ec7a5 (X349). A mutation run
that deleted 88 random `local` lines across src caught 87; the miss was a
module used only in type annotations, which cannot fail at run time.

Known gaps, all in the direction of saying nothing: `local x = x` treats the
right-hand `x` as the new local, a `repeat ... until` block's locals stay
visible until the enclosing block ends, and names inside `typeof(...)` in a
type are skipped.

    python tools/free_globals.py            # src, tests, tools; exit 1 on any finding
    python tools/free_globals.py src/server # one directory or file
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in",
    "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
    "continue",
}

LUAU_GLOBALS = {
    "assert", "collectgarbage", "error", "gcinfo", "getfenv", "getmetatable", "ipairs",
    "loadstring", "newproxy", "next", "pairs", "pcall", "print", "rawequal", "rawget", "rawlen",
    "rawset", "require", "select", "setfenv", "setmetatable", "tonumber", "tostring", "type",
    "typeof", "unpack", "xpcall", "_G", "_VERSION",
    "bit32", "buffer", "coroutine", "debug", "math", "os", "string", "table", "utf8", "vector",
}

ROBLOX_GLOBALS = {
    "game", "workspace", "Workspace", "script", "plugin", "shared", "settings", "UserSettings",
    "stats", "tick", "time", "wait", "delay", "spawn", "elapsedTime", "version", "warn", "task",
    "Enum", "Instance", "Axes", "BrickColor", "CatalogSearchParams", "CFrame", "Color3",
    "ColorSequence", "ColorSequenceKeypoint", "Content", "DateTime", "DockWidgetPluginGuiInfo",
    "Faces", "FloatCurveKey", "Font", "NumberRange", "NumberSequence", "NumberSequenceKeypoint",
    "OverlapParams", "Path2DControlPoint", "PathWaypoint", "PhysicalProperties", "Random", "Ray",
    "RaycastParams", "Rect", "Region3", "Region3int16", "RotationCurveKey", "SharedTable",
    "TweenInfo", "UDim", "UDim2", "Vector2", "Vector2int16", "Vector3", "Vector3int16",
}

# Reviewed false positives: "path/relative/to/root.luau": {"name", ...}
ALLOW = {}

OPERATORS = sorted(
    [
        "...", "..=", "//=", "::", "->", "==", "~=", "<=", ">=", "+=", "-=", "*=", "/=", "%=",
        "^=", "//", "..", "+", "-", "*", "/", "%", "^", "#", "&", "|", "?", "<", ">", "=", "(",
        ")", "{", "}", "[", "]", ";", ":", ",", ".", "@",
    ],
    key=len,
    reverse=True,
)

NAME_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
NUMBER_RE = re.compile(
    r"0[xX][0-9A-Fa-f_]+|0[bB][01_]+|(?:[0-9][0-9_]*(?:\.[0-9_]*)?|\.[0-9][0-9_]*)(?:[eE][+-]?[0-9_]+)?"
)
LONG_OPEN_RE = re.compile(r"\[(=*)\[")


class Tok:
    __slots__ = ("kind", "text", "line")

    def __init__(self, kind, text, line):
        self.kind = kind  # "name", "op", "str", "num", "eof"
        self.text = text
        self.line = line

    def __repr__(self):
        return f"{self.kind}:{self.text}@{self.line}"


def tokenize(src: str):
    toks = []
    i, n, line = 0, len(src), 1
    # One entry per open interpolated string: the `{` depth at which its
    # current `{expr}` hole closes and the string text resumes.
    interp = []
    brace = 0

    def read_backtick(i, line):
        """Scan backtick string text from i (just past ` or }) to the next hole or the end."""
        while i < n:
            c = src[i]
            if c == "\\":
                if i + 1 < n and src[i + 1] == "\n":
                    line += 1
                i += 2
                continue
            if c == "\n":
                line += 1
            if c == "`":
                return i + 1, line, False
            if c == "{":
                return i + 1, line, True
            i += 1
        return i, line, False

    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c in " \t\r\f\v":
            i += 1
            continue
        if src.startswith("--", i):
            m = LONG_OPEN_RE.match(src, i + 2)
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, m.end())
                j = n if j < 0 else j + len(close)
                line += src.count("\n", i, j)
                i = j
            else:
                j = src.find("\n", i)
                i = n if j < 0 else j
            continue
        m = LONG_OPEN_RE.match(src, i)
        if m:
            close = "]" + m.group(1) + "]"
            j = src.find(close, m.end())
            j = n if j < 0 else j + len(close)
            toks.append(Tok("str", "", line))
            line += src.count("\n", i, j)
            i = j
            continue
        if c in "\"'":
            start_line = line
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == "\\":
                    if src[j + 1 : j + 2] == "\n":
                        line += 1
                    elif src[j + 1 : j + 2] == "z":
                        k = j + 2
                        while k < n and src[k] in " \t\r\n":
                            line += src[k] == "\n"
                            k += 1
                        j = k
                        continue
                    j += 2
                    continue
                if src[j] == "\n":
                    break  # unterminated; stop at the line end
                j += 1
            toks.append(Tok("str", "", start_line))
            i = j + 1
            continue
        if c == "`":
            toks.append(Tok("str", "", line))
            i, line, hole = read_backtick(i + 1, line)
            if hole:
                interp.append(brace)
                brace += 1
                toks.append(Tok("op", "(", line))  # the hole reads like a parenthesised expression
            continue
        if c.isdigit() or (c == "." and i + 1 < n and src[i + 1].isdigit()):
            m = NUMBER_RE.match(src, i)
            toks.append(Tok("num", m.group(0), line))
            i = m.end()
            continue
        m = NAME_RE.match(src, i)
        if m:
            toks.append(Tok("name", m.group(0), line))
            i = m.end()
            continue
        for op in OPERATORS:
            if src.startswith(op, i):
                if op == "{":
                    brace += 1
                elif op == "}":
                    brace -= 1
                    if interp and brace == interp[-1]:
                        interp.pop()
                        toks.append(Tok("op", ")", line))
                        i, line, hole = read_backtick(i + 1, line)
                        if hole:
                            interp.append(brace)
                            brace += 1
                            toks.append(Tok("op", "(", line))
                        break
                toks.append(Tok("op", op, line))
                i += len(op)
                break
        else:
            i += 1  # stray character; ignore
    toks.append(Tok("eof", "", line))
    return toks


# Tokens after which an `if` starts an expression rather than a statement.
EXPR_PREV = {
    "=", "(", ",", "{", "[", "return", "and", "or", "not", "==", "~=", "<", ">", "<=", ">=",
    "+", "-", "*", "/", "//", "%", "^", "..", "#", "+=", "-=", "*=", "/=", "//=", "%=", "^=",
    "..=", "in", "until", "while", "elseif", "if",
}


class Scope:
    __slots__ = ("names", "pending_expr_else", "zombie")

    def __init__(self, names=()):
        self.names = set(names)
        self.pending_expr_else = 0
        self.zombie = False


class Checker:
    def __init__(self, toks):
        self.t = toks
        self.i = 0
        self.scopes = [Scope()]
        self.then_kinds = []  # "expr" / "stmt" for each `if`/`elseif` awaiting its `then`
        self.pending_for = []  # loop variables waiting for their `do`
        self.pending_func = []  # parameters waiting for the function body
        self.expr_tok = set()  # indices of then/else tokens that belong to if-expressions
        self.reads = []  # (name, line) never resolved
        self.global_defs = set()
        self.brackets = []  # open ( { [
        self.problems = []

    # --- helpers -------------------------------------------------------
    def tok(self, k=0):
        j = self.i + k
        return self.t[j] if j < len(self.t) else self.t[-1]

    def is_op(self, text, k=0):
        tk = self.tok(k)
        return tk.kind == "op" and tk.text == text

    def is_name(self, k=0):
        tk = self.tok(k)
        return tk.kind == "name" and tk.text not in KEYWORDS

    def declare(self, name):
        self.scopes[-1].names.add(name)

    def visible(self, name):
        return any(name in s.names for s in self.scopes)

    def pop_zombies(self):
        while len(self.scopes) > 1 and self.scopes[-1].zombie:
            self.scopes.pop()

    def push(self, names=()):
        self.scopes.append(Scope(names))

    def pop(self, what):
        self.pop_zombies()
        if len(self.scopes) > 1:
            self.scopes.pop()
        else:
            self.problems.append(f"line {self.tok().line}: `{what}` with no open block")

    def skip_balanced(self):
        """At an opening bracket; move past its match."""
        pairs = {"(": ")", "{": "}", "[": "]", "<": ">"}
        opener = self.tok().text
        closer = pairs[opener]
        depth = 0
        while self.tok().kind != "eof":
            tk = self.tok()
            if tk.kind == "op":
                if tk.text == opener:
                    depth += 1
                elif tk.text == closer:
                    depth -= 1
                    if depth == 0:
                        self.i += 1
                        return
            self.i += 1

    def skip_type_atom(self):
        if self.is_op("|") or self.is_op("&"):
            self.i += 1
        if self.is_op("..."):
            self.i += 1
        tk = self.tok()
        if tk.kind == "op" and tk.text in "({":
            self.skip_balanced()
        elif tk.kind == "name" and tk.text == "typeof" and self.is_op("(", 1):
            self.i += 1
            self.skip_balanced()
        elif tk.kind == "name":
            self.i += 1
            while self.is_op(".") and self.tok(1).kind == "name":
                self.i += 2
            if self.is_op("<"):
                self.skip_balanced()
            if self.is_op("..."):
                self.i += 1
        elif tk.kind in ("str", "num"):
            self.i += 1

    def skip_type(self):
        self.skip_type_atom()
        while True:
            if self.is_op("?"):
                self.i += 1
            elif self.is_op("|") or self.is_op("&") or self.is_op("->"):
                self.i += 1
                self.skip_type_atom()
            else:
                return

    def skip_attributes(self):
        while self.is_op("@") and self.tok(1).kind == "name":
            self.i += 2
            if self.is_op("["):
                self.skip_balanced()

    def function_params(self, method):
        """At the token after the function name (or after `function`). Reads the
        generic list, parameters and return type; the body scope opens at the end."""
        if self.is_op("<"):
            self.skip_balanced()
        params = {"self"} if method else set()
        if not self.is_op("("):
            return
        self.i += 1
        while self.tok().kind != "eof" and not self.is_op(")"):
            if self.is_name():
                params.add(self.tok().text)
                self.i += 1
                if self.is_op(":"):
                    self.i += 1
                    self.skip_type()
            elif self.is_op("..."):
                self.i += 1
                if self.is_op(":"):
                    self.i += 1
                    self.skip_type()
            else:
                self.i += 1
        self.i += 1  # past `)`
        if self.is_op(":"):
            self.i += 1
            self.skip_type()
        self.push(params)

    # --- main walk -----------------------------------------------------
    def prev_text(self):
        if self.i == 0:
            return None
        return self.t[self.i - 1].text

    def if_is_expr(self):
        prev = self.i - 1
        if prev < 0:
            return False
        ptk = self.t[prev]
        if ptk.kind == "op" or ptk.text in EXPR_PREV:
            return ptk.text in EXPR_PREV
        if ptk.text in ("then", "else"):
            return prev in self.expr_tok
        return False

    def run(self):
        while self.tok().kind != "eof":
            self.step()
        self.pop_zombies()
        if len(self.scopes) != 1:
            self.problems.append(f"{len(self.scopes) - 1} block(s) still open at end of file")

    def step(self):
        tk = self.tok()
        text = tk.text
        if tk.kind == "op":
            if text == "::":
                self.i += 1
                self.skip_type()
                return
            if text == "@":
                self.skip_attributes()
                return
            if text in "({[":
                self.brackets.append(text)
            elif text in ")}]" and self.brackets:
                self.brackets.pop()
            self.i += 1
            return
        if tk.kind != "name":
            self.i += 1
            return

        # contextual keywords at statement start: `type X = ...`, `export type X = ...`
        if text in ("type", "export") and self.statement_start():
            j = 1 if text == "type" else 2
            if (text == "type" or self.tok(1).text == "type") and self.tok(j).kind == "name" and (
                self.is_op("=", j + 1) or self.is_op("<", j + 1)
            ):
                self.i += j + 1
                if self.is_op("<"):
                    self.skip_balanced()
                if self.is_op("="):
                    self.i += 1
                    self.skip_type()
                return

        if text == "local":
            self.i += 1
            self.skip_attributes()
            if self.tok().text == "function":
                self.i += 1
                if self.is_name():
                    self.declare(self.tok().text)
                    self.i += 1
                self.function_params(False)
                return
            while self.is_name():
                self.declare(self.tok().text)
                self.i += 1
                if self.is_op(":"):
                    self.i += 1
                    self.skip_type()
                if self.is_op(","):
                    self.i += 1
                else:
                    break
            return

        if text == "function":
            self.i += 1
            if self.is_name():
                first = self.tok()
                self.read(first.text, first.line, defines=not self.is_op(".", 1) and not self.is_op(":", 1))
                self.i += 1
                method = False
                while (self.is_op(".") or self.is_op(":")) and self.tok(1).kind == "name":
                    method = self.is_op(":")
                    self.i += 2
                self.function_params(method)
            else:
                self.function_params(False)
            return

        if text == "for":
            self.i += 1
            names = set()
            while self.is_name():
                names.add(self.tok().text)
                self.i += 1
                if self.is_op(":"):
                    self.i += 1
                    self.skip_type()
                if self.is_op(","):
                    self.i += 1
                else:
                    break
            self.pending_for.append(names)
            return

        if text == "do":
            self.i += 1
            self.push(self.pending_for.pop() if self.pending_for else ())
            return

        if text == "while":
            self.i += 1
            return

        if text == "repeat":
            self.i += 1
            self.push()
            return

        if text == "until":
            self.pop_zombies()
            if len(self.scopes) > 1:
                self.scopes[-1].zombie = True  # locals stay visible in the condition
            self.i += 1
            return

        if text == "if":
            self.then_kinds.append("expr" if self.if_is_expr() else "stmt")
            self.i += 1
            return

        if text == "then":
            kind = self.then_kinds.pop() if self.then_kinds else "stmt"
            if kind == "expr":
                self.expr_tok.add(self.i)
                self.scopes[-1].pending_expr_else += 1
            else:
                self.push()
            self.i += 1
            return

        if text == "elseif":
            self.pop_zombies()
            if self.scopes[-1].pending_expr_else > 0:
                self.scopes[-1].pending_expr_else -= 1
                self.then_kinds.append("expr")
            else:
                self.pop("elseif")
                self.then_kinds.append("stmt")
            self.i += 1
            return

        if text == "else":
            self.pop_zombies()
            if self.scopes[-1].pending_expr_else > 0:
                self.scopes[-1].pending_expr_else -= 1
                self.expr_tok.add(self.i)
            else:
                self.pop("else")
                self.push()
            self.i += 1
            return

        if text == "end":
            self.pop("end")
            self.i += 1
            return

        if text in KEYWORDS:
            self.i += 1
            return

        # a plain name
        prev = self.t[self.i - 1] if self.i > 0 else None
        if prev is not None and prev.kind == "op" and prev.text in (".", ":"):
            self.i += 1  # field or method name
            return
        if self.is_op("=", 1):
            if self.brackets and self.brackets[-1] == "{":
                self.i += 1  # table constructor key
                return
            # assignment target: a global definition at the top of the file,
            # but inside a block it is almost always a local that went missing
            self.read(text, tk.line, defines=len(self.scopes) == 1)
            self.i += 1
            return
        self.read(text, tk.line, defines=False)
        self.i += 1

    def statement_start(self):
        if self.i == 0:
            return True
        prev = self.t[self.i - 1]
        if prev.kind == "op":
            return prev.text in (")", "]", "}", ";")
        if prev.kind in ("str", "num"):
            return True
        return prev.text in ("end", "then", "do", "else", "repeat", "break", "continue") or (
            prev.kind == "name" and prev.text not in KEYWORDS
        )

    def read(self, name, line, defines):
        if self.visible(name):
            return
        if defines:
            self.global_defs.add(name)
            return
        self.reads.append((name, line))


def check(path: Path):
    src = path.read_text(encoding="utf-8")
    c = Checker(tokenize(src))
    c.run()
    rel = path.relative_to(ROOT).as_posix()
    known = LUAU_GLOBALS | ROBLOX_GLOBALS | c.global_defs | ALLOW.get(rel, set())
    findings = [(name, line) for name, line in c.reads if name not in known]
    return findings, c.problems


def main() -> int:
    targets = sys.argv[1:] or ["src", "tests", "tools"]
    total = 0
    for target in targets:
        base = ROOT / target
        files = sorted(base.rglob("*.luau")) if base.is_dir() else [base]
        for path in files:
            findings, problems = check(path)
            rel = path.relative_to(ROOT).as_posix()
            for p in problems:
                print(f"{rel}: (scope tracking unsure) {p}")
            for name, line in findings:
                print(f"{rel}:{line}: reads `{name}`, which is not declared in any scope that reaches it")
                total += 1
    if total == 0:
        print("no free globals")
        return 0
    print(f"\n{total} read(s) of an undeclared name")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
