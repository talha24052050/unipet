"""Davutpaşa'ya özgü ağaçlar (low-poly GLB): çınar ve servi. Saf Python (make_landmarks.py'nin GLB yazıcısını kullanır).

Kullanım:  python tools/assets/make_trees.py
Çıktı   :  game/assets/props/tree_plane.glb, game/assets/props/tree_cypress.glb (taban orijinde, Y yukarı, metre)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_landmarks as L  # noqa: E402

L.COLORS.update({
    "plane_bark": (0.66, 0.62, 0.52),    # çınar: açık gri-bej, alacalı kabuk
    "plane_leaf": (0.36, 0.56, 0.22),
    "plane_leaf2": (0.44, 0.62, 0.26),
    "cypress_leaf": (0.17, 0.33, 0.20),  # servi: koyu yeşil
    "cypress_bark": (0.38, 0.29, 0.22),
})
MAX_TRIS = 700


def ico_blob(b, cx, cy, cz, r, color, rng, seg=7, rings=5, squash=0.8):
    """Topak taç: hafif bozulmuş küre (dışbükey, yüzler merkeze göre çevrilir)."""
    rows = []
    for k in range(1, rings):
        a = math.pi * k / rings - math.pi / 2
        row = []
        for i in range(seg):
            t = 2 * math.pi * (i + 0.5 * (k % 2)) / seg
            j = rng.uniform(0.88, 1.08)
            row.append((cx + r * j * math.cos(a) * math.cos(t), cy + r * squash * math.sin(a), cz + r * j * math.cos(a) * math.sin(t)))
        rows.append(row)
    bot, top = (cx, cy - r * squash, cz), (cx, cy + r * squash, cz)
    faces = [[bot, rows[0][(i + 1) % seg], rows[0][i]] for i in range(seg)]
    for k in range(len(rows) - 1):
        faces += [[rows[k][i], rows[k][(i + 1) % seg], rows[k + 1][(i + 1) % seg], rows[k + 1][i]] for i in range(seg)]
    faces += [[rows[-1][i], rows[-1][(i + 1) % seg], top] for i in range(seg)]
    b._add_faces(color, faces, None, center=(cx, cy, cz))


def plane_tree(seed):
    rng = random.Random(seed)
    b = L.Builder()
    # Kalın gövde + 3 ana dal
    b.cylinder(0, 0, 0.45, 0, 3.2, "plane_bark", seg=7)
    b.cylinder(0, 0, 0.36, 3.2, 5.0, "plane_bark", seg=7)
    blobs = [(0.0, 9.2, 0.0, 3.6)]
    for k in range(3):
        ang = 2 * math.pi * k / 3 + rng.uniform(-0.3, 0.3)
        dx, dz = math.cos(ang), math.sin(ang)
        bx, bz = dx * 1.6, dz * 1.6
        b.cylinder(bx * 0.5, bz * 0.5, 0.2, 4.6, 6.6, "plane_bark", seg=5)
        blobs.append((dx * 2.8, rng.uniform(7.2, 8.2), dz * 2.8, rng.uniform(2.8, 3.3)))
    for i, (x, y, z, r) in enumerate(blobs):
        ico_blob(b, x, y, z, r, "plane_leaf" if i % 2 == 0 else "plane_leaf2", rng)
    return b


def cypress_tree(seed):
    rng = random.Random(seed)
    b = L.Builder()
    b.cylinder(0, 0, 0.18, 0, 1.0, "cypress_bark", seg=5)
    # İnce uzun servi: üst üste iki koni (siluet daha doğal)
    b.cylinder(0, 0, 1.05, 0.7, 7.5, "cypress_leaf", seg=8, cone=True)
    b.cylinder(rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), 0.85, 3.5, 10.5, "cypress_leaf", seg=7, cone=True)
    return b


def main():
    out = os.path.join(L.ROOT, "game/assets/props")
    for name, b in (("tree_plane", plane_tree("cinar")), ("tree_cypress", cypress_tree("servi"))):
        tris = b.tri_count()
        assert tris <= MAX_TRIS, "%s: %d üçgen" % (name, tris)
        L.write_glb(os.path.join(out, name + ".glb"), name, b)
        print("OK %s: %d üçgen" % (name, tris))


if __name__ == "__main__":
    main()
