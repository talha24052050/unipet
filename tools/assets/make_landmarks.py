"""Simge binalar için low-poly süs modelleri (GLB) üretir. Saf Python, bağımlılık yok.

Kullanım:  python tools/assets/make_landmarks.py
Girdi : game/data/zones/kampus_greybox.json (OSM ayak izleri) + tools/assets/landmarks.json (tarifler)
Çıktı : game/assets/buildings/<id>.glb + game/data/landmarks.json (bina adı -> glb yolu)

Not: Blender bu makinede Smart App Control yüzünden çalışmıyor (imzasız ffmpeg DLL'i); geometri
basit olduğundan GLB doğrudan yazılıyor. Modeller sahne (Godot) koordinatlarında, Y yukarı.
Duvarlar/kapılar/çarpışma Godot'ta kalır; burada sadece kapı yüksekliğinin üstündeki süsler var
(korniş, kat silmesi, parapet, çatı üniteleri, baca, kubbe, minare, tente).
"""
import json
import math
import os
import random
import struct

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

GATE_CLEAR = 4.4  # Godot GATE_HEIGHT 3.2 + kiriş; bunun altına süs koyma
FLOOR_H = 3.5
CORNICE_OUT = 0.4
CORNICE_H = 0.55
LEDGE_OUT = 0.18
LEDGE_H = 0.22
PARAPET_IN = 0.3
PARAPET_H = 0.9
MAX_TRIS = 2000
EPS = 0.02

COLORS = {
    "trim": (0.93, 0.88, 0.78),
    "stone": (0.80, 0.72, 0.58),
    "roof_unit": (0.55, 0.57, 0.60),
    "dark": (0.25, 0.27, 0.30),
    "dome": (0.42, 0.50, 0.58),
    "white": (0.95, 0.95, 0.93),
    "brick": (0.62, 0.30, 0.22),
    "awning": (0.85, 0.35, 0.20),
}


# ---------- 2B yardımcılar (XZ düzlemi) ----------
def signed_area(p):
    return 0.5 * sum(p[i][0] * p[(i + 1) % len(p)][1] - p[(i + 1) % len(p)][0] * p[i][1] for i in range(len(p)))


def clean(p):
    out = []
    for q in p:
        if not out or math.dist(out[-1], q) > 0.05:
            out.append(q)
    if len(out) > 2 and math.dist(out[0], out[-1]) < 0.05:
        out.pop()
    return out


def edge_normal(a, b, ccw):
    dx, dz = b[0] - a[0], b[1] - a[1]
    l = math.hypot(dx, dz) or 1.0
    return (dz / l, -dx / l) if ccw else (-dz / l, dx / l)


def offset(p, d):
    """Çokgeni d kadar dışa (d<0: içe) kaydırır; miter, keskin köşede sınırlı."""
    ccw = signed_area(p) > 0
    n = len(p)
    out = []
    for i in range(n):
        a, b, c = p[i - 1], p[i], p[(i + 1) % n]
        n1, n2 = edge_normal(a, b, ccw), edge_normal(b, c, ccw)
        m = (n1[0] + n2[0], n1[1] + n2[1])
        ml = math.hypot(*m)
        m = n1 if ml < 1e-6 else (m[0] / ml, m[1] / ml)
        cosh = max(0.35, m[0] * n1[0] + m[1] * n1[1])
        out.append((b[0] + m[0] * d / cosh, b[1] + m[1] * d / cosh))
    return out


def inside(pt, poly):
    x, z = pt
    c = False
    n = len(poly)
    for i in range(n):
        x1, z1 = poly[i]
        x2, z2 = poly[(i + 1) % n]
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
            c = not c
    return c


def interior_points(poly, margin, count, rng):
    xs, zs = [q[0] for q in poly], [q[1] for q in poly]
    pts = []
    for _ in range(4000):
        if len(pts) >= count:
            break
        q = (rng.uniform(min(xs), max(xs)), rng.uniform(min(zs), max(zs)))
        if any(math.dist(q, s) < margin for s in pts):
            continue
        if all(inside((q[0] + dx, q[1] + dz), poly) for dx, dz in ((0, 0), (margin, 0), (-margin, 0), (0, margin), (0, -margin))):
            pts.append(q)
    return pts


def seg_closest(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    l2 = dx * dx + dz * dz or 1e-9
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / l2))
    return (a[0] + dx * t, a[1] + dz * t)


def centroid(poly):
    a = signed_area(poly)
    cx = cz = 0.0
    for i in range(len(poly)):
        x1, z1 = poly[i]
        x2, z2 = poly[(i + 1) % len(poly)]
        f = x1 * z2 - x2 * z1
        cx += (x1 + x2) * f
        cz += (z1 + z2) * f
    return (cx / (6 * a), cz / (6 * a))


# ---------- 3B ----------
def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(v):
    l = math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2) or 1.0
    return (v[0] / l, v[1] / l, v[2] / l)


class Builder:
    """Kapalı katılar ekler; her yüzün yönü, katının 'içinde mi' testiyle dışa çevrilir (düz gölgeleme)."""

    def __init__(self):
        self.tris = {}  # renk -> [(p0, p1, p2, n)]

    def _add_faces(self, color, faces, is_inside, center=None):
        out = self.tris.setdefault(color, [])
        for f in faces:
            for k in range(1, len(f) - 1):
                a, b, c = f[0], f[k], f[k + 1]
                n = cross(sub(b, a), sub(c, a))
                if n == (0.0, 0.0, 0.0) or max(abs(x) for x in n) < 1e-9:
                    continue
                n = norm(n)
                cen = ((a[0] + b[0] + c[0]) / 3, (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3)
                probe = (cen[0] + n[0] * EPS, cen[1] + n[1] * EPS, cen[2] + n[2] * EPS)
                flip = is_inside(probe) if center is None else (n[0] * (cen[0] - center[0]) + n[1] * (cen[1] - center[1]) + n[2] * (cen[2] - center[2])) < 0
                if flip:
                    b, c = c, b
                    n = (-n[0], -n[1], -n[2])
                out.append((a, b, c, n))

    def ring(self, outer, inner, y0, y1, color):
        n = len(outer)
        layers = [[(q[0], y, q[1]) for q in pts] for pts, y in ((outer, y0), (outer, y1), (inner, y1), (inner, y0))]
        faces = []
        for i in range(n):
            j = (i + 1) % n
            for r in range(4):
                r2 = (r + 1) % 4
                faces.append([layers[r][i], layers[r][j], layers[r2][j], layers[r2][i]])
        self._add_faces(color, faces, lambda p: y0 < p[1] < y1 and inside((p[0], p[2]), outer) and not inside((p[0], p[2]), inner))

    def prism(self, poly, y0, y1, color, apex=None):
        n = len(poly)
        bot = [(q[0], y0, q[1]) for q in poly]
        faces = [list(reversed(bot))]
        if apex is None:
            top = [(q[0], y1, q[1]) for q in poly]
            faces.append(top)
            faces += [[bot[i], bot[(i + 1) % n], top[(i + 1) % n], top[i]] for i in range(n)]
            test = lambda p: y0 < p[1] < y1 and inside((p[0], p[2]), poly)
        else:
            c = (sum(q[0] for q in poly) / n, sum(q[1] for q in poly) / n)
            ap = (c[0], apex, c[1])
            faces += [[bot[i], bot[(i + 1) % n], ap] for i in range(n)]

            def test(p):
                if not y0 < p[1] < apex:
                    return False
                s = 1.0 - (p[1] - y0) / (apex - y0)
                return inside((c[0] + (p[0] - c[0]) / max(s, 1e-6), c[1] + (p[2] - c[1]) / max(s, 1e-6)), poly)
        self._add_faces(color, faces, test)

    def box(self, cx, cz, w, d, y0, y1, color, yaw=0.0):
        cs, sn = math.cos(yaw), math.sin(yaw)
        pts = [(cx + x * cs - z * sn, cz + x * sn + z * cs) for x, z in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2))]
        self.prism(pts, y0, y1, color)

    def cylinder(self, cx, cz, r, y0, y1, color, seg=8, cone=False):
        pts = [(cx + r * math.cos(2 * math.pi * i / seg), cz + r * math.sin(2 * math.pi * i / seg)) for i in range(seg)]
        self.prism(pts, y0, y1, color, apex=y1 if cone else None)

    def dome(self, cx, cz, r, y0, color, seg=10, rings=4):
        rows = []
        for k in range(rings):
            a = (math.pi / 2) * k / rings
            rows.append([(cx + r * math.cos(a) * math.cos(2 * math.pi * i / seg), y0 + r * math.sin(a),
                          cz + r * math.cos(a) * math.sin(2 * math.pi * i / seg)) for i in range(seg)])
        top = (cx, y0 + r, cz)
        faces = [list(reversed(rows[0]))]
        for k in range(rings - 1):
            faces += [[rows[k][i], rows[k][(i + 1) % seg], rows[k + 1][(i + 1) % seg], rows[k + 1][i]] for i in range(seg)]
        faces += [[rows[-1][i], rows[-1][(i + 1) % seg], top] for i in range(seg)]
        # Dışbükey: yüzleri kubbe içindeki bir noktadan uzağa çevir
        self._add_faces(color, faces, None, center=(cx, y0 + r * 0.3, cz))

    def tri_count(self):
        return sum(len(v) for v in self.tris.values())


# ---------- GLB yazıcı ----------
def write_glb(path, name, builder):
    blob = bytearray()
    accessors, views, prims, mats = [], [], [], []

    def add_view(data, target):
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), "target": target})
        blob.extend(data)
        return len(views) - 1

    for color, tris in builder.tris.items():
        if not tris:
            continue
        pos, nrm = [], []
        for a, b, c, n in tris:
            for p in (a, b, c):
                pos.append(p)
                nrm.append(n)
        pv = add_view(b"".join(struct.pack("<3f", *p) for p in pos), 34962)
        nv = add_view(b"".join(struct.pack("<3f", *n) for n in nrm), 34962)
        mn = [min(p[i] for p in pos) for i in range(3)]
        mx = [max(p[i] for p in pos) for i in range(3)]
        accessors.append({"bufferView": pv, "componentType": 5126, "count": len(pos), "type": "VEC3", "min": mn, "max": mx})
        accessors.append({"bufferView": nv, "componentType": 5126, "count": len(nrm), "type": "VEC3"})
        r, g, b = COLORS[color]
        mats.append({"name": "lm_" + color, "pbrMetallicRoughness": {
            "baseColorFactor": [r ** 2.2, g ** 2.2, b ** 2.2, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.9}})
        prims.append({"attributes": {"POSITION": len(accessors) - 2, "NORMAL": len(accessors) - 1}, "material": len(mats) - 1})
    while len(blob) % 4:
        blob.append(0)
    gltf = {
        "asset": {"version": "2.0", "generator": "unipet make_landmarks.py"},
        "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": prims}], "materials": mats,
        "accessors": accessors, "bufferViews": views, "buffers": [{"byteLength": len(blob)}],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(blob)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(blob), 0x004E4942) + bytes(blob))


# ---------- tarifler ----------
def bands(b, poly, h, trim, with_parapet):
    y = FLOOR_H * 2
    while y < h - 1.0:
        if y > GATE_CLEAR:
            b.ring(offset(poly, LEDGE_OUT), offset(poly, -0.05), y - LEDGE_H, y, trim)
        y += FLOOR_H
    b.ring(offset(poly, CORNICE_OUT), offset(poly, -0.05), h - CORNICE_H, h + 0.05, trim)
    if with_parapet:
        b.ring(offset(poly, 0.1), offset(poly, -PARAPET_IN), h, h + PARAPET_H, trim)


def recipe_modern(b, poly, h, spec, rng):
    bands(b, poly, h, "trim", True)
    for q in interior_points(poly, 4.5, 4, rng):
        b.box(q[0], q[1], rng.uniform(2.0, 3.5), rng.uniform(1.5, 2.5), h, h + rng.uniform(1.0, 1.8), "roof_unit", rng.uniform(0, math.pi))
    for q in interior_points(poly, 6.0, int(spec.get("stacks", 0)), rng):
        b.cylinder(q[0], q[1], 0.6, h, h + 4.5, "brick")
        b.cylinder(q[0], q[1], 0.75, h + 4.5, h + 4.9, "dark")
    if spec.get("mast"):
        c = interior_points(poly, 3.0, 1, rng)
        if c:
            x, z = c[0]
            b.box(x, z, 1.2, 1.2, h, h + 1.0, "roof_unit")
            b.cylinder(x, z, 0.12, h + 1.0, h + 9.0, "dark", seg=6)
            b.box(x, z, 1.4, 0.15, h + 6.5, h + 7.3, "dark")


def recipe_historic(b, poly, h, spec, rng):
    # Taş korniş + kat silmesi (kırma çatı Godot'ta), çatı eteğinde tuğla bacalar
    bands(b, poly, h, "stone", False)
    n = len(poly)
    inner = offset(poly, -3.0)
    for i in range(n):
        a, c = inner[i], inner[(i + 1) % n]
        k = int(math.dist(poly[i], poly[(i + 1) % n]) // 22)
        yaw = math.atan2(c[1] - a[1], c[0] - a[0])
        for s in range(1, k + 1):
            t = s / (k + 1)
            x, z = a[0] + (c[0] - a[0]) * t, a[1] + (c[1] - a[1]) * t
            b.box(x, z, 1.4, 0.8, h, h + 3.6, "brick", yaw)
            b.box(x, z, 1.7, 1.1, h + 3.6, h + 3.9, "stone", yaw)


def recipe_mosque(b, poly, h, spec, rng):
    bands(b, poly, h, "white", False)
    cx, cz = centroid(poly)
    n = len(poly)
    # Kenarlara en kısa uzaklık (köşeye değil) -> kubbe gövdeden taşmasın
    edge_d = min(math.dist((cx, cz), seg_closest((cx, cz), poly[i], poly[(i + 1) % n])) for i in range(n))
    r = edge_d * 0.7
    drum = h + 2.6  # Godot'taki kırma çatının (2.5 m) üstünden çıksın
    b.cylinder(cx, cz, r * 1.04, h, drum, "white", seg=10)
    b.dome(cx, cz, r, drum, "dome")
    b.cylinder(cx, cz, 0.08, drum + r - 0.1, drum + r + 1.3, "dark", seg=4)
    # Minare: gövdeden en uzak köşenin hemen dışında
    far = max(poly, key=lambda q: math.dist(q, (cx, cz)))
    d = math.dist(far, (cx, cz)) or 1.0
    mx, mz = far[0] + (far[0] - cx) / d * 1.6, far[1] + (far[1] - cz) / d * 1.6
    top = h + 13.0
    b.cylinder(mx, mz, 1.0, 0.0, top, "white")
    b.cylinder(mx, mz, 1.45, top - 4.0, top - 3.4, "white")  # şerefe
    b.cylinder(mx, mz, 1.0, top, top + 4.0, "dome", cone=True)


def recipe_kiosk(b, poly, h, spec, rng):
    b.ring(offset(poly, 0.25), offset(poly, -0.05), h - 0.3, h + 0.1, "trim")
    n = len(poly)
    i = max(range(n), key=lambda k: math.dist(poly[k], poly[(k + 1) % n]))
    a, c = poly[i], poly[(i + 1) % n]
    nx, nz = edge_normal(a, c, signed_area(poly) > 0)
    y0 = min(h - 0.4, 2.9)
    b.prism([a, c, (c[0] + nx * 1.8, c[1] + nz * 1.8), (a[0] + nx * 1.8, a[1] + nz * 1.8)], y0 - 0.12, y0, "awning")


RECIPES = {"modern": recipe_modern, "historic": recipe_historic, "mosque": recipe_mosque, "kiosk": recipe_kiosk}


def main():
    grey = json.load(open(os.path.join(ROOT, "game/data/zones/kampus_greybox.json"), encoding="utf-8"))
    spec_all = json.load(open(os.path.join(ROOT, "tools/assets/landmarks.json"), encoding="utf-8"))
    out_dir = os.path.join(ROOT, "game/assets/buildings")
    os.makedirs(out_dir, exist_ok=True)
    manifest = {"_note": "tools/assets/make_landmarks.py üretir; elle düzenleme. Bina adı -> süs modeli (sahne koordinatlarında).", "buildings": {}}
    for spec in spec_all["buildings"]:
        bdata = next((x for x in grey["buildings"] if x.get("name") == spec["match"]), None)
        if bdata is None:
            print("YOK:", spec["match"])
            continue
        poly = clean([tuple(q) for q in bdata["points"]])
        h = float(bdata.get("height", 10.0))
        b = Builder()
        RECIPES[spec["recipe"]](b, poly, h, spec, random.Random(spec["id"]))
        tris = b.tri_count()
        assert tris <= MAX_TRIS, "%s: %d üçgen > %d" % (spec["id"], tris, MAX_TRIS)
        write_glb(os.path.join(out_dir, spec["id"] + ".glb"), spec["id"], b)
        manifest["buildings"][spec["match"]] = "res://assets/buildings/%s.glb" % spec["id"]
        print("OK %s: %d üçgen" % (spec["id"], tris))
    with open(os.path.join(ROOT, "game/data/landmarks.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
