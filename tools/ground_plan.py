"""Top-down 2D ground plans of one club plot (playtest item #26).

    python tools/ground_plan.py            # writes docs/ground_plan/*.svg and *.png

Coordinates are plot-local studs, the frame used all over src/server:
origin = pitch centre, +X east (away from the street), -X the street, -Z north.
Drawn with north up and the street on the left. The numbers for `current`
were read straight out of PlotGrounds / WorldBuilder / Clubhouse / Scenery /
MatchdayRoutes on 2026-09-22; if they drift, the code wins.

One script, two outputs: a tiny primitive recorder emits the same drawing as
SVG (for the repo) and PNG via PIL (so it can be eyeballed without a browser).
"""

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent / "docs" / "ground_plan"

# ---------------------------------------------------------------- palette
C = dict(
    lawn="#cfe3b6", street="#6d6f72", pave="#d9d6cc", asphalt="#8f9195",
    turf="#5fae4f", turfline="#eef7e6", hard="#c9c3b3", wall="#4a3b32",
    stand="#8c6a5a", standL4="#b08a78", roof="#7c7f86", seat="#3b5fa8",
    brick="#a0553d", building="#b9a48a", door="#f2c14e", glass="#8fd3f4",
    path="#e9e4d4", hedge="#3f7d3a", tree="#2f6b2f", bed="#7f5a3c",
    route="#d9342b", route2="#e07b1f", mast="#222", text="#1e1e1e",
    ad="#f0e6a8", coach="#2c4c9c", van="#f4f4f4", note="#8a1c1c",
    fence="#7a7a7a", water="#8fbfe0", pub="#7a4a2e", keep="#ff8a80",
)


# ---------------------------------------------------------------- canvas
class Canvas:
    """Records shapes in stud space; renders to SVG or PNG. z is drawn downward."""

    def __init__(self, x0, x1, z0, z1, scale=1.25, title=""):
        self.x0, self.x1, self.z0, self.z1, self.s = x0, x1, z0, z1, scale
        self.ops = []
        self.title = title
        self.W = int((x1 - x0) * scale)
        self.H = int((z1 - z0) * scale)

    # primitives -----------------------------------------------------
    def rect(self, x0, z0, x1, z1, fill=None, stroke=None, sw=1, dash=None, alpha=1.0):
        self.ops.append(("poly", [(x0, z0), (x1, z0), (x1, z1), (x0, z1)], fill, stroke, sw, dash, alpha))

    def poly(self, pts, fill=None, stroke=None, sw=1, dash=None, alpha=1.0):
        self.ops.append(("poly", list(pts), fill, stroke, sw, dash, alpha))

    def line(self, pts, stroke, sw=1, dash=None, arrow=False, alpha=1.0):
        self.ops.append(("line", list(pts), stroke, sw, dash, arrow, alpha))

    def circle(self, x, z, r, fill=None, stroke=None, sw=1):
        self.ops.append(("circle", x, z, r, fill, stroke, sw))

    def text(self, x, z, s, size=9, fill=None, anchor="mm", bold=False, rot=0):
        lines = s.split("\n")
        step = size * 1.2 / self.s                     # line pitch in studs
        z0 = z - step * (len(lines) - 1) / 2
        for i, ln in enumerate(lines):
            self.ops.append(("text", x, z0 + i * step, ln, size, fill or C["text"], anchor, bold, rot))

    # helpers --------------------------------------------------------
    def P(self, x, z):
        return ((x - self.x0) * self.s, (z - self.z0) * self.s)

    # svg ------------------------------------------------------------
    def to_svg(self, path):
        out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.W}" height="{self.H}" '
               f'viewBox="0 0 {self.W} {self.H}" font-family="Segoe UI, Arial, sans-serif">',
               '<defs><marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" '
               'markerHeight="6" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" '
               'fill="context-stroke"/></marker></defs>']
        for op in self.ops:
            if op[0] == "poly":
                _, pts, fill, stroke, sw, dash, alpha = op
                d = " ".join(f"{px:.1f},{py:.1f}" for px, py in (self.P(*p) for p in pts))
                out.append(f'<polygon points="{d}" fill="{fill or "none"}" '
                           f'stroke="{stroke or "none"}" stroke-width="{sw}" '
                           f'{f"stroke-dasharray=\"{dash}\"" if dash else ""} opacity="{alpha}"/>')
            elif op[0] == "line":
                _, pts, stroke, sw, dash, arrow, alpha = op
                d = " ".join(f"{px:.1f},{py:.1f}" for px, py in (self.P(*p) for p in pts))
                out.append(f'<polyline points="{d}" fill="none" stroke="{stroke}" stroke-width="{sw}" '
                           f'stroke-linejoin="round" {f"stroke-dasharray=\"{dash}\"" if dash else ""} '
                           f'{"marker-end=\"url(#arr)\"" if arrow else ""} opacity="{alpha}"/>')
            elif op[0] == "circle":
                _, x, z, r, fill, stroke, sw = op
                px, py = self.P(x, z)
                out.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{r * self.s:.1f}" '
                           f'fill="{fill or "none"}" stroke="{stroke or "none"}" stroke-width="{sw}"/>')
            elif op[0] == "text":
                _, x, z, s, size, fill, anchor, bold, rot = op
                px, py = self.P(x, z)
                ta = {"m": "middle", "l": "start", "r": "end"}[anchor[0]]
                tf = f' transform="rotate({rot} {px:.1f} {py:.1f})"' if rot else ""
                out.append(f'<text x="{px:.1f}" y="{py:.1f}" font-size="{size}" fill="{fill}" '
                           f'text-anchor="{ta}" dominant-baseline="middle" '
                           f'{"font-weight=\"bold\"" if bold else ""}{tf}>{_esc(s)}</text>')
        out.append("</svg>")
        path.write_text("\n".join(out), encoding="utf-8")
        return path

    # png ------------------------------------------------------------
    def to_png(self, path):
        img = Image.new("RGBA", (self.W, self.H), "#eef0e9")
        g = ImageDraw.Draw(img, "RGBA")
        for op in self.ops:
            if op[0] == "poly":
                _, pts, fill, stroke, sw, dash, alpha = op
                xy = [self.P(*p) for p in pts]
                if fill:
                    g.polygon(xy, fill=_rgba(fill, alpha))
                if stroke:
                    _dashed_line(g, xy + [xy[0]], _rgba(stroke, alpha), sw, dash)
            elif op[0] == "line":
                _, pts, stroke, sw, dash, arrow, alpha = op
                xy = [self.P(*p) for p in pts]
                _dashed_line(g, xy, _rgba(stroke, alpha), sw, dash)
                if arrow and len(xy) >= 2:
                    _arrow_head(g, xy[-2], xy[-1], _rgba(stroke, alpha), 4 + sw * 2)
            elif op[0] == "circle":
                _, x, z, r, fill, stroke, sw = op
                px, py = self.P(x, z)
                rr = r * self.s
                g.ellipse((px - rr, py - rr, px + rr, py + rr), fill=fill, outline=stroke, width=int(sw))
            elif op[0] == "text":
                _, x, z, s, size, fill, anchor, bold, rot = op
                px, py = self.P(x, z)
                f = _font(size, bold)
                if rot:
                    tw, th = g.textbbox((0, 0), s, font=f)[2:]
                    tmp = Image.new("RGBA", (tw + 4, th + 4), (0, 0, 0, 0))
                    ImageDraw.Draw(tmp).text((2, 2), s, fill=fill, font=f)
                    tmp = tmp.rotate(-rot, expand=True)
                    img.alpha_composite(tmp, (int(px - tmp.width / 2), int(py - tmp.height / 2)))
                else:
                    g.text((px, py), s, fill=fill, font=f, anchor={"m": "mm", "l": "lm", "r": "rm"}[anchor[0]])
        img.convert("RGB").save(path)
        return path


def _esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def _rgba(hexcol, alpha=1.0):
    h = hexcol.lstrip("#")
    if len(h) == 3:
        h = "".join(ch * 2 for ch in h)
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return (r, g, b, int(255 * alpha))


def _font(size, bold=False):
    names = ("segoeuib.ttf", "arialbd.ttf") if bold else ("segoeui.ttf", "arial.ttf")
    for name in names:
        try:
            return ImageFont.truetype(name, int(size * 1.15))
        except OSError:
            pass
    return ImageFont.load_default()


def _dashed_line(g, xy, colour, width, dash):
    w = max(1, int(round(width)))
    if not dash:
        g.line(xy, fill=colour, width=w, joint="curve")
        return
    on, off = [float(v) for v in str(dash).split(",")[:2]] if "," in str(dash) else (float(dash), float(dash))
    for (ax, ay), (bx, by) in zip(xy, xy[1:]):
        L = math.hypot(bx - ax, by - ay)
        if L == 0:
            continue
        ux, uy = (bx - ax) / L, (by - ay) / L
        t = 0.0
        while t < L:
            e = min(L, t + on)
            g.line([(ax + ux * t, ay + uy * t), (ax + ux * e, ay + uy * e)], fill=colour, width=w)
            t += on + off


def _arrow_head(g, a, b, colour, size):
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    p1 = (b[0] - size * math.cos(ang - 0.5), b[1] - size * math.sin(ang - 0.5))
    p2 = (b[0] - size * math.cos(ang + 0.5), b[1] - size * math.sin(ang + 0.5))
    g.polygon([b, p1, p2], fill=colour)


# ---------------------------------------------------------------- shared pieces
PITCH_W, PITCH_L = 190, 290          # Pitch.luau
TURF_X, TURF_Z = 103, 153            # GRASS_MARGIN 8
SIDE_EDGE, END_EDGE = 121, 179       # hardstanding outer lines
CORNER_Z, CORNER_X = 155, 105        # where side/end walls stop
AD_X, AD_Z = 104.5, 154.5


def draw_pitch(c):
    c.rect(-SIDE_EDGE, -END_EDGE, SIDE_EDGE, END_EDGE, fill=C["hard"])             # paved ring
    c.rect(-TURF_X, -TURF_Z, TURF_X, TURF_Z, fill=C["turf"])                        # turf
    hw, hl = PITCH_W / 2, PITCH_L / 2
    c.rect(-hw, -hl, hw, hl, stroke=C["turfline"], sw=1.2)
    c.line([(-hw, 0), (hw, 0)], C["turfline"], 1.2)
    c.circle(0, 0, 25, stroke=C["turfline"], sw=1.2)
    for sgn in (-1, 1):
        c.rect(-55.5, sgn * hl, 55.5, sgn * (hl - 45), stroke=C["turfline"], sw=1.2)
        c.rect(-25, sgn * hl, 25, sgn * (hl - 15), stroke=C["turfline"], sw=1.2)
        c.rect(-10, sgn * hl, 10, sgn * (hl + 6), fill="#ffffff", stroke="#777", sw=0.8)       # goal + net
    c.text(0, 0, "PITCH 190 × 290", 10, fill="#e8f5e2", bold=True)


def draw_ad_boards(c, west_gaps=True):
    for sgn in (-1, 1):
        zs = [(-153, 153)]
        if west_gaps and sgn < 0:
            zs = [(-153, -55), (-13, 13), (55, 153)]     # tunnel and dugout gaps
        for z0, z1 in zs:
            c.line([(sgn * AD_X, z0), (sgn * AD_X, z1)], C["ad"], 3)
        c.line([(-103, sgn * AD_Z), (103, sgn * AD_Z)], C["ad"], 3)


def draw_floodlight(c, x, z, label=True):
    c.circle(x, z, 3, fill=C["mast"])
    c.line([(x - 5, z - 5), (x + 5, z + 5)], C["mast"], 1.5)
    c.line([(x - 5, z + 5), (x + 5, z - 5)], C["mast"], 1.5)
    if label:
        c.text(x, z - 10, "mast", 7)


def draw_tree(c, x, z, r=6):
    c.circle(x, z, r, fill=C["tree"], stroke="#1e4a1e", sw=0.6)


def draw_hedge(c, a, b, w=3):
    c.line([a, b], C["hedge"], w)


def legend(c, x, z, rows, title):
    lh = 12
    c.rect(x, z, x + 150, z + lh * (len(rows) + 1) + 6, fill="#ffffff", stroke="#999", sw=0.8, alpha=0.92)
    c.text(x + 5, z + 7, title, 9, bold=True, anchor="l")
    for i, (col, label) in enumerate(rows):
        zz = z + lh * (i + 1) + 4
        c.rect(x + 5, zz - 4, x + 15, zz + 4, fill=col, stroke="#555", sw=0.5)
        c.text(x + 19, zz, label, 8, anchor="l")


def frame(c, name, subtitle):
    # street + pavement, plot wall
    c.rect(c.x0, c.z0, c.x1, c.z1, fill="#eef0e9")
    c.rect(-430, -380, -388, 380, fill=C["street"])
    c.text(-409, -300, "street", 9, fill="#eee", rot=-90)
    c.rect(-388, -380, -380, 380, fill=C["pave"])
    c.rect(-380, -380, 380, 380, fill=C["lawn"])
    c.rect(-380, -380, 380, 380, stroke=C["wall"], sw=2.5)
    c.text(0, -399, name, 16, bold=True)
    c.text(0, -387, subtitle, 9)
    # compass + scale bar
    c.line([(360, -320), (360, -360)], C["text"], 1.5, arrow=True)
    c.text(360, -368, "N", 10, bold=True)
    c.line([(230, -350), (330, -350)], C["text"], 2)
    c.text(280, -340, "100 studs (~36 m)", 8)


# ---------------------------------------------------------------- CURRENT
def plan_current():
    c = Canvas(-440, 400, -410, 400, title="current")
    frame(c, "CURRENT GROUND (build 0.1.1)", "as built in code, stands drawn at L2 (solid) with L4 max extent (dashed)")

    # plot gates
    c.rect(-381, -20, -379, -4, fill=C["door"])
    c.text(-395, -12, "ped gate", 7, anchor="r", rot=0)
    c.rect(-381, 60, -379, 100, fill=C["door"])
    c.text(-395, 80, "vehicle gate", 7, anchor="r")
    c.rect(-373, 72, -349, 88, fill=C["asphalt"])                     # access road
    c.circle(-417.5, 40, 4, fill="#f5b400", stroke="#333", sw=0.8)     # bus stop
    c.text(-417.5, 52, "bus stop", 7)

    # border beds
    for z0, z1 in ((-80, -22.5), (-2, 57.5), (102.5, 160)):
        c.rect(-379, z0, -375, z1, fill=C["bed"])

    # training ground
    c.rect(222, -178, 338, 178, stroke=C["fence"], sw=1.2)
    for sgn in (-1, 1):
        c.rect(230, sgn * 10, 330, sgn * 170, fill=C["turf"])
        c.rect(236, sgn * 16, 324, sgn * 164, stroke=C["turfline"], sw=0.8)
    c.rect(221, -6, 223, 6, fill=C["door"])
    c.text(280, -90, "training pitch 1", 8, fill="#e8f5e2")
    c.text(280, 90, "training pitch 2", 8, fill="#e8f5e2")
    c.rect(273, 85, 287, 95, fill=C["building"], stroke=C["wall"], sw=0.8)
    c.text(280, 103, "academy hut", 7)
    draw_hedge(c, (217.5, -178), (217.5, -12), 4)
    draw_hedge(c, (217.5, 12), (217.5, 178), 4)
    for x in (236, 268, 300, 332):
        draw_tree(c, x, -194)
        draw_tree(c, x, 194)
    for z in (-160, -120, -80, -40, 0, 40, 124, 162):
        draw_tree(c, 362, z)

    # car park
    c.rect(-350, 40, -250, 190, fill=C["asphalt"], stroke=C["pave"], sw=1.5)
    for z in range(104, 184, 9):
        c.line([(-349, z), (-331, z)], "#ddd", 0.6)
    for z in range(49, 184, 9):
        c.line([(-307, z), (-271, z)], "#ddd", 0.6)
    c.line([(-289, 49), (-289, 183)], "#ddd", 0.8)
    c.text(-300, 115, "CAR PARK\n100 × 150", 9, fill="#eee", bold=True)
    draw_hedge(c, (-353.5, 36.5), (-250, 36.5), 3)
    draw_hedge(c, (-353.5, 40), (-353.5, 61), 3)
    draw_hedge(c, (-353.5, 114), (-353.5, 193.5), 3)
    draw_hedge(c, (-350, 193.5), (-306, 193.5), 3)
    draw_hedge(c, (-294, 193.5), (-246.5, 193.5), 3)
    draw_hedge(c, (-246.5, 50), (-246.5, 190), 3)

    # paths
    c.rect(-379, -16, -169, -8, fill=C["path"], stroke="#bbb", sw=0.5)      # gate leg → clubhouse
    c.rect(-269, -191, -261, -16, fill=C["path"], stroke="#bbb", sw=0.5)    # north leg
    c.rect(-261, -191, -190, -183, fill=C["path"], stroke="#bbb", sw=0.5)   # east leg → forecourt
    c.rect(-250, 40, -157, 46, fill=C["path"], stroke="#bbb", sw=0.5)       # office path
    c.rect(-287, -146, -269, -136, fill=C["path"], stroke="#bbb", sw=0.5)   # shop apron
    c.rect(-359.5, -30, -355.5, -16, fill=C["path"], stroke="#bbb", sw=0.5) # bar patio path

    # club shop, bar, kiosk
    c.rect(-313, -165, -287, -135, fill=C["building"], stroke=C["wall"], sw=1)
    c.rect(-288, -144, -287, -138, fill=C["door"])
    c.text(-300, -150, "CLUB SHOP", 8, bold=True)
    c.rect(-374, -78, -341, -38, fill=C["pub"], stroke=C["wall"], sw=1)
    c.rect(-374, -38, -341, -30, fill=C["path"], stroke="#bbb", sw=0.5)
    c.text(-357.5, -58, "SUPPORTERS'\nBAR", 8, fill="#fff", bold=True)
    c.rect(-320, 4, -308, 12, fill=C["building"], stroke=C["wall"], sw=0.8)
    c.text(-314, 20, "snack kiosk", 7)
    for x, z in ((-350, -22), (-326, -22), (-302, -22), (-350, -2), (-326, -2), (-302, -2), (-200, -34), (-200, 14),
                 (-226, -62), (-222, 78), (-366, 56), (-368, 116)):
        draw_tree(c, x, z)

    # stadium keep-out (planting) — dashed
    c.rect(-195, -255, 195, 255, stroke=C["keep"], sw=1, dash="4,4")
    c.text(0, -262, "planting keep-out (Stadium rect)", 7, fill=C["note"])

    # pitch, ring, ad boards
    draw_pitch(c)
    draw_ad_boards(c)
    c.rect(-110, 16, -104, 40, fill="#555")
    c.rect(-110, -40, -104, -16, fill="#555")
    c.text(-114, 0, "tunnel", 6, rot=-90)
    c.rect(96, -166, 104, -158, fill="#333")
    c.text(100, -150, "scoreboard", 6)

    # perimeter wall on the ring edge (open NW corner, west break at clubhouse)
    W = C["wall"]
    c.line([(SIDE_EDGE, -CORNER_Z), (SIDE_EDGE, CORNER_Z)], W, 2)
    c.line([(-SIDE_EDGE, 40), (-SIDE_EDGE, CORNER_Z)], W, 2)
    c.line([(-SIDE_EDGE, -CORNER_Z), (-SIDE_EDGE, -40)], W, 2)
    c.line([(-CORNER_X, -END_EDGE), (CORNER_X, -END_EDGE)], W, 2)
    c.line([(-CORNER_X, END_EDGE), (CORNER_X, END_EDGE)], W, 2)
    for sx, sz in ((1, 1), (1, -1), (-1, 1)):
        c.line([(sx * SIDE_EDGE, sz * CORNER_Z), (sx * CORNER_X, sz * END_EDGE)], W, 2)

    # stands: L2 solid, L4 dashed
    def stand(x_in, depth, z0, z1, side, fill, dash=None):
        if side == "E":
            c.rect(x_in, z0, x_in + depth, z1, fill=fill, stroke=C["wall"], sw=0.8, dash=dash)
        elif side == "W":
            c.rect(-x_in - depth, z0, -x_in, z1, fill=fill, stroke=C["wall"], sw=0.8, dash=dash)
        elif side == "N":
            c.rect(z0, -x_in - depth, z1, -x_in, fill=fill, stroke=C["wall"], sw=0.8, dash=dash)
        else:
            c.rect(z0, x_in, z1, x_in + depth, fill=fill, stroke=C["wall"], sw=0.8, dash=dash)

    # L4 outline (roof face)
    stand(SIDE_EDGE, 49.6, -145.5, 145.5, "E", None, "3,3")
    stand(SIDE_EDGE, 49.6, -155, -41, "W", None, "3,3")
    stand(SIDE_EDGE, 49.6, 41, 155, "W", None, "3,3")
    stand(END_EDGE, 49.6, -98.5, 98.5, "N", None, "3,3")
    stand(END_EDGE, 49.6, -98.5, 98.5, "S", None, "3,3")
    # L2 solid
    stand(SIDE_EDGE, 25.6, -102, 102, "E", C["stand"])
    stand(SIDE_EDGE, 25.6, -143, -41, "W", C["stand"])
    stand(SIDE_EDGE, 25.6, 41, 143, "W", C["stand"])
    stand(END_EDGE, 25.6, -69, 69, "N", C["stand"])
    stand(END_EDGE, 25.6, -69, 69, "S", C["stand"])
    c.text(134, 0, "EAST STAND (L2 204 long) — solid brick back, no stairs", 7, fill="#fff", rot=90)
    c.text(-134, -92, "WEST wing", 7, fill="#fff", rot=-90)
    c.text(-134, 92, "WEST wing", 7, fill="#fff", rot=-90)
    c.text(0, -192, "NORTH STAND (L2 138 long)", 7, fill="#fff")
    c.text(0, 192, "SOUTH STAND", 7, fill="#fff")
    c.text(150, -150, "L4 max\nextent", 7, fill=C["note"])

    # clubhouse
    c.rect(-157, -40, -121, 40, fill=C["brick"], stroke=C["wall"], sw=1)
    c.line([(-157, 16), (-121, 16)], C["wall"], 0.6)
    c.line([(-157, -16), (-121, -16)], C["wall"], 0.6)
    c.line([(-148, -16), (-148, 16)], C["wall"], 0.6)
    c.text(-139, 28, "office", 7, fill="#fff")
    c.text(-139, -28, "store", 7, fill="#fff")
    c.text(-152, 0, "lobby", 6, fill="#fff", rot=-90)
    c.text(-135, 10, "home", 6, fill="#fff")
    c.text(-135, -10, "away", 6, fill="#fff")
    c.rect(-157.5, -4, -156.5, 4, fill=C["door"])        # front doors
    c.rect(-121.5, -4, -120.5, 4, fill=C["door"])        # players door
    c.rect(-155, 39.5, -150, 40.5, fill=C["door"])       # office side door
    c.rect(-157.5, -34, -156.5, -26, fill=C["glass"])    # kiosk hatch (west)
    c.text(-172, -30, "concession\nwindow (unused)", 6, anchor="r", fill=C["note"])
    c.rect(-169, -16, -157, 16, fill=C["path"], stroke="#bbb", sw=0.5)      # front apron
    c.rect(-157, 40, -147, 46, fill=C["path"], stroke="#bbb", sw=0.5)       # side apron
    for z in (-35, -29.5, -24, 24, 29.5, 35):
        draw_tree(c, -160, z, 2.5)
    c.text(-139, -50, "CLUBHOUSE 36 × 80", 8, bold=True)

    # turnstiles NW corner
    c.rect(-125.5, -179.3, -118.5, -154.7, fill="#666", stroke=C["wall"], sw=0.8)
    for z in (-174.4, -167, -159.6):
        c.line([(-126, z), (-118, z)], C["door"], 1.5)
    c.text(-112, -167, "turnstiles\n(3 lanes) →\nstraight onto\npitchside", 6, anchor="l", fill=C["note"])
    c.line([(-126.5, -179), (-105, -179)], C["wall"], 2)

    # forecourt + amenity + coach + van
    c.rect(-190, -225, -121, -150, fill=C["pave"], stroke="#bbb", sw=0.6)
    c.text(-155, -235, "FORECOURT (outside the ground)", 7)
    c.rect(-168, -176, -158, -168, fill=C["building"], stroke=C["wall"], sw=0.8)
    c.text(-163, -145, "'concourse' hut / shop / fan zone (L1-3)", 6, fill=C["note"])
    c.rect(-160, -221.25, -126, -212.75, fill=C["coach"])
    c.text(-143, -217, "team coach", 6, fill="#fff")
    c.rect(-180, -217, -172, -201, fill=C["van"], stroke="#888", sw=0.6)
    c.text(-176, -196, "TV van", 6)
    c.circle(-134, -182, 2.5, fill="#999")
    c.text(-134, -188, "statue", 6)

    # floodlights (current positions, far out)
    for sx in (-1, 1):
        for sz in (-1, 1):
            draw_floodlight(c, sx * 187, sz * 245)

    # fan routes
    c.line([(-380, -12), (-265, -12), (-265, -187), (-190, -187), (-121, -167)], C["route"], 2, arrow=True)
    c.line([(-300, 115), (-350, 40), (-265, -12)], C["route2"], 2, dash="6,3", arrow=True)
    c.text(-265, -100, "fans in (from gate)", 7, fill=C["route"], rot=-90)
    c.text(-330, 70, "fans from car park", 7, fill=C["route2"], rot=-45)

    legend(c, 240, 230, [
        (C["turf"], "pitch / training turf"),
        (C["hard"], "pitchside hardstanding"),
        (C["ad"], "ad boards"),
        (C["stand"], "stand (L2)"),
        (C["brick"], "clubhouse"),
        (C["building"], "other buildings"),
        (C["path"], "footpaths"),
        (C["asphalt"], "car park / road"),
        (C["hedge"], "hedge / trees"),
        (C["route"], "fan route in"),
        (C["keep"], "planting keep-out"),
    ], "Current — what stands where")
    return c


# ---------------------------------------------------------------- PROPOSED
# Fixed ground envelope, all tiers. Turnstiles, masts and fan routes never move;
# only the stands, the concourse surface and the catering grow inside it.
ENV_W, ENV_E, ENV_N, ENV_S = -201, 201, -259, 259     # perimeter wall lines (30 behind every L4 back)
CH_W, CH_E, CH_N, CH_S = -157, -121, -40, 40          # clubhouse shell (unchanged)
LOW_X, LOW_Z = 108, 158                               # low wall behind the ad boards (#20)
MAST = [(sx * 140, sz * 200) for sx in (-1, 1) for sz in (-1, 1)]   # #21
TURN_NW, TURN_SW = (-200, -175), (175, 200)           # turnstile blocks in the west wall (z ranges)
PATH_N_Z, PATH_S_Z = -187, 187                        # fan path centrelines to each block
ROUND_Z = 271                                          # walk-round path loop outside the wall
ROUND_E = 212
MAIN_GATE = (-16, 16)                                  # main entrance (players/staff/owner) in the west wall
SERVICE_GATE = (176, 192)                              # groundsman / ambulance gate in the south wall (x range)
COACH_BAY = (-312, 42, -276, 56)                       # #25, north edge of the car park
PUB = (-482, -32, -447, 8)                             # #16, across the street, opposite the ped gate

TIERS = {
    # name, E/W length, N/S length, depth (incl. back wall), lanes per turnstile block, roof
    # cp_z1 = car park south edge (x is always −350…−250, north edge z 40); deck = two-storey south half
    1: dict(name="L1  GRASSROOTS", ew=65, ns=44, depth=9.6, lanes=2, roof=False, cp_z1=120, deck=False),
    2: dict(name="L2  MAIN STAND", ew=204, ns=138, depth=25.6, lanes=3, roof=False, cp_z1=190, deck=False),
    3: dict(name="L3  COVERED GRANDSTAND", ew=291, ns=197, depth=49.6, lanes=5, roof=True, cp_z1=300, deck=False),
    4: dict(name="L4  BOWL WITH CORNER STANDS", ew=291, ns=197, depth=49.6, lanes=6, roof=True, cp_z1=300, deck=True),
}


def proposed_common(c, tier):
    t = TIERS[tier]
    # --- street, pub across the street (#16), ped gate arch
    c.rect(-438, -380, -430, 380, fill=C["pave"])
    c.rect(PUB[0], PUB[1], PUB[2], PUB[3], fill=C["pub"], stroke=C["wall"], sw=1)
    c.rect(PUB[0], PUB[3], PUB[2], PUB[3] + 8, fill=C["path"], stroke="#bbb", sw=0.5)
    c.text((PUB[0] + PUB[2]) / 2, (PUB[1] + PUB[3]) / 2, "SUPPORTERS'\nBAR (town land)", 8, fill="#fff", bold=True)
    c.rect(-381, -20, -379, -4, fill=C["door"])
    c.text(-372, -26, "ped gate + club arch", 7, anchor="l")
    c.rect(-381, 60, -379, 100, fill=C["door"])
    c.text(-395, 80, "vehicle gate", 7, anchor="r")
    c.rect(-373, 72, -349, 88, fill=C["asphalt"])
    c.circle(-417.5, 40, 4, fill="#f5b400", stroke="#333", sw=0.8)
    c.text(-417.5, 52, "bus stop", 7)
    for z0, z1 in ((-80, -22.5), (-2, 57.5), (102.5, 160)):
        c.rect(-379, z0, -375, z1, fill=C["bed"])

    # --- car park grows with the tier (#25 coach bay; east-hedge gap at z 178..196 for the SW fan path)
    z1 = t["cp_z1"]
    gravel = tier == 1
    c.rect(-350, 40, -250, z1, fill="#b9ab8c" if gravel else C["asphalt"], stroke=C["pave"], sw=1.5)
    if not gravel:
        for z in range(104, z1 - 6, 9):
            c.line([(-349, z), (-331, z)], "#ddd", 0.6)
        for z in range(67, z1 - 6, 9):
            c.line([(-307, z), (-271, z)], "#ddd", 0.6)
        c.line([(-289, 67), (-289, z1 - 7)], "#ddd", 0.8)
    if t["deck"]:
        c.rect(-350, 190, -250, z1, fill="#5b5e66", stroke="#ffd54f", sw=1.2)
        c.text(-300, 245, "PARKING DECK\n(2 storeys)", 8, fill="#fff", bold=True)
        c.text(-300, 280, "ramp", 6, fill="#eee")
    sizes = {120: "gravel 100 × 80", 190: "tarmac 100 × 150", 300: "tarmac 100 × 260"}
    c.text(-300, 140, "CAR PARK\n" + sizes[z1], 8, fill="#eee" if not gravel else "#333", bold=True)
    c.rect(*COACH_BAY, fill="#4b4e55" if not gravel else "#a89a7c", stroke="#ffd54f", sw=1, dash="3,2")
    c.rect(COACH_BAY[0] + 2, COACH_BAY[1] + 3, COACH_BAY[2] - 2, COACH_BAY[3] - 3, fill=C["coach"])
    c.text((COACH_BAY[0] + COACH_BAY[2]) / 2, COACH_BAY[1] + 7, "COACH BAY", 6, fill="#fff", bold=True)
    draw_hedge(c, (-353.5, 36.5), (-250, 36.5), 3)
    draw_hedge(c, (-353.5, 40), (-353.5, 61), 3)
    draw_hedge(c, (-353.5, 114), (-353.5, z1 + 3.5), 3)
    draw_hedge(c, (-350, z1 + 3.5), (-306, z1 + 3.5), 3)
    draw_hedge(c, (-294, z1 + 3.5), (-246.5, z1 + 3.5), 3)
    draw_hedge(c, (-246.5, 50), (-246.5, 178), 3)
    if z1 > 196:
        draw_hedge(c, (-246.5, 196), (-246.5, z1), 3)

    # --- paths (#10 #11 #14 #23a)
    P = dict(fill=C["path"], stroke="#bbb", sw=0.5)
    c.rect(-379, -16, -261, -8, **P)                         # gate leg
    c.rect(-269, PATH_N_Z - 4, -261, -8, **P)                # north leg (shop)
    c.rect(-261, PATH_N_Z - 4, ENV_W, PATH_N_Z + 4, **P)     # → NW turnstiles
    c.rect(-261, -16, ENV_W, -8, **P)                        # → main entrance gate
    c.rect(-287, -146, -269, -136, **P)                      # shop apron
    c.rect(-250, PATH_S_Z - 4, ENV_W, PATH_S_Z + 4, **P)     # car park → SW turnstiles
    c.rect(-250, 40, -226, 46, **P)                          # coach bay → #11 link
    c.rect(-234, -8, -226, 46, **P)                          # NEW #11: clubhouse path ↔ car park
    SW_GATE_Z = 308                                           # second street entrance, opens at L3
    c.rect(-234, PATH_S_Z + 4, -226, (SW_GATE_Z + 4 if tier >= 3 else ROUND_Z + 4), **P)   # down to the loop / SW gate
    if tier >= 3:
        c.rect(-379, SW_GATE_Z - 4, -226, SW_GATE_Z + 4, **P)
        c.rect(-381, SW_GATE_Z - 8, -379, SW_GATE_Z + 8, fill=C["door"])
        c.text(-395, SW_GATE_Z, "SW ped gate (L3+)", 7, anchor="r")
        c.line([(-380, SW_GATE_Z), (-230, SW_GATE_Z), (-230, PATH_S_Z + 12), (ENV_W, PATH_S_Z + 12)],
               C["route2"], 2, arrow=True)
    c.rect(-234, ROUND_Z - 4, ROUND_E + 4, ROUND_Z + 4, **P)   # loop south → athletic centre (#23a)
    c.rect(ROUND_E - 4, -ROUND_Z - 4, ROUND_E + 4, ROUND_Z + 4, **P)   # loop east
    c.rect(-234, -ROUND_Z - 4, ROUND_E + 4, -ROUND_Z + 4, **P)         # loop north
    c.rect(-234, PATH_N_Z - 4, -226, -ROUND_Z + 4, **P)      # loop west (north half)
    c.rect(276, 178, 284, ROUND_Z - 4, **P)
    c.rect(ROUND_E, ROUND_Z - 4, 284, ROUND_Z + 4, **P)
    c.rect(276, 16, 284, 178, **P)                           # inside the training fence to the door
    c.rect(-4, ENV_N - 8, 4, -ROUND_Z + 4, **P)              # north exit gate → loop
    c.rect(ENV_E, -4, ROUND_E - 4, 4, **P)                   # east exit gate → loop
    c.text(ROUND_E + 10, -100, "walk-round path (exit loop)", 7, rot=90)

    # --- club shop
    c.rect(-313, -165, -287, -135, fill=C["building"], stroke=C["wall"], sw=1)
    c.rect(-288, -144, -287, -138, fill=C["door"])
    c.text(-300, -150, "CLUB SHOP", 8, bold=True)
    # media bay outside the NW turnstiles (TV van)
    c.rect(-266, -252, -240, -230, fill=C["pave"], stroke="#bbb", sw=0.6)
    c.rect(-262, -245, -244, -237, fill=C["van"], stroke="#888", sw=0.6)
    c.text(-253, -258, "media bay (TV van)", 6)

    # --- training ground + athletic centre (#23)
    if tier == 1:                                            # nothing built here at spawn: for-sale outlines only
        c.rect(222, -178, 338, 178, stroke=C["fence"], sw=1, dash="4,3")
        c.rect(230, -170, 330, -20, stroke=C["hedge"], sw=1, dash="4,3")
        c.rect(230, 20, 330, 170, stroke=C["hedge"], sw=1, dash="4,3")
        c.text(280, -95, "training pitch 1\n(for sale)", 8, fill="#2d5a1e")
        c.text(280, 95, "training pitch 2\n(for sale)", 8, fill="#2d5a1e")
        c.rect(272, -5, 288, 5, stroke=C["wall"], sw=1, dash="3,2")
        c.text(280, -12, "COACH'S CABIN 16 × 10  (buy → hire a coach)", 6, bold=True)
    else:
        c.rect(222, -178, 338, 178, stroke=C["fence"], sw=1.2)
        for sgn in (-1, 1):
            c.rect(230, sgn * 20, 330, sgn * 170, fill=C["turf"])
            c.rect(236, sgn * 26, 324, sgn * 164, stroke=C["turfline"], sw=0.8)
        c.text(280, -95, "training pitch 1", 8, fill="#e8f5e2")
        c.text(280, 95, "training pitch 2", 8, fill="#e8f5e2")
        c.rect(240, -16, 320, 16, fill=C["building"], stroke=C["wall"], sw=1)
        c.rect(279, 15.5, 285, 16.5, fill=C["door"])
        c.text(280, 0, "ATHLETIC CENTRE 80 × 32\n" + ("coach's office · gym · changing" if tier == 2
                                                    else "coach's office · gym · physio · changing"), 7, bold=True)
    c.rect(342, -60, 376, 60, stroke=C["wall"], sw=0.8, dash="3,2")
    c.text(359, 0, "future\nacademy /\nyouth", 6, rot=90)
    c.rect(277, 177, 283, 179, fill=C["door"])
    draw_hedge(c, (217.5, -178), (217.5, -12), 4)
    draw_hedge(c, (217.5, 12), (217.5, 178), 4)
    for x in (236, 268, 300, 332):
        draw_tree(c, x, -194)
        draw_tree(c, x, 194)
    for z in (-160, -120, -80, -40, 0, 40, 124, 162):
        draw_tree(c, 362, z)

    # --- new planting zones (#22): hatched
    def planting(x0, z0, x1, z1, label):
        c.rect(x0, z0, x1, z1, fill="#a8cf8e", stroke=C["hedge"], sw=0.8, dash="3,2")
        c.text((x0 + x1) / 2, (z0 + z1) / 2, label, 7, fill="#1e4a1e")
    planting(-374, -80, -300, -38, "planting (old bar site)")
    planting(-360, -170, -320, -100, "planting")
    planting(-200, -340, 200, -285, "planting belt north")
    planting(-200, 285, 200, 340, "planting belt south")
    if t["cp_z1"] <= 200:
        planting(-374, 210, -260, 300, "planting (car park L3 grows here)")
    planting(-374, 315, -260, 370, "planting")
    planting(230, 200, 340, 260, "planting")
    for z in (-30, -26, -22):                                # flagpoles at the ped gate
        c.circle(-372, z, 1.2, fill="#333")
    c.text(-360, -34, "flagpoles + welcome board", 6, anchor="l")
    for x, z in ((-350, -22), (-326, -22), (-302, -22), (-350, -2), (-326, -2), (-302, -2),
                 (-366, 56), (-368, 116), (-230, -60), (-230, 90), (-300, -230), (-260, 250)):
        draw_tree(c, x, z)

    # --- the ground envelope: perimeter wall, jogging round the clubhouse front
    c.rect(ENV_W, ENV_N, ENV_E, ENV_S, fill="#e4dfd2" if tier >= 2 else "#bfd9a4")
    W = C["wall"]
    c.rect(ENV_W, ENV_N, ENV_E, ENV_S, stroke=W, sw=2.5)
    c.text(ENV_E + 6, -150, "perimeter wall", 7, rot=90)
    c.text(ENV_W - 6, -110, "perimeter wall", 7, rot=-90)
    # gates other than turnstiles
    c.rect(ENV_W - 1.5, MAIN_GATE[0], ENV_W + 1.5, MAIN_GATE[1], fill=C["door"])
    c.text(ENV_W - 4, -22, "MAIN ENTRANCE gate\n(players · staff · owner · directors)", 6, anchor="r")
    c.rect(-20, ENV_N - 1.5, 20, ENV_N + 1.5, fill=C["door"])
    c.text(0, ENV_N - 8, "north exit gate", 6)
    c.rect(ENV_E - 1.5, -20, ENV_E + 1.5, 20, fill=C["door"])
    c.text(ENV_E - 10, 0, "east exit gate", 6, rot=90)
    c.rect(SERVICE_GATE[0], ENV_S - 1.5, SERVICE_GATE[1], ENV_S + 1.5, fill="#ff9800")
    c.text(184, ENV_S + 8, "service gate (tractor / ambulance)", 6)
    # groundsman's compound, SE corner inside the wall
    c.rect(172, 232, 199, 257, fill="#cbb98f", stroke=W, sw=0.8, dash="2,2")
    c.rect(175, 236, 191, 246, fill=C["building"], stroke=W, sw=0.6)
    c.text(185, 252, "groundsman: shed · mower · spare goals", 5)
    # huts by the turnstiles (outside) and inside the NW corner
    c.rect(ENV_W - 22, TURN_NW[0] - 28, ENV_W - 6, TURN_NW[0] - 12, fill=C["building"], stroke=W, sw=0.6)
    c.rect(ENV_W - 22, TURN_SW[1] + 12, ENV_W - 6, TURN_SW[1] + 28, fill=C["building"], stroke=W, sw=0.6)
    c.text(ENV_W - 14, TURN_NW[0] - 20, "ticket\noffice", 5)
    c.text(ENV_W - 14, TURN_SW[1] + 20, "ticket\noffice", 5)
    c.rect(ENV_W - 16, TURN_NW[1] + 10, ENV_W - 6, TURN_NW[1] + 18, fill=C["building"], stroke=W, sw=0.6)
    c.text(ENV_W - 11, TURN_NW[1] + 24, "programmes", 5)
    c.rect(ENV_W - 16, TURN_SW[0] - 18, ENV_W - 6, TURN_SW[0] - 10, fill=C["building"], stroke=W, sw=0.6)
    c.text(ENV_W - 11, TURN_SW[0] - 24, "programmes", 5)
    c.rect(ENV_W + 4, -224, ENV_W + 18, -212, fill="#ffcc80", stroke=W, sw=0.6)
    c.text(ENV_W + 11, -230, "stewards /\ncontrol", 5)
    c.rect(ENV_W + 4, -248, ENV_W + 18, -236, fill="#ef9a9a", stroke=W, sw=0.6)
    c.text(ENV_W + 11, -254, "first aid", 5)
    c.text(ENV_E - 8, ENV_N + 4, "", 5)
    # low wall behind the ad boards (#20)
    lw = "#7b6f62"
    c.line([(LOW_X, -LOW_Z), (LOW_X, LOW_Z), (-LOW_X, LOW_Z), (-LOW_X, 55)], lw, 1.5)
    c.line([(-LOW_X, -55), (-LOW_X, -LOW_Z), (LOW_X, -LOW_Z)], lw, 1.5)
    c.text(LOW_X + 5, 120, "low wall", 6, rot=90)

    # --- turnstile blocks (#15 #14) with exit gates
    for (z0, z1), lbl in ((TURN_NW, "NW turnstiles"), (TURN_SW, "SW turnstiles")):
        c.rect(ENV_W - 4, z0, ENV_W + 4, z1, fill="#666", stroke=W, sw=0.8)
        n = t["lanes"]
        for i in range(n):
            z = z0 + (z1 - z0) * (i + 0.5) / n
            c.line([(ENV_W - 5, z), (ENV_W + 5, z)], C["door"], 1.2)
        c.text(ENV_W - 8, (z0 + z1) / 2, f"{lbl}\n{n} lanes + exit gate", 6, anchor="r")

    # --- clubhouse (front face is on the boundary)
    c.rect(CH_W, CH_N, CH_E, CH_S, fill=C["brick"], stroke=W, sw=1)
    c.line([(CH_W, 16), (CH_E, 16)], W, 0.6)
    c.line([(CH_W, -16), (CH_E, -16)], W, 0.6)
    c.line([(-148, -16), (-148, 16)], W, 0.6)
    c.text(-139, 28, "office", 7, fill="#fff")
    c.text(-139, -28, "store", 7, fill="#fff")
    c.text(-135, 10, "home", 6, fill="#fff")
    c.text(-135, -10, "away", 6, fill="#fff")
    c.rect(CH_W - 0.5, -4, CH_W + 0.5, 4, fill=C["door"])
    c.rect(CH_E - 0.5, -4, CH_E + 0.5, 4, fill=C["door"])
    c.rect(-155, CH_S - 0.5, -150, CH_S + 0.5, fill=C["door"])
    c.text(-146, 48, "staff door → concourse", 6, anchor="l")
    c.rect(ENV_W, -30, CH_W, 30, fill=C["path"], stroke="#bbb", sw=0.5)       # forecourt (inside)
    c.text(-180, -35, "reception forecourt", 6)
    c.circle(-186, 0, 2.5, fill="#999")
    c.text(-186, 7, "statue", 6)
    c.rect(-198, 34, -178, 48, fill="#a8cf8e", stroke=C["hedge"], sw=0.6)
    c.text(-188, 41, "memorial\ngarden", 5, fill="#1e4a1e")
    c.text(-139, -50, "CLUBHOUSE", 8, bold=True)

    # --- pitch, ring, boards, dugouts
    draw_pitch(c)
    draw_ad_boards(c)
    c.rect(-110, 16, -104, 40, fill="#555")
    c.rect(-110, -40, -104, -16, fill="#555")
    if tier < 3:
        c.rect(96, -166, 104, -158, fill="#333")
        c.text(100, -150, "scoreboard", 5)
    else:
        c.rect(120, -248, 160, -240, fill="#111")
        c.text(140, -253, "BIG SCREEN", 6, bold=True)

    # --- car park extras: players'/staff bays, disabled bays, cycle racks
    c.text(-262, 49, "players' & staff bays", 5, anchor="l", fill="#eee")
    c.text(-340, 98, "disabled bays · cycle racks", 5, anchor="l", fill="#eee")

    # --- fan routes (#14 in, #10 out)
    c.line([(-380, -12), (-265, -12), (-265, PATH_N_Z), (ENV_W, PATH_N_Z)], C["route"], 2, arrow=True)
    c.line([(-300, 115), (-255, PATH_S_Z), (ENV_W, PATH_S_Z)], C["route2"], 2, arrow=True)
    c.line([(ENV_W - 2, PATH_N_Z + 8), (-273, PATH_N_Z + 8), (-273, -4), (-380, -4)], C["route"], 1.2, dash="4,3", arrow=True)
    c.line([(ENV_W - 2, PATH_S_Z - 8), (-262, PATH_S_Z - 8), (-262, 120), (-300, 120)], C["route2"], 1.2, dash="4,3", arrow=True)
    c.line([(0, ENV_N), (0, -ROUND_Z), (-230, -ROUND_Z), (-230, PATH_N_Z)], C["route"], 1.2, dash="4,3", arrow=True)
    c.line([(ENV_E, 0), (ROUND_E, 0), (ROUND_E, ROUND_Z), (-230, ROUND_Z), (-230, PATH_S_Z)], C["route2"], 1.2, dash="4,3", arrow=True)
    c.line([(-294, 49), (-234, 43), (-234, -12), (ENV_W, -12)], "#2c4c9c", 1.5, dash="2,2", arrow=True)
    c.text(-234, 20, "players: coach → main gate", 5, fill="#2c4c9c", rot=-90)
    c.text(-273, -100, "fans in / out (gate)", 7, fill=C["route"], rot=-90)
    c.text(-262, 100, "fans in / out (car park)", 7, fill=C["route2"], rot=90)


def stand_rects(tier):
    """Solid stand footprints per side: list of (poly, side)."""
    t = TIERS[tier]
    d = t["depth"]
    ew, ns = t["ew"] / 2, t["ns"] / 2
    out = []
    out.append(("E", [(SIDE_EDGE, -ew), (SIDE_EDGE + d, -ew), (SIDE_EDGE + d, ew), (SIDE_EDGE, ew)]))
    for sgn in (-1, 1):                                     # west wings run outward from the clubhouse gap, clamp 155
        z0, z1 = 41, min(41 + ew, 155)
        out.append(("W", [(-SIDE_EDGE, sgn * z0), (-SIDE_EDGE - d, sgn * z0), (-SIDE_EDGE - d, sgn * z1), (-SIDE_EDGE, sgn * z1)]))
    for sgn in (-1, 1):
        out.append(("NS", [(-ns, sgn * END_EDGE), (-ns, sgn * (END_EDGE + d)), (ns, sgn * (END_EDGE + d)), (ns, sgn * END_EDGE)]))
    return out


def plan_proposed(tier):
    t = TIERS[tier]
    c = Canvas(-500, 400, -410, 400, title=f"L{tier}")
    frame(c, f"PROPOSED — {t['name']}", "fixed envelope x ±201, z ±259 (30 studs behind every L4 stand back); same gates, masts and routes at every tier")
    c.rect(-438, -380, -430, 380, fill=C["pave"])
    proposed_common(c, tier)
    d = t["depth"]
    fill = C["standL4"] if t["roof"] else C["stand"]

    # stands + end stairs (#13 #15) + vomitories (L3+)
    for side, poly in stand_rects(tier):
        if tier == 1 and side != "E":                        # only the East stand starts built (Config.StandPlots)
            c.poly(poly, stroke=C["wall"], sw=0.8, dash="3,2")
            continue
        c.poly(poly, fill=fill, stroke=C["wall"], sw=0.8)
        if t["roof"]:
            c.poly(poly, stroke=C["roof"], sw=2, dash="2,2")
        xs, zs = [p[0] for p in poly], [p[1] for p in poly]
        x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
        st = "#ffe082"
        if side in ("E", "W"):
            for z in (z0, z1):
                zz = (z - 6, z) if z == z0 else (z, z + 6)
                c.rect(x0 if side == "E" else x1 - min(d, 12), zz[0], (x0 + min(d, 12)) if side == "E" else x1, zz[1], fill=st, stroke="#555", sw=0.5)
        else:
            for x in (x0, x1):
                xx = (x - 6, x) if x == x0 else (x, x + 6)
                c.rect(xx[0], z0 if z0 > 0 else z1 - min(d, 12), xx[1], (z0 + min(d, 12)) if z0 > 0 else z1, fill=st, stroke="#555", sw=0.5)
        if tier >= 2:                                        # rear gates (L2) / vomitories (L3+) in the back wall
            if side == "E":
                for z in (-70, 70):
                    c.rect(x1 - 6, z - 3, x1 + 1, z + 3, fill="#222")
                for z in (z0, z1):                           # disabled viewing platforms at the front ends
                    c.rect(x0 - 3, z - (10 if z > 0 else 0), x0, z + (10 if z < 0 else 0), fill="#7fb3c9")
            elif side == "W":
                zc = (z0 + z1) / 2
                c.rect(x0 - 1, zc - 3, x0 + 6, zc + 3, fill="#222")
            else:
                for x in (-40, 40):
                    zz = (z1 - 6, z1 + 1) if z0 > 0 else (z0 - 1, z0 + 6)
                    c.rect(x - 3, zz[0], x + 3, zz[1], fill="#222")
        if tier >= 3:                                        # catering under the stand (dashed)
            c.rect(x0 + 2, z0 + 2, x1 - 2, z1 - 2, stroke="#fff", sw=0.6, dash="2,2")
    # press / TV gantry on the east stand
    if tier == 2:
        c.rect(SIDE_EDGE + d - 6, -8, SIDE_EDGE + d + 1, 8, fill="#546e7a")
        c.text(SIDE_EDGE + d + 12, 0, "TV gantry", 6, rot=90)
    elif tier >= 3:
        c.rect(SIDE_EDGE + 20, -12, SIDE_EDGE + 36, 12, fill="#546e7a", alpha=0.85)
        c.text(SIDE_EDGE + 28, 0, "press box\n+ camera", 5, fill="#fff")
    c.text(121 + d / 2, 0, f"EAST {t['ew']} long", 7, fill="#fff", rot=90)
    lab = "#fff" if tier > 1 else "#444"
    c.text(0, -END_EDGE - d / 2, f"NORTH {t['ns']} long" + (" (not built yet)" if tier == 1 else ""), 7, fill=lab)
    c.text(0, END_EDGE + d / 2, f"SOUTH {t['ns']} long" + (" (not built yet)" if tier == 1 else ""), 7, fill=lab)
    if tier == 1:
        c.text(-139, -60, "store → Football Ops\n(scouting) room at L2", 6, fill=C["note"])

    # corner stands (L4)
    if tier >= 4:
        ew, ns = t["ew"] / 2, t["ns"] / 2
        for sx in (-1, 1):
            for sz in (-1, 1):
                e_end = min(ew, 155) if sx < 0 else ew
                poly = [(sx * SIDE_EDGE, sz * e_end), (sx * SIDE_EDGE, sz * CORNER_Z), (sx * CORNER_X, sz * END_EDGE),
                        (sx * ns, sz * END_EDGE), (sx * ns, sz * (END_EDGE + d)), (sx * (SIDE_EDGE + d), sz * (END_EDGE + d)),
                        (sx * (SIDE_EDGE + d), sz * e_end)]
                c.poly(poly, fill="#c49a86", stroke=C["wall"], sw=0.8)
                c.poly(poly, stroke=C["roof"], sw=2, dash="2,2")
                c.text(sx * 140, sz * 195, "corner\nstand", 7, fill="#fff")
        c.rect(121, 90, 121 + d, 145.5, fill="#e0b040", alpha=0.55)
        c.text(121 + d / 2, 118, "AWAY", 7, bold=True, rot=90)

    # stand over the clubhouse (#5) at L3+
    if tier >= 3:
        xb = -SIDE_EDGE - d
        c.rect(xb, -41, CH_E, 41, fill=C["standL4"], stroke=C["wall"], sw=0.8, alpha=0.7)
        c.poly([(xb, -41), (CH_E, -41), (CH_E, 41), (xb, 41)], stroke=C["roof"], sw=2, dash="2,2")
        c.text((xb + CH_E) / 2, 0, "stand over\nclubhouse", 7, fill="#fff", bold=True)
        if tier == 3:
            c.rect(121, 100, 121 + d, 145.5, stroke="#e0b040", sw=1.5, dash="3,2")
            c.text(121 + d + 8, 122, "future away\nsection", 6, anchor="l", fill="#8a6000")

    # concourse contents per tier (#7)
    if tier == 1:
        c.text(-150, -120, "grass inside the fence\n+ gravel strip", 7, fill="#2d5a1e")
        c.rect(-160, -110, -146, -100, fill=C["van"], stroke="#888", sw=0.6)
        c.text(-153, -94, "burger van", 6)
        c.rect(-160, 100, -148, 112, fill="#7fb3c9", stroke="#555", sw=0.6)
        c.text(-154, 118, "portaloos", 6)
    elif tier == 2:
        for (x, z, lbl) in ((0, -232, "kiosk"), (0, 232, "kiosk"), (188, -60, "kiosk"), (188, 60, "kiosk"),
                            (-185, -110, "kiosk"), (-185, 110, "kiosk")):
            c.rect(x - 7, z - 5, x + 7, z + 5, fill=C["building"], stroke=C["wall"], sw=0.6)
            c.text(x, z, lbl, 6)
    else:
        c.rect(-198, -150, -176, -70, fill="#f6e7b2", stroke="#bbb", sw=0.6)
        c.text(-187, -110, "fan zone\npicnic\nbenches", 5)
    if tier >= 2:
        for (x, z) in ((186, -222), (-170, 250), (60, 250), (-60, -250)):
            c.rect(x - 9, z - 6, x + 9, z + 6, fill="#7fb3c9", stroke="#555", sw=0.6)
            c.text(x, z, "toilets", 6)

    # masts
    for x, z in MAST:
        draw_floodlight(c, x, z, label=(tier < 4))
    if tier >= 4:
        c.text(140, 215, "masts rise\nfrom corner roofs", 6)

    # planting keep-out reminder = the envelope
    legend(c, 240, 230, [
        (C["turf"], "pitch / training turf"),
        (C["hard"], "hardstanding (inside low wall)"),
        (C["ad"], "ad boards"),
        ("#7b6f62", "low wall (#20)"),
        (fill, "stand"),
        ("#ffe082", "end stairs (#13/#15)"),
        ("#222", "vomitory (L3+)"),
        (C["brick"], "clubhouse"),
        (C["path"], "footpaths"),
        (C["route"], "fan route in / out"),
        (C["hedge"], "hedge / trees / new planting"),
    ], f"Proposed L{tier}")
    return c


PLANS = {
    "current": plan_current,
    "proposed_L1": lambda: plan_proposed(1),
    "proposed_L2": lambda: plan_proposed(2),
    "proposed_L3": lambda: plan_proposed(3),
    "proposed_L4": lambda: plan_proposed(4),
}


def main(names=None):
    OUT.mkdir(parents=True, exist_ok=True)
    for name in names or PLANS:
        c = PLANS[name]()
        c.to_svg(OUT / f"{name}.svg")
        c.to_png(OUT / f"{name}.png")
        print(OUT / f"{name}.svg")


if __name__ == "__main__":
    main(sys.argv[1:] or None)
