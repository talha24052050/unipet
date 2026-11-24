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
MAX_TRIS = 3200  # Kışla ~1.5 km çevreli tek bina (10 giriş bölümüyle ~2.8k); diğerleri < 1200
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
    "column": (0.94, 0.94, 0.92),
    "palm_trunk": (0.50, 0.38, 0.26),
    "palm_leaf": (0.30, 0.55, 0.25),
    "cut_stone": (0.82, 0.77, 0.66),
    "concrete": (0.72, 0.71, 0.68),
    "kisla_wall": (0.937, 0.890, 0.784),  # building_style.gd HISTORIC_WALL ile aynı
    "kisla_roof": (0.63, 0.34, 0.27),     # HISTORIC_ROOF ile aynı
    "hall_roof": (0.76, 0.77, 0.78),
    "post_white": (0.9, 0.9, 0.88),
    "terrace": (0.58, 0.56, 0.52),
    "sign_navy": (0.16, 0.20, 0.42),
    "mescit_stone": (0.78, 0.77, 0.71),
    "mescit_stone_dark": (0.64, 0.63, 0.57),
    "mescit_drum": (0.67, 0.66, 0.60),
    "mescit_cap": (0.48, 0.50, 0.45),
    "corten": (0.48, 0.30, 0.19),
    "glass_dark": (0.14, 0.18, 0.21),
    "buyukev_grey": (0.68, 0.70, 0.66),
    "buyukev_roof_edge": (0.44, 0.46, 0.45),
    "buyukev_tile": (0.62, 0.34, 0.23),
    "buyukev_stone": (0.58, 0.56, 0.50),
    "buyukev_wood": (0.58, 0.38, 0.22),
    "buyukev_flagstone": (0.67, 0.69, 0.68),
    "hedge_green": (0.18, 0.40, 0.16),
    "warm_glow": (0.90, 0.72, 0.44),
    "lib_roof_dark": (0.24, 0.26, 0.30),
    "lib_roof_seam": (0.31, 0.33, 0.37),
    "lib_skylight": (0.48, 0.62, 0.74),
    "lib_white": (0.94, 0.94, 0.93),
    "lib_glass_black": (0.18, 0.25, 0.33),
    "lib_frame_black": (0.11, 0.12, 0.14),
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

    def tube(self, x0, z0, y0, r0, x1, z1, y1, r1, color, seg=6):
        """Eğik, daralan gövde (alt ve üst halka farklı merkezde): tek parça, basamaksız."""
        lo = [(x0 + r0 * math.cos(2 * math.pi * i / seg), y0, z0 + r0 * math.sin(2 * math.pi * i / seg)) for i in range(seg)]
        hi = [(x1 + r1 * math.cos(2 * math.pi * i / seg), y1, z1 + r1 * math.sin(2 * math.pi * i / seg)) for i in range(seg)]
        faces = [list(reversed(lo)), hi] + [[lo[i], lo[(i + 1) % seg], hi[(i + 1) % seg], hi[i]] for i in range(seg)]
        self._add_faces(color, faces, None, center=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))

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
def write_glb(path, name, builder, single_surface=False):
    """single_surface: tüm renkler tek primitive + köşe rengi (COLOR_0) → tek çizim çağrısı (çok kopyalanan ağaçlar için)."""
    blob = bytearray()
    accessors, views, prims, mats = [], [], [], []

    def add_view(data, target):
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), "target": target})
        blob.extend(data)
        return len(views) - 1

    groups = [(c, [(t, c) for t in tris]) for c, tris in builder.tris.items() if tris]
    if single_surface:
        groups = [("vc", [x for _, g in groups for x in g])]
    for color, items in groups:
        pos, nrm, col = [], [], []
        for (a, b, c, n), cname in items:
            r, g, bl = COLORS[cname]
            for p in (a, b, c):
                pos.append(p)
                nrm.append(n)
                col.append((r ** 2.2, g ** 2.2, bl ** 2.2))  # glTF köşe rengi lineer
        pv = add_view(b"".join(struct.pack("<3f", *p) for p in pos), 34962)
        nv = add_view(b"".join(struct.pack("<3f", *n) for n in nrm), 34962)
        mn = [min(p[i] for p in pos) for i in range(3)]
        mx = [max(p[i] for p in pos) for i in range(3)]
        accessors.append({"bufferView": pv, "componentType": 5126, "count": len(pos), "type": "VEC3", "min": mn, "max": mx})
        accessors.append({"bufferView": nv, "componentType": 5126, "count": len(nrm), "type": "VEC3"})
        attrs = {"POSITION": len(accessors) - 2, "NORMAL": len(accessors) - 1}
        if single_surface:
            cv = add_view(b"".join(struct.pack("<3f", *c) for c in col), 34962)
            accessors.append({"bufferView": cv, "componentType": 5126, "count": len(col), "type": "VEC3"})
            attrs["COLOR_0"] = len(accessors) - 1
            mats.append({"name": "lm_vertex_color", "pbrMetallicRoughness": {
                "baseColorFactor": [1.0, 1.0, 1.0, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.9}})
        else:
            r, g, b = COLORS[color]
            is_glossy = color in ("lib_glass_black", "lib_skylight", "glass_dark")
            is_frame = color in ("lib_frame_black", "lib_roof_dark")
            mats.append({"name": "lm_" + color, "pbrMetallicRoughness": {
                "baseColorFactor": [r ** 2.2, g ** 2.2, b ** 2.2, 1.0],
                "metallicFactor": 0.42 if is_glossy else (0.25 if is_frame else 0.0),
                "roughnessFactor": 0.15 if is_glossy else (0.55 if is_frame else 0.9)}})
        prims.append({"attributes": attrs, "material": len(mats) - 1})
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
    if spec.get("pavilions"):
        for i, pt in wall_crossings(poly, spec["_paths"]):
            pavilion(b, poly, i, pt, h, "kisla_wall", "stone", "kisla_roof")


GATE_W = 4.0       # Godot greybox_builder GATE_WIDTH ile aynı
GATE_H = 3.2       # GATE_HEIGHT
PAV_W = 15.0       # giriş bölümü (risalit) genişliği
PAV_OUT = 1.1      # duvardan öne çıkma
PAV_RISE = 1.8     # ana saçaktan yükseklik farkı
PEDIMENT_H = 2.4   # üçgen alınlık


def seg_intersect(p1, p2, q1, q2):
    """İki doğru parçasının kesişimi: (t, nokta) ya da None (t: p1→p2 üzerinde 0..1)."""
    d1 = (p2[0] - p1[0], p2[1] - p1[1])
    d2 = (q2[0] - q1[0], q2[1] - q1[1])
    den = d1[0] * d2[1] - d1[1] * d2[0]
    if abs(den) < 1e-9:
        return None
    t = ((q1[0] - p1[0]) * d2[1] - (q1[1] - p1[1]) * d2[0]) / den
    u = ((q1[0] - p1[0]) * d1[1] - (q1[1] - p1[1]) * d1[0]) / den
    if 0.0 <= t <= 1.0 and 0.0 <= u <= 1.0:
        return t, (p1[0] + d1[0] * t, p1[1] + d1[1] * t)
    return None


def _straight_run(poly, i, pt, direction, max_turn_deg=8.0):
    """pt'den kenar i boyunca (direction=+1 ileri, -1 geri) düz devam eden duvar uzunluğu (hafif kırıklar dahil)."""
    n = len(poly)
    a, c = poly[i], poly[(i + 1) % n]
    u = ((c[0] - a[0]) / math.dist(a, c), (c[1] - a[1]) / math.dist(a, c))
    run = math.dist(pt, c if direction > 0 else a)
    k = i
    for _ in range(n):
        k = (k + direction) % n
        p0, p1 = poly[k], poly[(k + 1) % n]
        L_ = math.dist(p0, p1)
        if L_ < 1e-6:
            continue
        v = ((p1[0] - p0[0]) / L_, (p1[1] - p0[1]) / L_)
        if math.degrees(math.acos(max(-1.0, min(1.0, u[0] * v[0] + u[1] * v[1])))) > max_turn_deg:
            break
        run += L_
    return run


def wall_crossings(poly, paths, min_gap=12.0):
    """Yolların duvarı kestiği/duvara dayandığı yerler (Godot burada geçit açar): [(kenar indeksi, nokta)].
    OSM'de yol uçları çoğu zaman tam bina köşe noktasında: düz devam eden duvar boyunca yer var mı diye bakılır."""
    out = []
    n = len(poly)
    for i in range(n):
        a, c = poly[i], poly[(i + 1) % n]
        edge_len = math.dist(a, c)
        if edge_len < 1e-6:
            continue
        hits = []
        for line in paths:
            for j in range(len(line) - 1):
                hit = seg_intersect(a, c, line[j], line[j + 1])
                if hit is not None:
                    hits.append(hit[1])
            for e in (line[0], line[-1]):  # yol duvara dayanıp bitiyor (Godot GATE_TOUCH_DIST)
                q = seg_closest(e, a, c)
                if math.dist(q, e) < 1.0:
                    hits.append(q)
        for pt in hits:
            if _straight_run(poly, i, pt, 1) < PAV_W / 2 + 1.0 or _straight_run(poly, i, pt, -1) < PAV_W / 2 + 1.0:
                continue  # köşeye çok yakın: bölüm duvardan taşmasın
            if all(math.dist(pt, q) > min_gap for _, q in out):
                out.append((i, pt))
    return out


def pavilion(b, poly, i, pt, h, wall_color, trim_color, roof_color):
    """Geçidin üstünde öne çıkan giriş bölümü: iki yan ayak + geçit üstü kütle + üçgen alınlık; geçit açık kalır."""
    a, c = poly[i], poly[(i + 1) % len(poly)]
    L_ = math.dist(a, c)
    u = ((c[0] - a[0]) / L_, (c[1] - a[1]) / L_)
    nx, nz = edge_normal(a, c, signed_area(poly) > 0)
    top = h + PAV_RISE

    def rect(along0, along1, out0, out1):
        return [(pt[0] + u[0] * s + nx * o, pt[1] + u[1] * s + nz * o)
                for s, o in ((along0, out0), (along1, out0), (along1, out1), (along0, out1))]

    half = PAV_W / 2
    gap = GATE_W / 2 + 0.1
    b.prism(rect(-half, -gap, -0.2, PAV_OUT), 0.0, top, wall_color)            # sol ayak
    b.prism(rect(gap, half, -0.2, PAV_OUT), 0.0, top, wall_color)              # sağ ayak
    b.prism(rect(-gap, gap, -0.2, PAV_OUT), GATE_H + 0.6, top, wall_color)     # geçit üstü (kemer hizası)
    b.prism(rect(-half - 0.25, half + 0.25, -0.2, PAV_OUT + 0.25), top - 0.45, top, trim_color)  # korniş
    b.prism(rect(-gap - 0.5, gap + 0.5, PAV_OUT - 0.05, PAV_OUT + 0.15), GATE_H + 0.2, GATE_H + 0.6, trim_color)  # kemer başlığı
    # Üçgen alınlık (önden görünen), arkası kiremit eğimli çatı
    front_l = (pt[0] + u[0] * -half + nx * (PAV_OUT + 0.25), top, pt[1] + u[1] * -half + nz * (PAV_OUT + 0.25))
    front_r = (pt[0] + u[0] * half + nx * (PAV_OUT + 0.25), top, pt[1] + u[1] * half + nz * (PAV_OUT + 0.25))
    front_t = (pt[0] + nx * (PAV_OUT + 0.25), top + PEDIMENT_H, pt[1] + nz * (PAV_OUT + 0.25))
    back_l = (pt[0] + u[0] * -half - nx * 4.0, top, pt[1] + u[1] * -half - nz * 4.0)
    back_r = (pt[0] + u[0] * half - nx * 4.0, top, pt[1] + u[1] * half - nz * 4.0)
    back_t = (pt[0] - nx * 4.0, top + PEDIMENT_H, pt[1] - nz * 4.0)
    cen = (pt[0] - nx * 1.8, top + PEDIMENT_H * 0.35, pt[1] - nz * 1.8)
    b._add_faces(trim_color, [[front_l, front_r, front_t], [back_l, back_t, back_r]], None, center=cen)
    b._add_faces(roof_color, [[front_l, front_t, back_t, back_l], [front_r, back_r, back_t, front_t],
                              [front_l, back_l, back_r, front_r]], None, center=cen)


def recipe_mosque(b, poly, h, spec, rng):
    """Davutpaşa Kışlası Mescidi (gerçek fotoğraf referansı): kubbesiz alçak taş yapı,
    sol köşede kalın kare kesme taş minare kaidesi + kısa silindirik taş petek + konik kurşun külah + alem,
    ön cephe sol tarafında küçük kahverengi camlı kabin ve gri kutu."""
    # Çatı saçağında ince taş korniş
    b.ring(offset(poly, 0.26), offset(poly, -0.05), h - 0.24, h + 0.04, "mescit_stone_dark")

    # Uzun ön cephe (bulvara bakan kenar 1: [-53.99,-13.84] -> [-67.2,-24.2]; genel olarak en uzun dış kenar)
    n = len(poly)
    ccw = signed_area(poly) > 0
    edge_i = 1 if n >= 4 else max(range(n), key=lambda k: math.dist(poly[k], poly[(k + 1) % n]))
    p1, p2 = poly[edge_i], poly[(edge_i + 1) % n]
    L_ = math.dist(p1, p2) or 1.0
    ux, uz = (p2[0] - p1[0]) / L_, (p2[1] - p1[1]) / L_
    nx, nz = edge_normal(p1, p2, ccw)
    yaw = math.atan2(uz, ux)

    # 1) Kalın kare kesme taş minare kulesi (p1 köşesine bitişik, hafif dışa taşan)
    mx = p1[0] - ux * 0.70 + nx * 0.55
    mz = p1[1] - uz * 0.70 + nz * 0.55
    b.box(mx, mz, 3.20, 3.20, -1.2, 1.35, "mescit_stone_dark", yaw)   # alt taş kaide
    b.box(mx, mz, 2.85, 2.85, 1.35, 8.35, "mescit_stone", yaw)        # ana kare taş gövde
    # Üst gövdede küçük dikey mazgal delikleri
    for side_n in (-1, 1):
        b.box(mx + nx * side_n * 1.44, mz + nz * side_n * 1.44, 0.14, 0.08, 6.55, 7.25, "dark", yaw)
    for side_u in (-1, 1):
        b.box(mx + ux * side_u * 1.44, mz + uz * side_u * 1.44, 0.08, 0.14, 6.55, 7.25, "dark", yaw)
    # Üstte kademeli çıkıntılı kare taş korniş / başlık
    b.box(mx, mz, 3.04, 3.04, 8.35, 8.60, "mescit_stone_dark", yaw)
    b.box(mx, mz, 3.26, 3.26, 8.60, 9.05, "mescit_stone", yaw)
    # Kısa silindirik taş petek (kareden dar)
    b.cylinder(mx, mz, 0.96, 9.05, 11.45, "mescit_drum", seg=12)
    # Konik gri-zeytin külah + ince alem
    b.cylinder(mx, mz, 1.08, 11.45, 13.45, "mescit_cap", seg=12, cone=True)
    b.cylinder(mx, mz, 0.06, 13.38, 14.55, "dark", seg=6)
    b.cylinder(mx, mz, 0.14, 13.72, 13.88, "dark", seg=8)
    b.cylinder(mx, mz, 0.11, 14.08, 14.20, "dark", seg=8)

    # 2) Minarenin hemen sağında küçük kahverengi camlı kabin + önünde alçak gri kutu (fotoğraftaki gibi)
    cx_cab = p1[0] + ux * 3.1 + nx * 1.45
    cz_cab = p1[1] + uz * 3.1 + nz * 1.45
    b.box(cx_cab, cz_cab, 3.5, 1.8, -0.4, 2.35, "corten", yaw)
    b.box(cx_cab + nx * 0.91, cz_cab + nz * 0.91, 3.1, 0.06, 1.25, 2.08, "glass_dark", yaw)
    b.box(cx_cab - ux * 1.76, cz_cab - uz * 1.76, 0.06, 1.35, 1.25, 2.08, "glass_dark", yaw)
    # Alçak gri beton/tesisat kutusu
    bx_box = p1[0] + ux * 4.5 + nx * 2.55
    bz_box = p1[1] + uz * 4.5 + nz * 2.55
    b.box(bx_box, bz_box, 1.55, 0.95, -0.4, 1.15, "concrete", yaw)

    # 3) Sağ köşede ince yağmur iniş borusu
    b.cylinder(p2[0] + nx * 0.08, p2[1] + nz * 0.08, 0.06, 0.0, h, "mescit_stone_dark", seg=6)


def recipe_kiosk(b, poly, h, spec, rng):
    b.ring(offset(poly, 0.25), offset(poly, -0.05), h - 0.3, h + 0.1, "trim")
    n = len(poly)
    i = max(range(n), key=lambda k: math.dist(poly[k], poly[(k + 1) % n]))
    a, c = poly[i], poly[(i + 1) % n]
    nx, nz = edge_normal(a, c, signed_area(poly) > 0)
    y0 = min(h - 0.4, 2.9)
    b.prism([a, c, (c[0] + nx * 1.8, c[1] + nz * 1.8), (a[0] + nx * 1.8, a[1] + nz * 1.8)], y0 - 0.12, y0, "awning")


def nearest_edge_to_paths(poly, paths):
    """Yollara en yakın (giriş) kenarı: orta noktası herhangi bir yol noktasına en yakın, en az 8 m uzun kenar."""
    n = len(poly)
    best, best_d = 0, float("inf")
    for i in range(n):
        a, c = poly[i], poly[(i + 1) % n]
        if math.dist(a, c) < 8.0:
            continue
        mid = ((a[0] + c[0]) / 2, (a[1] + c[1]) / 2)
        for line in paths:
            for j in range(len(line) - 1):
                d = math.dist(mid, seg_closest(mid, line[j], line[j + 1]))
                if d < best_d:
                    best, best_d = i, d
    return best


def palm(b, x, z, h, rng):
    """Alçak poligon palmiye: hafif eğik gövde + sarkık yapraklar."""
    lean = (rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6))
    segs = 4
    for k in range(segs):
        y0, y1 = h * k / segs, h * (k + 1) / segs
        t0, t1 = k / segs, (k + 1) / segs
        r = 0.28 - 0.06 * t0
        cx, cz = x + lean[0] * t0 * t0, z + lean[1] * t0 * t0
        b.cylinder(cx, cz, r, y0, y1 + 0.02, "palm_trunk", seg=6)
    tx, tz = x + lean[0], z + lean[1]
    for k in range(7):
        ang = 2 * math.pi * k / 7 + rng.uniform(-0.2, 0.2)
        dx, dz = math.cos(ang), math.sin(ang)
        px, pz = -dz * 0.35, dx * 0.35  # yaprak genişliği yönü
        L = rng.uniform(2.6, 3.2)
        root = (tx, h, tz)
        mid = (tx + dx * L * 0.55, h + 0.5, tz + dz * L * 0.55)
        tip = (tx + dx * L, h - 1.1, tz + dz * L)
        leaf = [[root, (mid[0] + px, mid[1], mid[2] + pz), tip], [root, tip, (mid[0] - px, mid[1], mid[2] - pz)]]
        # ince yaprak: iki üçgen, her iki yüz için ters kopya (kapalı katı değil)
        out = b.tris.setdefault("palm_leaf", [])
        for f in leaf:
            a, c, d = f
            n = norm(cross(sub(c, a), sub(d, a)))
            if n[1] < 0:
                c, d = d, c
                n = (-n[0], -n[1], -n[2])
            out.append((a, c, d, n))
            out.append((a, d, c, (-n[0], -n[1], -n[2])))


def recipe_library(b, poly, h, spec, rng):
    """Merkez Kütüphane: düz çatı + parapet, giriş cephesinde yüksek beyaz sütunlu revak, önünde palmiyeler."""
    bands(b, poly, h, "trim", True)
    i = nearest_edge_to_paths(poly, spec["_paths"])
    a, c = poly[i], poly[(i + 1) % len(poly)]
    nx, nz = edge_normal(a, c, signed_area(poly) > 0)
    L = math.dist(a, c)
    ux, uz = (c[0] - a[0]) / L, (c[1] - a[1]) / L
    depth = 2.8
    span = min(L * 0.6, 26.0)
    s0 = (L - span) / 2
    count = max(4, int(span // 4.0) + 1)
    top = h - 0.6
    for k in range(count):
        t = s0 + span * k / (count - 1)
        x, z = a[0] + ux * t + nx * depth, a[1] + uz * t + nz * depth
        b.cylinder(x, z, 0.4, 0.0, top, "column", seg=8)
    # revak çatısı (sütunlardan duvara)
    e0 = (a[0] + ux * (s0 - 1.0), a[1] + uz * (s0 - 1.0))
    e1 = (a[0] + ux * (s0 + span + 1.0), a[1] + uz * (s0 + span + 1.0))
    slab = [e0, e1, (e1[0] + nx * (depth + 0.8), e1[1] + nz * (depth + 0.8)), (e0[0] + nx * (depth + 0.8), e0[1] + nz * (depth + 0.8))]
    b.prism(slab, top, top + 0.6, "column")
    # palmiyeler: girişe giden yolun iki yanında
    for k, side in enumerate((-1, 1, -1, 1)):
        dist = 9.0 + 7.0 * (k // 2)
        mx, mz = a[0] + ux * L / 2 + nx * dist, a[1] + uz * L / 2 + nz * dist
        palm(b, mx + ux * side * 4.5, mz + uz * side * 4.5, rng.uniform(6.0, 7.5), rng)


def recipe_domed(b, poly, h, spec, rng):
    """Otağ-ı Hümayun / tarihi hamam: kesme taş korniş, kurşun kubbe(ler), bacalar."""
    bands(b, poly, h, "cut_stone", False)
    cx, cz = centroid(poly)
    n = len(poly)
    edge_d = min(math.dist((cx, cz), seg_closest((cx, cz), poly[i], poly[(i + 1) % n])) for i in range(n))
    domes = int(spec.get("domes", 1))
    r = edge_d * (0.6 if domes == 1 else 0.38)
    drum = h + 2.6  # Godot'taki kırma çatının üstünden çıksın
    centers = [(cx, cz)] if domes == 1 else interior_points(poly, r * 2.1, domes, rng) or [(cx, cz)]
    for x, z in centers:
        b.cylinder(x, z, r * 1.05, h, drum, "cut_stone", seg=10)
        b.dome(x, z, r, drum, "dome")
        b.cylinder(x, z, 0.07, drum + r - 0.1, drum + r + 1.0, "dark", seg=4)
    for q in interior_points(poly, 3.0, int(spec.get("chimneys", 0)), rng):
        b.cylinder(q[0], q[1], 0.45, h, drum + 1.5, "cut_stone", seg=8)
        b.cylinder(q[0], q[1], 0.6, drum + 1.5, drum + 2.2, "dome", seg=8, cone=True)


def nearest_road(pos, paths_all):
    """Kapı konumuna en yakın yol parçası: (yakın nokta, birim yön, tür)."""
    best = None
    for kind, line in paths_all:
        for j in range(len(line) - 1):
            c = seg_closest(pos, line[j], line[j + 1])
            d = math.dist(c, pos)
            if best is None or d < best[0]:
                L = math.dist(line[j], line[j + 1]) or 1.0
                best = (d, c, ((line[j + 1][0] - line[j][0]) / L, (line[j + 1][1] - line[j][1]) / L), kind)
    return best[1], best[2], best[3]


def _quad(c, u, along, across):
    ux, uz = u
    nx, nz = -uz, ux
    return [(c[0] + ux * a * along / 2 + nx * s * across / 2, c[1] + uz * a * along / 2 + nz * s * across / 2)
            for a, s in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def gate_portal(b, c, u, half_open):
    """Ana giriş: iki kalın beton duvar + üstte eğik beton tabla + lacivert YTÜ panosu (fotoğraftaki brütalist kapı)."""
    ux, uz = u
    nx, nz = -uz, ux
    depth, thick, h_low, h_high, T = 7.0, 1.6, 8.0, 10.5, 0.8
    for side, top in ((-1, h_low), (1, h_high)):
        off = half_open + thick / 2
        b.prism(_quad((c[0] + nx * side * off, c[1] + nz * side * off), u, depth, thick), 0.0, top, "concrete")
    span = 2 * (half_open + thick) + 2.0
    pts = {}
    for a in (-1, 1):
        for s_ in (-1, 1):
            y = (h_low if s_ < 0 else h_high) + 0.05
            pts[(a, s_)] = (c[0] + ux * a * (depth + 2) / 2 + nx * s_ * span / 2, y, c[1] + uz * a * (depth + 2) / 2 + nz * s_ * span / 2)
    up = lambda q: (q[0], q[1] + T, q[2])
    A, B, C, D = pts[(-1, -1)], pts[(-1, 1)], pts[(1, 1)], pts[(1, -1)]
    faces = [[A, B, C, D], [up(A), up(D), up(C), up(B)],
             [A, D, up(D), up(A)], [B, up(B), up(C), C], [A, up(A), up(B), B], [D, C, up(C), up(D)]]
    b._add_faces("concrete", faces, None, center=(c[0], (h_low + h_high) / 2 + T / 2, c[1]))
    # pano: yüksek duvarın yol tarafındaki yüzünde
    b.prism(_quad((c[0] + nx * (half_open - 0.08), c[1] + nz * (half_open - 0.08)), u, 4.0, 0.12), 5.2, 6.6, "sign_navy")


def gate_simple(b, c, u, half_open):
    """Yaya girişi: iki taş ayak + üstte lacivert pano."""
    ux, uz = u
    nx, nz = -uz, ux
    yaw = math.atan2(uz, ux)
    for side in (-1, 1):
        x, z = c[0] + nx * side * (half_open + 0.6), c[1] + nz * side * (half_open + 0.6)
        b.box(x, z, 1.2, 1.2, 0.0, 4.2, "cut_stone", yaw)
        b.box(x, z, 1.5, 1.5, 4.2, 4.6, "cut_stone", yaw)
    b.prism(_quad(c, u, 0.25, 2 * half_open + 2.4), 3.6, 4.4, "sign_navy")


GATES = {"portal": gate_portal, "simple": gate_simple}

def recipe_gable_hall(b, poly, h, spec, rng):
    """Büyük Ev (Google Haritalar 4 fotoğraf referansı):
    - Ön cephe (GB): açık gri-adaçayı üçgen alınlıklı 3 gözlü sundurma, sol & sağ gözlerde kalın SİYAH çelik X çaprazlar,
      altta doğal taş kaplama kaide, ortada ahşap/taş giriş basamakları + engelli rampası + çapraz ahşap kolon + cam kapı.
    - Üst çatı: kiremit kaplı beşik çatı + koyu gri metal saçak çerçevesi.
    - Uzun KB (bulvar) cephesi: 46 m boyunca siyah çelik-cam kış bahçesi + iç yeşil çit bandı."""
    import sys as _sys
    _sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import make_greenery as G
    c, u, hu, hv = G.min_area_rect(poly)
    v = (-u[1], u[0])
    fx, fz = spec["front"]
    front_sign = 1 if (fx - c[0]) * u[0] + (fz - c[1]) * u[1] > 0 else -1
    # Bulvar tarafı (KB, Yemekhane yönü = (-103, -95)) v işaretini belirle
    road_sign = 1 if ((-60.0 - c[0]) * v[0] + (-95.0 - c[1]) * v[1]) > 0 else -1
    rise, side_over, porch = 2.45, 0.65, 4.4
    y0 = h
    yaw_u = math.atan2(u[1], u[0])

    def P(a, s, y):
        return (c[0] + u[0] * a + v[0] * s, y, c[1] + u[1] * a + v[1] * s)

    def beam_3d(p0, p1, half_t, color):
        # İki nokta arasında kalın dikdörtgen çelik/ahşap kiriş
        dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
        L_ = math.sqrt(dx * dx + dy * dy + dz * dz) or 1.0
        tx, ty, tz = dx / L_, dy / L_, dz / L_
        # Birim dik eksenler
        ref = (0.0, 1.0, 0.0) if abs(ty) < 0.9 else (1.0, 0.0, 0.0)
        ax, ay, az = norm(cross((tx, ty, tz), ref))
        bx, by, bz = norm(cross((tx, ty, tz), (ax, ay, az)))
        offs = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        r0 = [(p0[0] + (ax * ox + bx * oy) * half_t, p0[1] + (ay * ox + by * oy) * half_t, p0[2] + (az * ox + bz * oy) * half_t) for ox, oy in offs]
        r1 = [(p1[0] + (ax * ox + bx * oy) * half_t, p1[1] + (ay * ox + by * oy) * half_t, p1[2] + (az * ox + bz * oy) * half_t) for ox, oy in offs]
        faces = [list(reversed(r0)), r1] + [[r0[i], r0[(i + 1) % 4], r1[(i + 1) % 4], r1[i]] for i in range(4)]
        b._add_faces(color, faces, None, center=((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2))

    back = -front_sign * (hu + 0.5)
    front = front_sign * (hu + porch)
    w = hv + side_over
    T = 0.26

    # 1) Beşik çatı (kiremit kaplı uzun yan yüzeyler + koyu gri metal kenar alınlığı)
    for side in (-1, 1):
        e0, e1 = P(back, side * w, y0 - 0.15), P(front, side * w, y0 - 0.15)
        r0, r1 = P(back, 0, y0 + rise), P(front, 0, y0 + rise)
        up = lambda q: (q[0], q[1] + T, q[2])
        cen = P((back + front) / 2, side * w * 0.5, y0 + rise * 0.45 + T * 0.5)
        b._add_faces("buyukev_tile", [[up(e0), up(r0), up(r1), up(e1)]], None, center=cen)
        b._add_faces("buyukev_roof_edge", [
            [e0, e1, r1, r0], [e0, up(e0), up(e1), e1],
            [e0, r0, up(r0), up(e0)], [e1, up(e1), up(r1), r1],
        ], None, center=cen)

    # 2) Ön cephe üçgen alınlık çerçevesi (sol-sağ kalın açık gri duvar ayakları + üst alınlık kirişi)
    fa = front_sign * (hu + porch - 0.18)
    fa_in = front_sign * (hu + porch - 0.85)
    # Üst alınlık üçgeni (ön ve arka yüz)
    for a_pos in (fa, fa_in):
        tri = [P(a_pos, -hv - 0.35, y0 - 0.1), P(a_pos, hv + 0.35, y0 - 0.1), P(a_pos, 0, y0 + rise - 0.05)]
        b._add_faces("buyukev_grey", [tri], None, center=P((fa + fa_in) / 2, 0, y0 + 0.4))
    # Alınlık altında kalın yatay gri üst kiriş
    beam_3d(P(fa - front_sign * 0.3, -hv - 0.25, y0 - 0.18), P(fa - front_sign * 0.3, hv + 0.25, y0 - 0.18), 0.30, "buyukev_grey")
    # 4 kalın açık gri dikey cephe kolonu (sol dış, orta-sol, orta-sağ, sağ dış → 3 göz!)
    col_s = [-hv + 0.35, -2.55, 2.55, hv - 0.35]
    for s_col in col_s:
        qx, _, qz = P(fa - front_sign * 0.32, s_col, 0)
        b.box(qx, qz, 0.72, 1.02, -0.4, y0, "buyukev_grey", yaw_u)
        b.box(qx, qz, 0.78, 1.08, -0.4, 0.60, "buyukev_stone", yaw_u)  # alt doğal taş kaide

    # 3) Sol ve sağ gözlerde KALIN SİYAH ÇELİK X ÇAPRAZLAR + alt doğal taş kaide duvarı (link2.jpg!)
    x_a = fa - front_sign * 0.32
    for s0, s1 in ((-hv + 0.80, -3.00), (3.00, hv - 0.80)):
        # Alt taş duvar kaidesi
        sm = (s0 + s1) / 2
        qx, _, qz = P(x_a, sm, 0)
        b.box(qx, qz, 0.52, abs(s1 - s0), -0.4, 0.58, "buyukev_stone", yaw_u)
        # Siyah çelik üst/alt yatay kirişler + kalın X çaprazlar
        y_lo, y_hi = 0.62, y0 - 0.28
        beam_3d(P(x_a, s0, y_lo), P(x_a, s1, y_hi), 0.14, "dark")
        beam_3d(P(x_a, s1, y_lo), P(x_a, s0, y_hi), 0.14, "dark")
        beam_3d(P(x_a, s0, y_lo), P(x_a, s1, y_lo), 0.08, "dark")
        beam_3d(P(x_a, s0, y_hi), P(x_a, s1, y_hi), 0.08, "dark")
        # Arka kısım sıcak ışıklı cam cephe (veranda içi)
        gx, _, gz = P(front_sign * (hu + 0.35), sm, 0)
        b.box(gx, gz, 0.12, abs(s1 - s0) + 0.5, 0.50, y0 - 0.2, "glass_dark", yaw_u)

    # 4) Orta giriş gözü (link1.jpg): sıcak tavan ahşap kirişleri, çapraz ahşap iç kolon, siyah sürgülü cam kapı,
    #    önünde 3 geniş kahverengi taş basamak + sağda engelli rampası
    for s_beam in (-1.2, 0.0, 1.2):
        beam_3d(P(front_sign * (hu + 0.2), s_beam, y0 - 0.18), P(fa - front_sign * 0.3, s_beam, y0 - 0.18), 0.10, "buyukev_wood")
    # Çapraz ahşap kaplamalı dekoratif iç kolon (link1.jpg ortada kapı yanında)
    wx, _, wz = P(front_sign * (hu + 1.15), -0.35, 0)
    b.box(wx, wz, 0.55, 0.62, 0.45, y0 - 0.2, "buyukev_wood", yaw_u)
    # Siyah çerçeveli sürgülü cam giriş kapısı + siyah kayıtlı sıcak vitrin (link1.jpg!)
    dx, _, dz = P(front_sign * (hu + 0.35), -1.45, 0)
    b.box(dx, dz, 0.22, 2.35, 0.45, 3.05, "dark", yaw_u)
    dx2, _, dz2 = P(front_sign * (hu + 0.45), -1.45, 0)
    b.box(dx2, dz2, 0.08, 1.95, 0.52, 2.82, "warm_glow", yaw_u)
    # Kapı ortasında ince siyah dikey kayıt + üst yatay kayıt
    b.box(dx2, dz2, 0.14, 0.08, 0.52, 2.82, "dark", yaw_u)
    b.box(dx2, dz2, 0.14, 1.98, 2.15, 2.24, "dark", yaw_u)
    # Sağ yarım cam vitrin (sıcak kafe içi + siyah cam kayıt ızgarası)
    dx3, _, dz3 = P(front_sign * (hu + 0.35), 1.35, 0)
    b.box(dx3, dz3, 0.14, 2.30, 0.50, 3.15, "warm_glow", yaw_u)
    b.box(dx3, dz3, 0.20, 0.08, 0.50, 3.15, "dark", yaw_u)
    b.box(dx3, dz3, 0.20, 2.32, 1.75, 1.84, "dark", yaw_u)
    b.box(dx3, dz3, 0.20, 2.32, 3.06, 3.18, "dark", yaw_u)
    # Koyu koyu antrasit BÜYÜK EV tabela arka plakası (alınlık tepesinde)
    sx_p, _, sz_p = P(fa + front_sign * 0.06, 0.0, 0)
    b.box(sx_p, sz_p, 0.16, 4.4, y0 + 0.35, y0 + 1.48, "dark", yaw_u)

    # 5) Giriş terası (doğal taş taban) + 3 basamak + sağda engelli rampası + ön kayrak taş meydan (link2.jpg!)
    porch_floor = [(q[0], q[2]) for q in (
        P(front_sign * hu, -hv, 0), P(front_sign * (hu + porch), -hv, 0),
        P(front_sign * (hu + porch), hv, 0), P(front_sign * hu, hv, 0),
    )]
    b.prism(porch_floor, -0.35, 0.48, "buyukev_stone")
    # 3 kahverengi basamak (orta giriş açıklığı boyunca)
    for k in range(3):
        a0 = front_sign * (hu + porch + k * 0.42)
        a1 = front_sign * (hu + porch + (k + 1) * 0.42)
        st_poly = [(q[0], q[2]) for q in (P(a0, -2.15, 0), P(a1, -2.15, 0), P(a1, 1.15, 0), P(a0, 1.15, 0))]
        b.prism(st_poly, -0.25, 0.44 - k * 0.13, "buyukev_wood")
    # Sağda engelli rampası (eğimli prizma)
    r_a0, r_a1 = front_sign * (hu + porch), front_sign * (hu + porch + 1.65)
    rp = [P(r_a0, 1.15, 0.46), P(r_a0, 2.25, 0.46), P(r_a1, 2.25, 0.12), P(r_a1, 1.15, 0.12)]
    rb = [P(r_a0, 1.15, -0.2), P(r_a0, 2.25, -0.2), P(r_a1, 2.25, -0.2), P(r_a1, 1.15, -0.2)]
    b._add_faces("buyukev_wood", [
        rp, list(reversed(rb)),
        [rb[0], rb[1], rp[1], rp[0]], [rb[1], rb[2], rp[2], rp[1]],
        [rb[2], rb[3], rp[3], rp[2]], [rb[3], rb[0], rp[0], rp[3]],
    ], None, center=P((r_a0 + r_a1) / 2, 1.7, 0.1))
    # Ön kayrak taş döşeli düz teras meydanı
    flag_poly = [(q[0], q[2]) for q in (
        P(front_sign * (hu + porch - 0.1), -hv - 1.4, 0), P(front_sign * (hu + porch + 3.6), -hv - 1.4, 0),
        P(front_sign * (hu + porch + 3.6), hv + 1.4, 0), P(front_sign * (hu + porch - 0.1), hv + 1.4, 0),
    )]
    b.prism(flag_poly, -0.25, 0.12, "buyukev_flagstone")

    # 6) Uzun KB (bulvar/Yemekhane) tarafında SİYAH ÇELİK-CAM KIŞ BAHÇESİ (link3.jpg & link4.jpg!)
    wg_len = hu * 1.78
    wg_a0 = -wg_len * 0.5
    wg_a1 = wg_len * 0.5
    wg_s0 = road_sign * (hv - 0.1)
    wg_s1 = road_sign * (hv + 3.15)
    wg_h = 3.10
    # Kış bahçesi siyah düz çatı tablası ve alınlığı
    wg_roof = [(q[0], q[2]) for q in (P(wg_a0, wg_s0, 0), P(wg_a1, wg_s0, 0), P(wg_a1, wg_s1, 0), P(wg_a0, wg_s1, 0))]
    b.prism(wg_roof, wg_h - 0.24, wg_h + 0.08, "dark")
    # Kış bahçesi zemin kaidesi
    b.prism(wg_roof, -0.35, 0.18, "buyukev_stone")
    # Kış bahçesi dış koyu cam cephe şeridi + iç yeşil çit/bitki bandı (link3.jpg!)
    wg_glass_s = road_sign * (hv + 2.98)
    gx_w, _, gz_w = P(0.0, wg_glass_s, 0)
    b.box(gx_w, gz_w, wg_len - 0.2, 0.10, 0.20, wg_h - 0.24, "glass_dark", yaw_u)
    hx_w, _, hz_w = P(0.0, road_sign * (hv + 2.75), 0)
    b.box(hx_w, hz_w, wg_len - 0.6, 0.34, 0.72, 1.28, "hedge_green", yaw_u)
    # Her ~2.4 m'de bir dikey siyah çelik kayıtlar (link3.jpg karakteristik ritmi!)
    n_mull = max(10, int(wg_len // 2.4))
    for k in range(n_mull + 1):
        aa = wg_a0 + wg_len * k / n_mull
        mx, _, mz = P(aa, road_sign * (hv + 3.05), 0)
        b.box(mx, mz, 0.14, 0.18, 0.14, wg_h - 0.18, "dark", yaw_u)
    # Alt yatay siyah kayıt bandı
    lx, _, lz = P(0.0, road_sign * (hv + 3.06), 0)
    b.box(lx, lz, wg_len, 0.16, 0.16, 0.34, "dark", yaw_u)
    # İki kısa uç cam + dikme (kış bahçesi baş/sonu)
    for aa_end in (wg_a0, wg_a1):
        ex, _, ez = P(aa_end, road_sign * (hv + 1.55), 0)
        b.box(ex, ez, 0.12, 3.05, 0.20, wg_h - 0.22, "glass_dark", yaw_u)


def recipe_new_library(b, poly, h, spec, rng):
    """YTÜ Yeni Merkez Kütüphanesi (TEB Mimarlık 2024 — yildiz.edu.tr & mimarizm.com referansları):
    - L-formlu ana kütüphane kütlesi (Arm A: 67.5x18.1m, Arm B: 73.5x18.5m) üstünde köşede 45° gönye birleşimli
      koyu antrasit kenet metal beşik çatı + her iki eğimde sıralı dikdörtgen çatı ışıklıkları +
      iki uçta beyaz üçgen alınlık çerçeveleri (Tarihi Hamam ucunda 2 dev camlı üçgen cephe).
    - Kare planlı özel kullanımlar küpü (25x34.3m): 2. katta +1.15m dışa çıkmalı (konsol) tamamen siyah
      giydirme cam cephe + altta beyaz konsol tavanı + düz beyaz parapetli çatıda 3x3 ışıklık ızgarası.
    - İki kütleyi bağlayan üst kat siyah çelik çapraz kafesli cam köprü (lib_gal_20.jpg)."""
    # b#139 kesin yerel eksenleri (v13 = (-74.33, -236.71)):
    # u = (+0.8099, +0.5866) (GD, Tarihi Hamam'a doğru), v = (-0.5866, +0.8099) (GB, Yemekhane'ye doğru)
    ox, oz = -74.33, -236.71
    ux, uz = 0.8099, 0.5866
    vx, vz = -0.5866, 0.8099
    yaw_u = math.atan2(uz, ux)
    y0 = h  # 10.5 m

    def P(lu, lv, y):
        return (ox + ux * lu + vx * lv, y, oz + uz * lu + vz * lv)

    def quad_box(u0, u1, v0, v1, ya, yb, color):
        pts = [(P(u0, v0, 0)[0], P(u0, v0, 0)[2]), (P(u1, v0, 0)[0], P(u1, v0, 0)[2]),
               (P(u1, v1, 0)[0], P(u1, v1, 0)[2]), (P(u0, v1, 0)[0], P(u0, v1, 0)[2])]
        b.prism(pts, ya, yb, color)

    def slope_slab(a0, a1, r1, r0, thick, color, cen):
        up = lambda q: (q[0], q[1] + thick, q[2])
        b._add_faces(color, [
            [up(a0), up(a1), up(r1), up(r0)],
            [a0, r0, r1, a1],
            [a0, a1, up(a1), up(a0)],
            [r0, up(r0), up(r1), r1],
            [a0, up(a0), up(r0), r0],
            [a1, r1, up(r1), up(a1)],
        ], None, center=cen)

    def beam_3d(p0, p1, half_t, color):
        dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
        L_ = math.sqrt(dx * dx + dy * dy + dz * dz) or 1.0
        tx, ty, tz = dx / L_, dy / L_, dz / L_
        ref = (0.0, 1.0, 0.0) if abs(ty) < 0.9 else (1.0, 0.0, 0.0)
        ax, ay, az = norm(cross((tx, ty, tz), ref))
        bx, by, bz = norm(cross((tx, ty, tz), (ax, ay, az)))
        offs = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        r0 = [(p0[0] + (ax * ox_ + bx * oy_) * half_t, p0[1] + (ay * ox_ + by * oy_) * half_t, p0[2] + (az * ox_ + bz * oy_) * half_t) for ox_, oy_ in offs]
        r1 = [(p1[0] + (ax * ox_ + bx * oy_) * half_t, p1[1] + (ay * ox_ + by * oy_) * half_t, p1[2] + (az * ox_ + bz * oy_) * half_t) for ox_, oy_ in offs]
        faces = [list(reversed(r0)), r1] + [[r0[i], r0[(i + 1) % 4], r1[(i + 1) % 4], r1[i]] for i in range(4)]
        b._add_faces(color, faces, None, center=((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2))

    # 1) L-kanat koyu antrasit kenet metal beşik çatı (lib_ytu_2.jpg!)
    #    Arm A: u ∈ [-0.55, 67.65], v ∈ [-0.20, 18.30], mahya v = 9.05
    #    Arm B: u ∈ [-0.55, 18.50], v ∈ [-0.20, 73.70], mahya u = 9.05
    #    45° köşe birleşimi: dış köşe (-0.55, -0.20) -> mahya köşesi (9.05, 9.05) -> iç dere (18.50, 18.30)
    ye = y0 - 0.10
    yr = y0 + 2.75
    T = 0.24
    # Arm A dış (KD) eğimi
    slope_slab(P(-0.55, -0.20, ye), P(67.65, -0.20, ye), P(67.65, 9.05, yr), P(9.05, 9.05, yr), T, "lib_roof_dark", P(34.0, 4.4, ye + 1.2))
    # Arm A iç (avlu) eğimi
    slope_slab(P(18.50, 18.30, ye), P(67.65, 18.30, ye), P(67.65, 9.05, yr), P(9.05, 9.05, yr), T, "lib_roof_dark", P(40.0, 13.7, ye + 1.2))
    # Arm B dış (KB) eğimi
    slope_slab(P(-0.55, -0.20, ye), P(-0.55, 73.70, ye), P(9.05, 73.70, yr), P(9.05, 9.05, yr), T, "lib_roof_dark", P(4.2, 36.0, ye + 1.2))
    # Arm B iç (avlu) eğimi
    slope_slab(P(18.50, 18.30, ye), P(18.50, 73.70, ye), P(9.05, 73.70, yr), P(9.05, 9.05, yr), T, "lib_roof_dark", P(13.8, 44.0, ye + 1.2))

    # Beyaz üçgen kalkan duvarları (Arm A u=67.53 Tarihi Hamam ucu + Arm B v=73.54 GB ucu — lib_ytu_2.jpg & lib_mim_1.jpg!)
    # Arm A ucu: beyaz üçgen çerçeve + içinde koyu üçgen cam alınlık + orta beyaz taşıyıcı dikme
    for u_g, u_in in ((67.58, 67.15),):
        t0, t1, t2 = P(u_g, -0.10, ye), P(u_g, 18.20, ye), P(u_g, 9.05, yr)
        b0, b1, b2 = P(u_in, -0.10, ye), P(u_in, 18.20, ye), P(u_in, 9.05, yr)
        b._add_faces("lib_white", [[t0, t1, t2], [b0, b2, b1], [t0, b0, b2, t2], [t2, b2, b1, t1]], None, center=P(67.35, 9.05, ye + 0.8))
        # Gable içi 2 büyük koyu cam üçgen boşluğu (lib_ytu_2.jpg sağ alt!)
        for v_lo, v_hi in ((1.0, 8.2), (9.9, 17.1)):
            y_lo = ye + 0.05
            y_hi_l = ye + (yr - ye) * (1.0 - abs(v_lo - 9.05) / 9.15) - 0.35
            y_hi_r = ye + (yr - ye) * (1.0 - abs(v_hi - 9.05) / 9.15) - 0.35
            gf = [P(u_g + 0.05, v_lo, y_lo), P(u_g + 0.05, v_hi, y_lo), P(u_g + 0.05, v_hi, y_hi_r), P(u_g + 0.05, v_lo, y_hi_l)]
            b._add_faces("lib_glass_black", [gf], None, center=P(u_g - 0.3, (v_lo + v_hi) / 2, ye + 0.8))
    # Arm B ucu (v=73.54): saf beyaz üçgen alınlık (lib_mim_1.jpg sol uç!)
    t0, t1, t2 = P(-0.50, 73.60, ye), P(18.42, 73.60, ye), P(9.05, 73.60, yr)
    b0, b1, b2 = P(-0.50, 73.15, ye), P(18.42, 73.15, ye), P(9.05, 73.15, yr)
    b._add_faces("lib_white", [[t0, t1, t2], [b0, b2, b1], [t0, b0, b2, t2], [t2, b2, b1, t1]], None, center=P(9.0, 73.35, ye + 0.8))

    # Çatı eğimleri boyunca sıralı çatı ışıklıkları (lib_ytu_2.jpg!)
    # Arm A eğimleri (v = 4.6 ve v = 13.5 hizasında, u = 18..62 boyunca)
    for lu in (20.0, 29.0, 38.0, 47.0, 56.0, 63.0):
        for lv_s in (4.5, 13.6):
            y_s = ye + (yr - ye) * (1.0 - abs(lv_s - 9.05) / 9.25) + T
            quad_box(lu - 1.6, lu + 1.6, lv_s - 1.15, lv_s + 1.15, y_s - 0.20, y_s + 0.30, "lib_frame_black")
            quad_box(lu - 1.35, lu + 1.35, lv_s - 0.90, lv_s + 0.90, y_s + 0.28, y_s + 0.36, "lib_skylight")
    # Arm B eğimleri (u = 4.5 ve u = 13.6 hizasında, v = 22..68 boyunca)
    for lv in (23.0, 32.0, 41.0, 50.0, 59.0, 67.5):
        for lu_s in (4.5, 13.6):
            y_s = ye + (yr - ye) * (1.0 - abs(lu_s - 9.05) / 9.50) + T
            quad_box(lu_s - 1.15, lu_s + 1.15, lv - 1.6, lv + 1.6, y_s - 0.20, y_s + 0.30, "lib_frame_black")
            quad_box(lu_s - 0.90, lu_s + 0.90, lv - 1.35, lv + 1.35, y_s + 0.28, y_s + 0.36, "lib_skylight")

    # 2) Kare Özel Kullanımlar Küpü: 2. katta +1.15m dışa çıkmalı (konsol) SİYAH CAM KÜP + düz beyaz çatı + 3x3 ışıklık ızgarası!
    #    Taban footprint: u ∈ [25.35, 50.30], v ∈ [35.48, 69.78]
    cu0, cu1 = 24.30, 51.45
    cv0, cv1 = 34.40, 70.90
    # Konsol alt beyaz tavan tablası (lib_mim_1.jpg & lib_gal_19.jpg karakteristik beyaz alt çıkma!)
    quad_box(cu0, cu1, cv0, cv1, 4.10, 4.42, "lib_white")
    # Üst kat koyu reflekte cam küp kabuğu (4.42 -> 10.40 m, taban kutunun 1.1m dışına çıkmalı)
    # 4 dış cam şerit duvarı (içi zaten greybox gövdesi; dış konsol yakası gerçek 3B çıkma oluşturur)
    quad_box(cu0, cu1, cv1 - 1.25, cv1, 4.42, 10.42, "lib_glass_black")  # GB ön yüz
    quad_box(cu0, cu1, cv0, cv0 + 1.25, 4.42, 10.42, "lib_glass_black")  # KD avlu yüzü
    quad_box(cu1 - 1.25, cu1, cv0, cv1, 4.42, 10.42, "lib_glass_black")  # GD meydan yüzü
    quad_box(cu0, cu0 + 1.25, cv0, cv1, 4.42, 10.42, "lib_glass_black")  # KB köprü yüzü
    # Siyah cam küp ince yatay + dikey giydirme cam profilleri (lib_mim_1.jpg & lib_gal_19.jpg!)
    quad_box(cu0 - 0.08, cu1 + 0.08, cv0 - 0.08, cv1 + 0.08, 10.22, 10.52, "lib_frame_black")  # üst siyah alınlık
    for y_rib in (4.42, 5.92, 7.42, 8.92):
        # 4 kenar boyunca yatay ince kayıt şeridi
        quad_box(cu0 - 0.05, cu1 + 0.05, cv1 - 0.05, cv1 + 0.05, y_rib, y_rib + 0.09, "lib_frame_black")
        quad_box(cu0 - 0.05, cu1 + 0.05, cv0 - 0.05, cv0 + 0.05, y_rib, y_rib + 0.09, "lib_frame_black")
        quad_box(cu1 - 0.05, cu1 + 0.05, cv0 - 0.05, cv1 + 0.05, y_rib, y_rib + 0.09, "lib_frame_black")
        quad_box(cu0 - 0.05, cu0 + 0.05, cv0 - 0.05, cv1 + 0.05, y_rib, y_rib + 0.09, "lib_frame_black")
    for k in range(10):
        lu_m = cu0 + (cu1 - cu0) * k / 9.0
        for lv_m in (cv0, cv1):
            mx, _, mz = P(lu_m, lv_m, 0)
            b.box(mx, mz, 0.10, 0.14, 4.42, 10.42, "lib_frame_black", yaw_u)
    for k in range(12):
        lv_m = cv0 + (cv1 - cv0) * k / 11.0
        for lu_m in (cu0, cu1):
            mx, _, mz = P(lu_m, lv_m, 0)
            b.box(mx, mz, 0.14, 0.10, 4.42, 10.42, "lib_frame_black", yaw_u)

    # Düz beyaz çatı membranı + beyaz parapet kenarı + MERKEZİ 3x3 IŞIKLIK PLATFORMU (lib_ytu_2.jpg sol!)
    quad_box(cu0 + 0.15, cu1 - 0.15, cv0 + 0.15, cv1 - 0.15, 10.42, 10.62, "lib_white")
    # Parapet çerçevesi
    quad_box(cu0, cu1, cv0, cv0 + 0.45, 10.52, 10.92, "lib_white")
    quad_box(cu0, cu1, cv1 - 0.45, cv1, 10.52, 10.92, "lib_white")
    quad_box(cu0, cu0 + 0.45, cv0, cv1, 10.52, 10.92, "lib_white")
    quad_box(cu1 - 0.45, cu1, cv0, cv1, 10.52, 10.92, "lib_white")
    # Merkezi yükseltilmiş koyu metal ışıklık platformu (3x3 kare ışıklıklar — lib_ytu_2.jpg & lib_gal_12/13!)
    quad_box(31.5, 44.2, 44.5, 59.5, 10.62, 11.15, "lib_roof_dark")
    for iu in range(3):
        for iv in range(3):
            su = 33.6 + iu * 4.2
            sv = 47.0 + iv * 5.0
            quad_box(su - 1.35, su + 1.35, sv - 1.55, sv + 1.55, 11.15, 11.42, "lib_frame_black")
            quad_box(su - 1.10, su + 1.10, sv - 1.30, sv + 1.30, 11.40, 11.48, "lib_skylight")
    # İkinci küçük çatı ışıklık / tesisat bacası (lib_ytu_2.jpg sol ön)
    quad_box(35.8, 40.0, 62.0, 66.0, 10.62, 11.25, "lib_roof_seam")
    quad_box(36.3, 39.5, 62.5, 65.5, 11.25, 11.34, "lib_skylight")

    # 3) Üst kat siyah çelik çapraz kafesli cam köprü (u ∈ [18.2, 24.4], v ∈ [55.7, 65.7] — lib_gal_20.jpg!)
    quad_box(18.1, 24.5, 55.6, 65.8, 4.30, 4.98, "lib_white")
    quad_box(18.1, 24.5, 55.6, 65.8, 8.95, 9.48, "lib_frame_black")
    for lv_b in (55.65, 65.75):
        # Çapraz çelik kafes diyagonalleri (lib_gal_20.jpg!)
        beam_3d(P(18.4, lv_b, 5.0), P(20.4, lv_b, 8.9), 0.11, "lib_frame_black")
        beam_3d(P(20.4, lv_b, 8.9), P(22.4, lv_b, 5.0), 0.11, "lib_frame_black")
        beam_3d(P(22.4, lv_b, 5.0), P(24.3, lv_b, 8.9), 0.11, "lib_frame_black")


RECIPES = {"gable_hall": recipe_gable_hall, "library": recipe_library, "new_library": recipe_new_library, "domed": recipe_domed, "modern": recipe_modern, "historic": recipe_historic, "mosque": recipe_mosque, "kiosk": recipe_kiosk}


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
        h = float(spec.get("height", bdata.get("height", 10.0)))
        if "height" in spec:
            manifest.setdefault("heights", {})[spec["match"]] = h
        b = Builder()
        road_kinds = ("residential", "residential_oneway", "service", "parking_aisle")
        spec = dict(spec, _paths=[[tuple(q) for q in p["points"]] for p in grey.get("paths", []) if p.get("kind") not in road_kinds and p.get("kind") != "cycleway"])
        RECIPES[spec["recipe"]](b, poly, h, spec, random.Random(spec["id"]))
        tris = b.tri_count()
        assert tris <= MAX_TRIS, "%s: %d üçgen > %d" % (spec["id"], tris, MAX_TRIS)
        write_glb(os.path.join(out_dir, spec["id"] + ".glb"), spec["id"], b)
        manifest["buildings"][spec["match"]] = "res://assets/buildings/%s.glb" % spec["id"]
        if "_sign" in spec:
            manifest.setdefault("signs", {})[spec["match"]] = spec["_sign"]
        print("OK %s: %d üçgen" % (spec["id"], tris))
    paths_all = [(p.get("kind", ""), [tuple(q) for q in p["points"]]) for p in grey.get("paths", [])]
    manifest["free"] = []
    road_kinds = ("residential", "residential_oneway", "service", "parking_aisle")
    for g in spec_all.get("gates", []):
        c, u, kind = nearest_road(tuple(g["pos"]), paths_all)
        b = Builder()
        GATES[g["style"]](b, c, u, 5.0 if kind in road_kinds else 2.5)
        write_glb(os.path.join(out_dir, g["id"] + ".glb"), g["id"], b)
        manifest["free"].append("res://assets/buildings/%s.glb" % g["id"])
        print("OK kapı %s (%s yolu): %d üçgen" % (g["id"], kind, b.tri_count()))
    with open(os.path.join(ROOT, "game/data/landmarks.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
