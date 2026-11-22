"""Kutbi — YTÜ'ye özel efsanevi yıldız pet (reklam filmi + Talha'nın konsept görselleri, 2026-11-22).

Kullanım:  python tools/assets/make_kutbi.py
Çıktı   :  game/assets/characters/kutbi/kutbi.glb

Tasarım (referans görseller: tombul yuvarlak uçlu beş köşeli yıldız, lacivert gövde + beyaz takımyıldızı benekleri,
göğüste altın çerçeveli parlayan çekirdek, yıldız yansımalı iri gözler, küçük ağız, başının üstünde dönen 3 minik yıldız):
  - İskelet yok; düğüm animasyonları: Body (süzülme/eğilme/dönme), Orbit (minik yıldızların yörüngesi).
  - Animasyon adları CharacterDef'te eşlenir: Idle, Walk, Run, Dance, Jump, Wave, Yes, No.
  - Boy ~1 m (diğer petlerle aynı ölçek), yerden ~0.2 m yukarıda süzülür.
"""
import json
import math
import os
import random
import struct
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "game/assets/characters/kutbi/kutbi.glb")

NAVY = (0.10, 0.13, 0.32)
NAVY_DEEP = (0.06, 0.08, 0.22)
FRECKLE = (0.92, 0.93, 1.0)
EYE = (0.04, 0.05, 0.12)
SHINE = (1.0, 1.0, 1.0)
MOUTH = (0.55, 0.18, 0.25)
GOLD = (0.95, 0.72, 0.30)
CORE = (1.0, 0.86, 0.50)
STAR = (1.0, 0.85, 0.42)

CENTER_Y = 0.62     # gövde merkezi (yer 0)
R_BASE, R_AMP = 0.30, 0.21   # yıldız silueti: çukurlar R_BASE, uçlar R_BASE+R_AMP (tombul, kısa kollar)
SHAPE = 1.6                   # >1: uçlar dolgun ve yuvarlak, çukurlar geniş
DEPTH = 0.22        # yastık kalınlığının yarısı
SEG, RINGS = 80, 11
PROFILE = 0.6       # halka ölçeği cos(φ)^PROFILE


def star_r(theta):
    # tepe yukarıda (θ=90°); (1+cos)/2 üssüyle yumuşak, tombul uçlar (referans: deniz yıldızı değil peluş yıldız)
    c = math.cos(5.0 * (theta - math.pi / 2))
    return R_BASE + R_AMP * ((1.0 + c) / 2.0) ** SHAPE


class Mesh:
    """Renk başına üçgen listesi; düz gölgeleme (yüz normali)."""

    def __init__(self):
        self.tris = {}

    def tri(self, color, a, b, c, emissive=False):
        key = (color, emissive)
        n = _norm(_cross(_sub(b, a), _sub(c, a)))
        self.tris.setdefault(key, []).append((a, b, c, n))

    def quad(self, color, a, b, c, d, emissive=False):
        self.tri(color, a, b, c, emissive)
        self.tri(color, a, c, d, emissive)


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _norm(v):
    l = math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2) or 1.0
    return (v[0] / l, v[1] / l, v[2] / l)


def body(m, rng):
    """Yastık gibi şişkin yıldız: siluet halkaları z boyunca kosinüsle daralır, ön/arka uçlar tek noktada birleşir."""
    rows = []
    for k in range(1, RINGS):
        phi = math.pi * k / RINGS - math.pi / 2      # -90..90
        z = DEPTH * math.sin(phi)
        s = math.cos(phi) ** PROFILE                 # kenarlar dolgun kalsın
        row = []
        for i in range(SEG):
            th = 2 * math.pi * i / SEG
            r = star_r(th) * s
            row.append((r * math.cos(th), CENTER_Y + r * math.sin(th), z))
        rows.append(row)
    back, front = (0.0, CENTER_Y, -DEPTH), (0.0, CENTER_Y, DEPTH)
    def col(idx, y):
        t = (y - (CENTER_Y - 0.5)) / 1.0
        return NAVY if t > 0.45 else NAVY_DEEP

    for i in range(SEG):
        j = (i + 1) % SEG
        m.tri(NAVY_DEEP, back, rows[0][j], rows[0][i])
        m.tri(NAVY, front, rows[-1][i], rows[-1][j])
        for k in range(len(rows) - 1):
            a, b, c, d = rows[k][i], rows[k][j], rows[k + 1][j], rows[k + 1][i]
            m.quad(col(k * SEG + i, a[1]), a, b, c, d)


def freckles(m, rng, count=70):
    """Takımyıldızı benekleri: ön ve arka yüzeyde küçük beyaz noktalar (yüz/çekirdek bölgesi boş kalır)."""
    placed = 0
    while placed < count:
        th = rng.uniform(0, 2 * math.pi)
        rho = math.sqrt(rng.uniform(0.04, 0.85))
        x = star_r(th) * rho * math.cos(th)
        y = CENTER_Y + star_r(th) * rho * math.sin(th)
        side = 1 if rng.random() < 0.6 else -1
        if side > 0 and abs(x) < 0.2 and CENTER_Y - 0.28 < y < CENTER_Y + 0.17:
            continue  # gözler ve çekirdek
        z = side * (front_z(x, y) + 0.003)
        r = rng.uniform(0.006, 0.013)
        seg = 6
        for i in range(seg):
            a0, a1 = 2 * math.pi * i / seg, 2 * math.pi * (i + 1) / seg
            p0 = (x + r * math.cos(a0), y + r * math.sin(a0), z)
            p1 = (x + r * math.cos(a1), y + r * math.sin(a1), z)
            if side > 0:
                m.tri(FRECKLE, (x, y, z), p0, p1, True)
            else:
                m.tri(FRECKLE, (x, y, z), p1, p0, True)
        placed += 1


def blob(m, color, cx, cy, cz, rx, ry, rz, seg=10, rings=6, emissive=False, front_only=False):
    rows = []
    for k in range(1, rings):
        a = math.pi * k / rings - math.pi / 2
        rows.append([(cx + rx * math.cos(a) * math.cos(2 * math.pi * i / seg), cy + ry * math.sin(a),
                      cz + rz * math.cos(a) * math.sin(2 * math.pi * i / seg)) for i in range(seg)])
    bot, top = (cx, cy - ry, cz), (cx, cy + ry, cz)
    for i in range(seg):
        j = (i + 1) % seg
        m.tri(color, bot, rows[0][i], rows[0][j], emissive)
        m.tri(color, top, rows[-1][j], rows[-1][i], emissive)
        for k in range(len(rows) - 1):
            m.quad(color, rows[k][i], rows[k + 1][i], rows[k + 1][j], rows[k][j], emissive)


def disc(m, color, cx, cy, z, r, seg=20, emissive=False):
    c = (cx, cy, z)
    for i in range(seg):
        a0, a1 = 2 * math.pi * i / seg, 2 * math.pi * (i + 1) / seg
        m.tri(color, c, (cx + r * math.cos(a0), cy + r * math.sin(a0), z), (cx + r * math.cos(a1), cy + r * math.sin(a1), z), emissive)


def ring(m, color, cx, cy, z, r0, r1, depth, seg=24):
    for i in range(seg):
        a0, a1 = 2 * math.pi * i / seg, 2 * math.pi * (i + 1) / seg
        p = lambda r, a, zz: (cx + r * math.cos(a), cy + r * math.sin(a), zz)
        m.quad(color, p(r0, a0, z), p(r1, a0, z), p(r1, a1, z), p(r0, a1, z))             # ön yüz
        m.quad(color, p(r1, a0, z), p(r1, a0, z - depth), p(r1, a1, z - depth), p(r1, a1, z))  # dış kenar


def front_z(x, y):
    """Gövde ön yüzeyinin (x,y)'deki z'si: ρ = cos(φ)^PROFILE → z = DEPTH·sin(φ) (yüz parçaları yüzeye otursun)."""
    th = math.atan2(y - CENTER_Y, x)
    rho = min(math.hypot(x, y - CENTER_Y) / star_r(th), 1.0)
    c = rho ** (1.0 / PROFILE)
    return DEPTH * math.sqrt(max(0.0, 1.0 - c * c))


def face(m):
    for sx in (-1, 1):
        ex, ey = sx * 0.105, CENTER_Y + 0.07
        ez = front_z(ex, ey)
        blob(m, EYE, ex, ey, ez, 0.07, 0.078, 0.035, seg=14, rings=7)
        blob(m, SHINE, ex - 0.022, ey + 0.03, ez + 0.03, 0.02, 0.02, 0.01, seg=8, rings=4)
        blob(m, STAR, ex + 0.02, ey - 0.025, ez + 0.032, 0.012, 0.012, 0.006, seg=6, rings=3, emissive=True)
    mz = front_z(0.0, CENTER_Y + 0.0)
    blob(m, MOUTH, 0.0, CENTER_Y - 0.0, mz + 0.004, 0.028, 0.016, 0.01, seg=10, rings=4)
    cy = CENTER_Y - 0.13
    cz = front_z(0.0, cy) + 0.004
    ring(m, GOLD, 0.0, cy, cz, 0.07, 0.095, 0.03)
    disc(m, CORE, 0.0, cy, cz + 0.002, 0.072, emissive=True)


def flat_star(m, cx, cy, cz, r, thick=0.02, rot=0.0):
    pts = []
    for i in range(10):
        a = rot + math.pi / 2 + math.pi * i / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    f, b = cz + thick / 2, cz - thick / 2
    for i in range(10):
        j = (i + 1) % 10
        m.tri(STAR, (cx, cy, f), (pts[i][0], pts[i][1], f), (pts[j][0], pts[j][1], f), True)
        m.tri(STAR, (cx, cy, b), (pts[j][0], pts[j][1], b), (pts[i][0], pts[i][1], b), True)
        m.quad(STAR, (pts[i][0], pts[i][1], b), (pts[j][0], pts[j][1], b), (pts[j][0], pts[j][1], f), (pts[i][0], pts[i][1], f), True)


ORBIT_Y = CENTER_Y + 0.5
ORBIT_R = 0.3


def orbit(m):
    """Orbit düğümünün yerel uzayında (düğüm ORBIT_Y yüksekliğinde, y ekseninde döner)."""
    for k in range(3):
        a = 2 * math.pi * k / 3
        flat_star(m, ORBIT_R * math.cos(a), 0.03 * math.sin(3 * a), ORBIT_R * math.sin(a), 0.06, rot=a)


# ---------------- GLB ----------------
def quat_axis(axis, ang):
    s = math.sin(ang / 2)
    return (axis[0] * s, axis[1] * s, axis[2] * s, math.cos(ang / 2))


def quat_mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz)


def build_animations():
    """{ad: (süre, [(t, body_pos, body_rot_quat, body_scale, orbit_angle)])} — ara kareler doğrusal."""
    X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
    anims = {}

    def sample(name, dur, n, fn):
        anims[name] = (dur, [(dur * i / n,) + fn(i / n) for i in range(n + 1)])

    tau = 2 * math.pi
    sample("Idle", 2.4, 24, lambda u: ((0, 0.05 * math.sin(tau * u), 0), quat_axis(Z, 0.05 * math.sin(tau * u)), (1, 1, 1), tau * u))
    sample("Walk", 0.8, 16, lambda u: ((0, 0.07 * abs(math.sin(tau * u)), 0),
                                        quat_mul(quat_axis(X, 0.18), quat_axis(Z, 0.12 * math.sin(tau * u))), (1, 1, 1), tau * u * 0.7))
    sample("Run", 0.5, 12, lambda u: ((0, 0.1 * abs(math.sin(tau * u)), 0),
                                       quat_mul(quat_axis(X, 0.32), quat_axis(Z, 0.15 * math.sin(tau * u))), (1, 1, 1), tau * u))
    sample("Dance", 1.6, 32, lambda u: ((0, 0.12 * abs(math.sin(2 * tau * u)), 0), quat_axis(Y, tau * u),
                                         (1 + 0.06 * math.sin(2 * tau * u), 1 - 0.06 * math.sin(2 * tau * u), 1), 2 * tau * u))
    def jump(u):
        h = max(0.0, math.sin(math.pi * min(1.0, max(0.0, (u - 0.15) / 0.7))))
        sq = 0.12 * (math.sin(math.pi * u / 0.15) if u < 0.15 else (math.sin(math.pi * (u - 0.85) / 0.15) if u > 0.85 else 0))
        return ((0, 0.6 * h, 0), quat_axis(Y, tau * h * 0.5 if u > 0.15 else 0), (1 + sq, 1 - sq, 1 + sq), tau * u * 1.5)
    sample("Jump", 1.0, 24, jump)
    sample("Wave", 1.2, 24, lambda u: ((0, 0.04 * math.sin(tau * u), 0), quat_axis(Z, 0.28 * math.sin(2 * tau * u)), (1, 1, 1), tau * u))
    sample("Yes", 1.0, 20, lambda u: ((0, 0.03 * abs(math.sin(2 * tau * u)), 0), quat_axis(X, 0.25 * math.sin(2 * tau * u)), (1, 1, 1), tau * u))
    sample("No", 1.0, 20, lambda u: ((0, 0, 0), quat_axis(Y, 0.45 * math.sin(2 * tau * u)), (1, 1, 1), tau * u * 0.5))
    return anims


def write_glb(body_mesh, orbit_mesh, anims, path):
    blob_ = bytearray()
    views, accessors, materials, meshes = [], [], [], []

    def view(data, target=None):
        while len(blob_) % 4:
            blob_.append(0)
        v = {"buffer": 0, "byteOffset": len(blob_), "byteLength": len(data)}
        if target:
            v["target"] = target
        views.append(v)
        blob_.extend(data)
        return len(views) - 1

    def acc(data_fmt, values, typ, comp=5126, minmax=False):
        data = b"".join(struct.pack(data_fmt, *v) if isinstance(v, tuple) else struct.pack(data_fmt, v) for v in values)
        a = {"bufferView": view(data), "componentType": comp, "count": len(values), "type": typ}
        if minmax:
            dims = len(values[0]) if isinstance(values[0], tuple) else 1
            if dims == 1:
                a["min"], a["max"] = [min(values)], [max(values)]
            else:
                a["min"] = [min(v[i] for v in values) for i in range(dims)]
                a["max"] = [max(v[i] for v in values) for i in range(dims)]
        accessors.append(a)
        return len(accessors) - 1

    mat_index = {}

    def material(color, emissive):
        key = (color, emissive)
        if key not in mat_index:
            m = {"name": "kutbi_%d" % len(materials), "pbrMetallicRoughness": {
                "baseColorFactor": [color[0] ** 2.2, color[1] ** 2.2, color[2] ** 2.2, 1.0], "metallicFactor": 0.0,
                "roughnessFactor": 0.35 if color in (EYE, SHINE) else 0.8}}
            if emissive:
                m["emissiveFactor"] = [color[0], color[1], color[2]]
            materials.append(m)
            mat_index[key] = len(materials) - 1
        return mat_index[key]

    def mesh(mm, name):
        prims = []
        for (color, emissive), tris in mm.tris.items():
            pos, nrm = [], []
            for a, b, c, n in tris:
                pos += [a, b, c]
                nrm += [n, n, n]
            prims.append({"attributes": {"POSITION": acc("<3f", pos, "VEC3", minmax=True), "NORMAL": acc("<3f", nrm, "VEC3")},
                          "material": material(color, emissive)})
        meshes.append({"name": name, "primitives": prims})
        return len(meshes) - 1

    body_i, orbit_i = mesh(body_mesh, "Body"), mesh(orbit_mesh, "Orbit")
    nodes = [{"name": "Kutbi", "children": [1]},
             {"name": "Body", "mesh": body_i, "children": [2]},
             {"name": "Orbit", "mesh": orbit_i, "translation": [0, ORBIT_Y, 0]}]
    animations = []
    for name, (dur, keys) in anims.items():
        times = [k[0] for k in keys]
        t_acc = acc("<f", times, "SCALAR", minmax=True)
        samplers, channels = [], []

        def chan(node, path_, values, typ, fmt):
            samplers.append({"input": t_acc, "output": acc(fmt, values, typ), "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": node, "path": path_}})
        chan(1, "translation", [k[1] for k in keys], "VEC3", "<3f")
        chan(1, "rotation", [k[2] for k in keys], "VEC4", "<4f")
        chan(1, "scale", [k[3] for k in keys], "VEC3", "<3f")
        # yörünge: açıyı küçük adımlarla quaternion'a çevir (doğrusal ara değer 180°'den büyük atlamasın)
        chan(2, "rotation", [quat_axis((0, 1, 0), k[4]) for k in keys], "VEC4", "<4f")
        animations.append({"name": name, "samplers": samplers, "channels": channels})
    while len(blob_) % 4:
        blob_.append(0)
    gltf = {"asset": {"version": "2.0", "generator": "unipet make_kutbi.py"}, "scene": 0, "scenes": [{"nodes": [0]}],
            "nodes": nodes, "meshes": meshes, "materials": materials, "accessors": accessors,
            "bufferViews": views, "buffers": [{"byteLength": len(blob_)}], "animations": animations}
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob_)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(blob_), 0x004E4942) + bytes(blob_))


def main():
    rng = random.Random("kutbi")
    b, o = Mesh(), Mesh()
    body(b, rng)
    face(b)
    freckles(b, rng)
    orbit(o)
    tris = sum(len(v) for v in b.tris.values()) + sum(len(v) for v in o.tris.values())
    write_glb(b, o, build_animations(), OUT)
    print("OK kutbi: %d üçgen -> %s" % (tris, OUT))


if __name__ == "__main__":
    main()
