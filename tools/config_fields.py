#!/usr/bin/env python3
"""Every Config field the code reads must exist in Config (found the hard way).

At 00:18 an edit to the X350 comment block in `src/shared/Config.luau` replaced
a slice of the file that happened to contain four unrelated constants -
`MerchPopularityShare`, `ResaleShare`, `ResaleSettled`, `ResaleAppearances` -
and nothing noticed, because RunAll compiles Studio's copies (known bug 4) and
those still had them. On disk, `Economy.merchRevenue` and `Squad.value` would
have thrown "attempt to perform arithmetic on nil" on every matchday and every
player card.

This is the cheap guard: collect every `Config.<name> =` definition, then every
`Config.<name>` read across src/ and tests/, and report the difference.
Functions (`function Config.foo`) and exported types count as definitions.

    python tools/config_fields.py        # exit 1 if anything is read but not defined
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONFIG = ROOT / "src" / "shared" / "Config.luau"
FOLDERS = ("src/shared", "src/server", "src/client", "tests")

DEFINE = re.compile(r"^Config\.([A-Za-z_][A-Za-z0-9_]*)\s*=", re.M)
FUNCTION = re.compile(r"^function Config\.([A-Za-z_][A-Za-z0-9_]*)", re.M)
EXPORT = re.compile(r"^export type ([A-Za-z_][A-Za-z0-9_]*)", re.M)
READ = re.compile(r"\bConfig\.([A-Za-z_][A-Za-z0-9_]*)")


def main() -> int:
    config = CONFIG.read_text(encoding="utf-8")
    defined = set(DEFINE.findall(config)) | set(FUNCTION.findall(config)) | set(EXPORT.findall(config))

    missing: "dict[str, list[str]]" = {}
    for folder in FOLDERS:
        base = ROOT / folder
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*.luau")):
            text = path.read_text(encoding="utf-8")
            for name in sorted(set(READ.findall(text))):
                if name not in defined:
                    missing.setdefault(name, []).append(path.relative_to(ROOT).as_posix())

    if not missing:
        print("every Config field that is read is defined (%d fields)" % len(defined))
        return 0
    for name, files in sorted(missing.items()):
        print("Config.%s is read but never defined: %s" % (name, ", ".join(files)))
    print("\n%d missing Config field(s)" % len(missing))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
