"""Studio/disk parity check (X304).

Twice tonight a Studio copy of a script drifted from disk in a way the tests
could not see: X284 (AmbientAudio had the X281 call but not its `require`) and
the HUD's missing top-level `TextService`, which killed the season card. Both
were only found by reading the output window after a playtest.

Rojo would make this impossible (X4/X34, blocked on Marcel reconnecting the
plugin), so until then this compares every script on disk with the one in
Studio, ignoring comments and all whitespace - Studio's copies are condensed
and have their comments stripped, so only the code can be compared.

Usage:
    python tools/studio_parity.py            # writes the Luau probe
    python tools/studio_parity.py --print    # also prints it

Then run the printed file's contents through the Studio MCP (Edit datamodel).
It prints "parity: N scripts, all match" or one line per script that differs.
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(os.environ.get("TEMP", "/tmp"), "fx", "parity.lua")

# Where each disk folder lives in the data model. `src/client/*.client.luau`
# are LocalScripts and the rest are modules, but the path is the same either
# way, so only the folder matters.
ROOTS = [
    ("src/shared", "game.ReplicatedStorage.Shared"),
    ("src/server", "game.ServerScriptService.Server"),
    ("src/client", "game.StarterPlayer.StarterPlayerScripts.Client"),
    ("tests", "game.ServerStorage.Tests"),
]


def studio_name(filename: str) -> str:
    """Main.server.luau -> Main, AmbientAudio.client.luau -> AmbientAudio."""
    name = filename[: -len(".luau")]
    for suffix in (".server", ".client"):
        if name.endswith(suffix):
            name = name[: -len(suffix)]
    return name


def strip(source: str) -> str:
    """Code only: no comments, no whitespace. Quote-aware, so a `--` inside a
    string is kept (and a comment inside a string is not stripped twice)."""
    out = []
    i, n = 0, len(source)
    quote = None  # "'", '"' or the closing bracket of a long string
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
        if c == "-" and source.startswith("--", i):
            # a comment: long form first, then to end of line
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
                    continue
            end = source.find("\n", i)
            i = n if end == -1 else end
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
        if not c.isspace():
            out.append(c)
        i += 1
    return "".join(out)


def fnv1a(text: str) -> int:
    """32-bit FNV-1a over the UTF-8 bytes. Mirrored in the Luau probe."""
    h = 2166136261
    for b in text.encode("utf-8"):
        h = ((h ^ b) * 16777619) & 0xFFFFFFFF
    return h


def wanted() -> "set[str] | None":
    """`--git <rev>` limits the check to scripts changed since <rev>, which keeps
    the probe small enough to paste when only tonight's work matters."""
    if "--git" not in sys.argv:
        return None
    rev = sys.argv[sys.argv.index("--git") + 1]
    import subprocess

    out = subprocess.run(
        ["git", "diff", "--name-only", rev],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return {line.strip().replace("\\", "/") for line in out.splitlines() if line.strip()}


def main() -> int:
    only = wanted()
    rows = []
    for folder, path in ROOTS:
        directory = os.path.join(ROOT, folder)
        if not os.path.isdir(directory):
            continue
        for filename in sorted(os.listdir(directory)):
            if not filename.endswith(".luau"):
                continue
            if only is not None and ("%s/%s" % (folder, filename)) not in only:
                continue
            with open(os.path.join(directory, filename), encoding="utf-8") as f:
                source = f.read()
            code = strip(source)
            # Lua's `#s` counts bytes, so compare bytes: this codebase is full of
            # em dashes, pounds and middots
            blob = code.encode("utf-8")
            rows.append((("%s.%s" % (path, studio_name(filename))), fnv1a(code), len(blob)))

    lines = [
        "-- generated by tools/studio_parity.py (X304); run in the Edit datamodel",
        "local want = {",
    ]
    for path, digest, size in rows:
        lines.append('\t{ "%s", %d, %d },' % (path, digest, size))
    lines.append("}")
    lines.append(
        r"""
local function strip(source)
	local out, i, n = {}, 1, #source
	local quote = nil
	while i <= n do
		local c = string.sub(source, i, i)
		if quote then
			table.insert(out, c)
			if quote == "'" or quote == '"' then
				if c == "\\" then
					table.insert(out, string.sub(source, i + 1, i + 1))
					i += 2
					continue
				elseif c == quote then
					quote = nil
				end
			elseif string.sub(source, i, i + #quote - 1) == quote then
				table.insert(out, string.sub(source, i + 1, i + #quote - 1))
				i += #quote
				quote = nil
				continue
			end
			i += 1
			continue
		end
		if string.sub(source, i, i + 1) == "--" then
			local j = i + 2
			if string.sub(source, j, j) == "[" then
				local level = 0
				local k = j + 1
				while string.sub(source, k, k) == "=" do
					level += 1
					k += 1
				end
				if string.sub(source, k, k) == "[" then
					local close = "]" .. string.rep("=", level) .. "]"
					local a = string.find(source, close, k, true)
					i = if a then a + #close else n + 1
					continue
				end
			end
			local a = string.find(source, "\n", i, true)
			i = if a then a else n + 1
			continue
		end
		if c == "'" or c == '"' then
			table.insert(out, c)
			quote = c
			i += 1
			continue
		end
		if c == "[" then
			local level = 0
			local k = i + 1
			while string.sub(source, k, k) == "=" do
				level += 1
				k += 1
			end
			if string.sub(source, k, k) == "[" then
				table.insert(out, string.sub(source, i, k))
				quote = "]" .. string.rep("=", level) .. "]"
				i = k + 1
				continue
			end
		end
		if not string.match(c, "%s") then
			table.insert(out, c)
		end
		i += 1
	end
	return table.concat(out)
end

-- 16-bit halves: h * 16777619 overflows a double's 53 bits of integer, which
-- silently made every hash disagree the first time this ran
local function mul32(a, b)
	local a0, a1 = a % 65536, math.floor(a / 65536)
	local b0, b1 = b % 65536, math.floor(b / 65536)
	return (a0 * b0 + ((a0 * b1 + a1 * b0) % 65536) * 65536) % 4294967296
end

local function fnv1a(text)
	local h = 2166136261
	for i = 1, #text do
		h = mul32(bit32.bxor(h, string.byte(text, i)), 16777619)
	end
	return h
end

local function resolve(path)
	local node = game
	for name in string.gmatch(string.sub(path, 6), "[^%.]+") do
		node = node:FindFirstChild(name)
		if not node then
			return nil
		end
	end
	return node
end

local bad = {}
for _, row in want do
	local path, digest, size = row[1], row[2], row[3]
	local inst = resolve(path)
	if not inst then
		table.insert(bad, "MISSING " .. path)
	else
		local code = strip(inst.Source)
		local mine = fnv1a(code)
		if mine ~= digest then
			table.insert(bad, string.format("DIFFERS %s (studio %d chars, disk %d)", path, #code, size))
		end
	end
end
if #bad == 0 then
	return string.format("parity: %d scripts, all match", #want)
end
return string.format("parity: %d scripts, %d differ\n%s", #want, #bad, table.concat(bad, "\n"))"""
    )
    probe = "\n".join(lines)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(probe)
    print("%d scripts -> %s" % (len(rows), OUT))
    if "--print" in sys.argv:
        print(probe)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
