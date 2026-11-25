"""Sami — YTÜ Davutpaşa Kampüsü (Tarihi Hamam / ARTLAB) 3B Voksel Chibi NPC modeli.

Kullanım:  python tools/assets/make_sami.py
Çıktı   :  game/assets/npcs/sami/sami.glb

Referans (8 açılı piksel-art turnaround):
  - Büyük chibi kafa, dağınık kıvırcık/dikenli siyah saç, dikdörtgen siyah çerçeveli gözlük + mavi-lacivert gözler,
    ince bıyık ve kirli sakal gölgesi, koyu lacivert bisiklet yaka tişört ve pantolon, kırmızı-beyaz spor ayakkabılar.
  - 6 eklemli düğüm (Body, Head, ArmL, ArmR, LegL, LegR) + açgözlü yüzey birleştirme (greedy meshing) ile
    keskin kübik 3B voksel görünümü korunurken üçgen sayısı düşük tutulur.
  - Animasyonlar: Idle, Wave, Talk, Walk, Jump.
"""
import json
import math
import os
import struct

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "game/assets/npcs/sami/sami.glb")

VOX = 0.026  # 1 voksel = 2.6 cm -> toplam boy ~1.40 m

# sRGB renk paleti (referans görselden örneklenmiştir)
C_HAIR = (0.07, 0.08, 0.11)
C_HAIR_HI = (0.16, 0.19, 0.25)
C_FRAME = (0.08, 0.09, 0.12)
C_SKIN = (0.96, 0.70, 0.56)
C_SKIN_SH = (0.87, 0.60, 0.46)
C_STUBBLE_LT = (0.76, 0.54, 0.43)
C_STUBBLE_DK = (0.50, 0.36, 0.29)
C_MOUTH = (0.64, 0.34, 0.29)
C_EYE_WHITE = (0.98, 0.99, 1.00)
C_EYE_BLUE = (0.13, 0.27, 0.44)
C_EYE_PUPIL = (0.06, 0.12, 0.22)
C_SHIRT = (0.13, 0.15, 0.23)
C_SHIRT_SH = (0.09, 0.11, 0.17)
C_PANTS = (0.15, 0.18, 0.28)
C_PANTS_SH = (0.11, 0.13, 0.21)
C_SHOE_RED = (0.74, 0.17, 0.18)
C_SHOE_WHITE = (0.97, 0.98, 0.99)
C_SOLE = (0.10, 0.11, 0.14)


class VoxelGrid:
    """(x, y, z) tamsayı voksel ızgarası -> gizli iç yüzey eleme + 2B greedy meshing."""

    def __init__(self):
        self.voxels = {}

    def set(self, x, y, z, color):
        self.voxels[(int(x), int(y), int(z))] = color

    def fill(self, x0, x1, y0, y1, z0, z1, color):
        for x in range(int(x0), int(x1) + 1):
            for y in range(int(y0), int(y1) + 1):
                for z in range(int(z0), int(z1) + 1):
                    self.voxels[(x, y, z)] = color

    def erase(self, x0, x1, y0, y1, z0, z1):
        for x in range(int(x0), int(x1) + 1):
            for y in range(int(y0), int(y1) + 1):
                for z in range(int(z0), int(z1) + 1):
                    self.voxels.pop((x, y, z), None)

    def to_tris(self, origin_vox=(0.0, 0.0, 0.0)):
        """Renk -> [(a, b, c, normal)] listesi. Bitişik aynı renkli yüzeyleri dikdörtgenlerde birleştirir."""
        ox, oy, oz = origin_vox
        tris_by_col = {}
        # 6 yön: (normal, sabit_eksen, u_eksen, v_eksen, sarım_ters_mi)
        dirs = [
            ((1, 0, 0), 0, 2, 1, True),
            ((-1, 0, 0), 0, 2, 1, False),
            ((0, 1, 0), 1, 0, 2, True),
            ((0, -1, 0), 1, 0, 2, False),
            ((0, 0, 1), 2, 0, 1, False),
            ((0, 0, -1), 2, 0, 1, True),
        ]
        for nrm, ax_w, ax_u, ax_v, flip in dirs:
            planes = {}
            step_w = nrm[ax_w]
            for pos, col in self.voxels.items():
                nb = (pos[0] + nrm[0], pos[1] + nrm[1], pos[2] + nrm[2])
                if nb in self.voxels:
                    continue
                w = pos[ax_w] + (1 if step_w > 0 else 0)
                planes.setdefault(w, {})[(pos[ax_u], pos[ax_v])] = col

            for w, grid2d in planes.items():
                if not grid2d:
                    continue
                us = [k[0] for k in grid2d]
                vs = [k[1] for k in grid2d]
                u_min, u_max = min(us), max(us)
                v_min, v_max = min(vs), max(vs)
                visited = set()
                for v in range(v_min, v_max + 1):
                    for u in range(u_min, u_max + 1):
                        if (u, v) in visited or (u, v) not in grid2d:
                            continue
                        col = grid2d[(u, v)]
                        u_end = u
                        while (u_end + 1, v) in grid2d and (u_end + 1, v) not in visited and grid2d[(u_end + 1, v)] == col:
                            u_end += 1
                        v_end = v
                        while True:
                            ok = True
                            for uu in range(u, u_end + 1):
                                if (uu, v_end + 1) not in grid2d or (uu, v_end + 1) in visited or grid2d[(uu, v_end + 1)] != col:
                                    ok = False
                                    break
                            if not ok:
                                break
                            v_end += 1
                        for vv in range(v, v_end + 1):
                            for uu in range(u, u_end + 1):
                                visited.add((uu, vv))

                        def pt(uu, vv):
                            c = [0.0, 0.0, 0.0]
                            c[ax_w] = float(w)
                            c[ax_u] = float(uu)
                            c[ax_v] = float(vv)
                            return ((c[0] - ox) * VOX, (c[1] - oy) * VOX, (c[2] - oz) * VOX)

                        p00 = pt(u, v)
                        p10 = pt(u_end + 1, v)
                        p11 = pt(u_end + 1, v_end + 1)
                        p01 = pt(u, v_end + 1)
                        nf = (float(nrm[0]), float(nrm[1]), float(nrm[2]))
                        lst = tris_by_col.setdefault(col, [])
                        if not flip:
                            lst.append((p00, p10, p11, nf))
                            lst.append((p00, p11, p01, nf))
                        else:
                            lst.append((p00, p11, p10, nf))
                            lst.append((p00, p01, p11, nf))
        return tris_by_col


def build_head():
    """Chibi kafa (boyun eklemi y=0, x=0, z=0). +Z = yüz önü, +Y = yukarı."""
    g = VoxelGrid()

    # 1) Yuvarlatılmış kübik kafa çekirdeği: x in -11..11 (23), y in 1..25 (25), z in -9..9 (19)
    for y in range(1, 26):
        # Alt çene ve en üst kafa kubbesinde hafif pah (chibi yuvarlaklığı)
        trim_y = 2 if y == 1 else (1 if y in (2, 24, 25) else 0)
        for x in range(-11, 12):
            for z in range(-9, 10):
                # Yatay köşe pahı: tam dikdörtgen kutu değil, piksel-art kavisli 3B kafa
                corner = max(0, abs(x) - 8) + max(0, abs(z) - 6)
                if corner > 3 - trim_y:
                    continue
                if abs(x) == 11 and abs(z) >= 6:
                    continue
                col = C_SKIN
                if y <= 2 or z <= -4 or (abs(x) >= 10 and y <= 6):
                    col = C_SKIN_SH
                g.set(x, y, z, col)

    # 2) Kirli sakal (5-o'clock shadow) dokusu — çene altı, yanak altı ve favoriye çıkan diyagonal hat
    for y in range(2, 10):
        for x in range(-10, 11):
            for z in range(1, 10):
                if (x, y, z) not in g.voxels:
                    continue
                # Yalnızca dış yüzeye oturan deri voksellerini renklendir
                if (x, y, z + 1) in g.voxels and (x + (1 if x >= 0 else -1), y, z) in g.voxels:
                    continue
                in_jaw_band = (y <= 4 and z >= 4) or (abs(x) >= 7 and 4 <= y <= 9 and z >= 2)
                if in_jaw_band and ((x * 3 + y * 5 + z * 7) % 3 == 0):
                    g.set(x, y, z, C_STUBBLE_LT)

    # 3) Bıyık ve samimi gülümseme (ön yüzey z=9 ve hafif kabartma z=10)
    # Kavisli bıyık: y=7..8, x=-5..5
    for x in range(-5, 6):
        my = 8 if abs(x) <= 3 else 7
        g.set(x, my, 9, C_STUBBLE_DK)
        if abs(x) <= 4:
            g.set(x, my, 10, C_STUBBLE_DK)
    # Gülümseyen ağız: y=5..6
    for x in range(-3, 4):
        ay = 5 if abs(x) <= 2 else 6
        g.set(x, ay, 9, C_MOUTH)
    # Alt dudak altı hafif keçi sakalı gölgesi
    for x in (-1, 0, 1):
        g.set(x, 3, 9, C_STUBBLE_DK if x == 0 else C_STUBBLE_LT)

    # 4) 3B çıkıntılı küçük chibi burun (y=9..11, x=-1..1, z=10)
    for y in (9, 10, 11):
        for x in (-1, 0, 1):
            if y == 11 and x != 0:
                continue
            g.set(x, y, 10, C_SKIN if y >= 10 else C_SKIN_SH)

    # 5) İri mavi-lacivert chibi gözler + beyaz parlama (y=11..15, sol/sağ: x=±3..±8, z=9)
    for sx in (-1, 1):
        # Göz akı tabanı
        for gx in range(3, 9):
            for gy in range(11, 16):
                g.set(sx * gx, gy, 9, C_EYE_WHITE)
        # İris (göz bebeği merkeze hafif yakın, canlı bakış)
        iris_cols = [4, 5, 6, 7]
        for gx in iris_cols:
            for gy in range(11, 15):
                is_pupil = gx in (5, 6) and gy in (12, 13)
                g.set(sx * gx, gy, 9, C_EYE_PUPIL if is_pupil else C_EYE_BLUE)
        # Sol-üst piksel parlama (catchlight — tüm 8 referans karedeki ikonik beyaz parıltı!)
        shine_x = sx * 4 if sx > 0 else sx * 7
        g.set(shine_x, 14, 9, C_EYE_WHITE)
        g.set(shine_x, 13, 9, C_EYE_WHITE)

    # 6) Kalın siyah kaşlar (y=17..18, x=±3..±9, z=9..10)
    for sx in (-1, 1):
        for gx in range(3, 10):
            by = 18 if gx <= 7 else 17
            g.set(sx * gx, by, 9, C_HAIR)
            g.set(sx * gx, by, 10, C_HAIR)

    # 7) 3B Dikdörtgen Siyah Çerçeveli Gözlük (z=10..11 ön çerçeve + z=0..10 yan saplar!)
    for sx in (-1, 1):
        # Üst ve alt çerçeve çıtaları (x=2..10, y=16 üst ve y=10 alt)
        for gx in range(2, 11):
            g.set(sx * gx, 16, 10, C_FRAME)
            g.set(sx * gx, 16, 11, C_FRAME)
            if 3 <= gx <= 9:
                g.set(sx * gx, 10, 10, C_FRAME)
                g.set(sx * gx, 10, 11, C_FRAME)
        # İç ve dış dikey çerçeve kenarları (x=2 ve x=10, y=11..15)
        for gy in range(11, 16):
            g.set(sx * 2, gy, 10, C_FRAME)
            g.set(sx * 10, gy, 10, C_FRAME)
            g.set(sx * 10, gy, 11, C_FRAME)
        # Yan gözlük sapları (kulak üstüne kadar uzanır: x=±11..±12, y=14..15, z=0..10)
        for gz in range(0, 11):
            wx = 11 if abs(gz) >= 7 else 12
            g.set(sx * wx, 15, gz, C_FRAME)
            if gz >= 7:
                g.set(sx * 11, 15, gz, C_FRAME)
    # Burun köprüsü (x=-2..2, y=14..15, z=10..11)
    for bx in range(-2, 3):
        g.set(bx, 15, 10, C_FRAME)
        g.set(bx, 15, 11, C_FRAME)

    # 8) 3B Chibi Kulaklar (x=±12..±13, y=10..15, z=-2..2)
    for sx in (-1, 1):
        for ey in range(10, 16):
            for ez in range(-2, 3):
                if (ey in (10, 15)) and abs(ez) == 2:
                    continue
                g.set(sx * 12, ey, ez, C_SKIN if ez >= 0 else C_SKIN_SH)
                if 11 <= ey <= 14 and -1 <= ez <= 1:
                    g.set(sx * 13, ey, ez, C_SKIN_SH if ez == 0 and ey in (12, 13) else C_SKIN)

    # 9) Dağınık Kıvırcık / Dikenli Siyah Saçlar (üst kubbe, alın perçemleri, favoriler ve kabarık arka saç)
    def hair_col(x, y, z):
        # Kıvırcık bukle dokusu için koyu antrasit parlama vokselleri
        h = (x * 7 + y * 13 + z * 5) % 17
        return C_HAIR_HI if h in (0, 5) and y >= 16 else C_HAIR

    # Üst saç kütlesi (y=23..31)
    for y in range(23, 32):
        ry = (y - 23) / 8.0
        max_x = int(round(13.0 - ry * 4.5))
        max_z_f = int(round(11.0 - ry * 4.0))
        max_z_b = int(round(11.5 - ry * 4.0))
        for x in range(-max_x, max_x + 1):
            for z in range(-max_z_b, max_z_f + 1):
                if (x / max(1.0, max_x + 0.6)) ** 2 + (z / max(1.0, max_z_b + 0.6)) ** 2 <= 1.08:
                    g.set(x, y, z, hair_col(x, y, z))

    # Üstteki ikonik dağınık/dikenli saç tutamları (y=31..35 — referans karelerdeki sivri kıvrımlar!)
    tufts = [
        (0, 32, 3, 2, 3, 2),
        (-5, 32, 2, 2, 3, 2),
        (5, 32, 1, 2, 3, 2),
        (-9, 30, 0, 2, 3, 2),
        (9, 30, 1, 2, 3, 2),
        (-3, 32, -4, 2, 3, 2),
        (4, 32, -3, 2, 3, 2),
        (0, 31, -7, 3, 2, 2),
        (-7, 29, 6, 2, 2, 2),
        (7, 29, 6, 2, 2, 2),
    ]
    for cx, cy, cz, rx, ry, rz in tufts:
        for dx in range(-rx, rx + 1):
            for dy in range(0, ry + 1):
                for dz in range(-rz, rz + 1):
                    if abs(dx) + dy + abs(dz) <= rx + ry:
                        g.set(cx + dx, cy + dy, cz + dz, hair_col(cx + dx, cy + dy, cz + dz))

    # Alın üstü asimetrik perçemler (y=19..24, z=9..11 — kaşların hemen üstüne inen doğal tutamlar)
    bang_heights = {
        -10: 20, -9: 21, -8: 22, -7: 21, -6: 22, -5: 20, -4: 22, -3: 23,
        -2: 21, -1: 20, 0: 21, 1: 22, 2: 20, 3: 21, 4: 23, 5: 22,
        6: 21, 7: 22, 8: 21, 9: 21, 10: 20,
    }
    for bx, y_low in bang_heights.items():
        for by in range(y_low, 25):
            g.set(bx, by, 9, hair_col(bx, by, 9))
            if by >= y_low + 1:
                g.set(bx, by, 10, hair_col(bx, by, 10))

    # Yan saçlar & favoriler (kulak önü z=3..6, y=13..24 ve kulak arkası/üstü)
    for sx in (-1, 1):
        for y in range(15, 25):
            for z in range(-9, 9):
                if abs(z) <= 7 or y >= 19:
                    g.set(sx * 12, y, z, hair_col(sx * 12, y, z))
                if y >= 20 and abs(z) <= 6:
                    g.set(sx * 13, y, z, hair_col(sx * 13, y, z))
        # Favori (kulak önünde y=12..16, z=3..5)
        for fy in range(12, 17):
            for fz in (3, 4, 5):
                if fy == 12 and fz == 5:
                    continue
                g.set(sx * 11, fy, fz, C_HAIR)
                if fy >= 14:
                    g.set(sx * 12, fy, fz, C_HAIR)

    # Arka kabarık kıvırcık saç kütlesi ve ense kesimi (z=-11..-7, y=5..25 — yan profillerle birebir!)
    for y in range(5, 25):
        t = max(0.0, (14 - y) / 9.0)  # aşağı indikçe enseye doğru daralır
        max_x = int(round(12.0 - t * 4.5))
        back_z = -11 if 12 <= y <= 23 else (-10 if y >= 8 else -9)
        for x in range(-max_x, max_x + 1):
            for z in range(back_z, -6):
                if abs(x) == max_x and z == back_z:
                    continue
                g.set(x, y, z, hair_col(x, y, z))
        # Kulak arkası yan ense dolgusu
        if y >= 8:
            for sx in (-1, 1):
                for z in range(-8, -2):
                    if abs(sx * max_x) >= 9:
                        g.set(sx * (max_x - 1), y, z, hair_col(sx * max_x, y, z))

    return g.to_tris(origin_vox=(0.5, 0.0, 0.5))


def build_torso():
    """Gövde + Boyun + Bel (pivot kalça hizasında y=0, boyun üstü y=9)."""
    g = VoxelGrid()
    # Alt kalça / pantolon beli (y=0..1, x=-5..5, z=-3..3)
    for y in (0, 1):
        for x in range(-5, 6):
            for z in range(-3, 4):
                if abs(x) == 5 and abs(z) == 3:
                    continue
                g.set(x, y, z, C_PANTS if z >= -1 else C_PANTS_SH)

    # Koyu lacivert tişört gövdesi (y=2..9, x=-6..6, z=-4..4)
    for y in range(2, 10):
        for x in range(-6, 7):
            for z in range(-4, 5):
                if abs(x) == 6 and abs(z) == 4:
                    continue
                col = C_SHIRT_SH if (abs(x) == 6 or z == -4 or y == 2) else C_SHIRT
                g.set(x, y, z, col)

    # Bisiklet yaka ön açıklığı + boyun (y=9..11)
    for x in (-2, -1, 0, 1, 2):
        g.set(x, 9, 4, C_SKIN_SH if abs(x) == 2 else C_SKIN)
    for y in (9, 10, 11):
        for x in range(-3, 4):
            for z in range(-2, 3):
                g.set(x, y, z, C_SKIN_SH)

    return g.to_tris(origin_vox=(0.5, 0.0, 0.5))


def build_arm(is_left):
    """Kısa tişört kolu + chibi kol/el (omuz pivotu (0, 0, 0))."""
    g = VoxelGrid()
    # Kısa lacivert kol ağzı (y=-2..1, x=-1..2, z=-2..2)
    for y in range(-2, 2):
        for x in range(-1, 2):
            for z in range(-2, 3):
                if abs(z) == 2 and y == 1 and x != 0:
                    continue
                g.set(x, y, z, C_SHIRT if z >= -1 else C_SHIRT_SH)
    # Ön kol ve el (y=-7..-3, x=-1..1, z=-1..2)
    for y in range(-7, -2):
        for x in range(-1, 2):
            for z in range(-1, 2):
                inner = (is_left and x == -1) or ((not is_left) and x == 1)
                g.set(x, y, z, C_SKIN_SH if (inner or y == -7) else C_SKIN)
    return g.to_tris(origin_vox=(0.5, 0.5, 0.5))


def build_leg():
    """Koyu lacivert pantolon bacağı + kırmızı-beyaz spor ayakkabı (kalça pivotu (0, 0, 0))."""
    g = VoxelGrid()
    # Pantolon (y=-4..0, x=-2..1, z=-2..2)
    for y in range(-4, 1):
        for x in range(-2, 2):
            for z in range(-2, 3):
                if abs(z) == 2 and (x in (-2, 1)):
                    continue
                g.set(x, y, z, C_PANTS if z >= 0 else C_PANTS_SH)

    # Kırmızı-beyaz spor ayakkabı (y=-8..-5, arkadan öne z=-2..4 -> burun +Z yönünde!)
    # y=-5: bilek & beyaz dil detayı
    for x in range(-2, 2):
        for z in range(-2, 3):
            col = C_SHOE_WHITE if (z == 2 and x in (-1, 0)) else C_SHOE_RED
            g.set(x, -5, z, col)
    # y=-6: kırmızı gövde + beyaz burun ucu
    for x in range(-2, 2):
        for z in range(-2, 5):
            if z == 4 and x in (-2, 1):
                continue
            col = C_SHOE_WHITE if z >= 3 else C_SHOE_RED
            g.set(x, -6, z, col)
    # y=-7: bembeyaz kauçuk orta taban
    for x in range(-2, 2):
        for z in range(-2, 5):
            if z == 4 and x in (-2, 1):
                continue
            g.set(x, -7, z, C_SHOE_WHITE)
    # y=-8: koyu alt taban (yer = y_world 0.0!)
    for x in range(-2, 2):
        for z in range(-2, 5):
            if z == 4 and x in (-2, 1):
                continue
            g.set(x, -8, z, C_SOLE)

    return g.to_tris(origin_vox=(0.0, 0.0, 0.5))


# ---------------- GLB & Animasyon Üretimi ----------------

def quat_axis(axis, ang):
    s = math.sin(ang * 0.5)
    return (axis[0] * s, axis[1] * s, axis[2] * s, math.cos(ang * 0.5))


def quat_euler_xyz(rx, ry, rz):
    qx = quat_axis((1, 0, 0), rx)
    qy = quat_axis((0, 1, 0), ry)
    qz = quat_axis((0, 0, 1), rz)
    return quat_mul(qy, quat_mul(qx, qz))


def quat_mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    )


# Düğüm indeksleri:
# 0: Sami (root)
# 1: Body   (pos: 0, 8*VOX, 0)
# 2: Head   (child of Body, pos: 0, 9.5*VOX, 0)
# 3: ArmL   (child of Body, pos: +7.8*VOX, 7.8*VOX, 0)
# 4: ArmR   (child of Body, pos: -7.8*VOX, 7.8*VOX, 0)
# 5: LegL   (child of Sami, pos: +2.6*VOX, 8*VOX, 0)
# 6: LegR   (child of Sami, pos: -2.6*VOX, 8*VOX, 0)

BODY_BASE_Y = 8.0 * VOX


def build_animations():
    tau = 2.0 * math.pi
    anims = {}

    def sample(name, dur, steps, fn):
        anims[name] = (dur, [(dur * i / steps,) + fn(i / steps) for i in range(steps + 1)])

    # 1) Idle: doğal nefes alıp verme, meraklı chibi kafa bakışı ve hafif kol salınımı
    def idle_fn(u):
        bob = 0.008 * math.sin(tau * u)
        body_rot = quat_euler_xyz(0.0, 0.03 * math.sin(tau * u), 0.0)
        head_rot = quat_euler_xyz(0.04 * math.sin(tau * u), 0.14 * math.sin(tau * u), 0.03 * math.cos(tau * u))
        arm_l = quat_euler_xyz(0.05 * math.sin(tau * u), 0.0, 0.08)
        arm_r = quat_euler_xyz(-0.05 * math.sin(tau * u), 0.0, -0.08)
        id_q = (0.0, 0.0, 0.0, 1.0)
        return ((0.0, BODY_BASE_Y + bob, 0.0), body_rot, head_rot, arm_l, arm_r,
                (2.6 * VOX, BODY_BASE_Y, 0.0), id_q, (-2.6 * VOX, BODY_BASE_Y, 0.0), id_q)

    sample("Idle", 2.8, 28, idle_fn)

    # 2) Wave: sağ kolunu (-X = karakterin sağ eli!) kaldırıp neşeyle el sallar
    def wave_fn(u):
        env = math.sin(math.pi * 0.5 * min(1.0, u / 0.12)) if u < 0.12 else (math.sin(math.pi * 0.5 * (1.0 - u) / 0.14) if u > 0.86 else 1.0)
        bob = 0.018 * abs(math.sin(2.0 * tau * u))
        body_rot = quat_euler_xyz(0.0, 0.06 * env, 0.04 * env)
        head_rot = quat_euler_xyz(-0.06 * env, 0.08 * math.sin(2.0 * tau * u), -0.10 * env)
        arm_l = quat_euler_xyz(0.08, 0.0, 0.12)
        # Sağ kol yukarı kalkar (z ekseninde -2.48 rad dışa-yukarı + el sallama salınımı)
        wave_osc = 0.38 * math.sin(3.0 * tau * u) * env
        arm_r = quat_euler_xyz(-0.28 * env, 0.0, (-2.48 * env) + wave_osc)
        id_q = (0.0, 0.0, 0.0, 1.0)
        return ((0.0, BODY_BASE_Y + bob, 0.0), body_rot, head_rot, arm_l, arm_r,
                (2.6 * VOX, BODY_BASE_Y, 0.0), id_q, (-2.6 * VOX, BODY_BASE_Y, 0.0), id_q)

    sample("Wave", 1.5, 30, wave_fn)

    # 3) Talk: anlatırken kafa onayı ve iki kolla canlı anlatım jestleri
    def talk_fn(u):
        bob = 0.012 * abs(math.sin(2.0 * tau * u))
        body_rot = quat_euler_xyz(0.02 * math.sin(2.0 * tau * u), 0.06 * math.sin(tau * u), 0.0)
        head_rot = quat_euler_xyz(0.11 * math.sin(3.0 * tau * u), 0.12 * math.sin(tau * u), 0.06 * math.sin(2.0 * tau * u))
        arm_l = quat_euler_xyz(-0.55 - 0.25 * math.sin(2.0 * tau * u), 0.0, 0.18)
        arm_r = quat_euler_xyz(-0.55 + 0.25 * math.sin(2.0 * tau * u), 0.0, -0.18)
        id_q = (0.0, 0.0, 0.0, 1.0)
        return ((0.0, BODY_BASE_Y + bob, 0.0), body_rot, head_rot, arm_l, arm_r,
                (2.6 * VOX, BODY_BASE_Y, 0.0), id_q, (-2.6 * VOX, BODY_BASE_Y, 0.0), id_q)

    sample("Talk", 1.8, 28, talk_fn)

    # 4) Walk: canlı chibi yürüyüş döngüsü
    def walk_fn(u):
        s = math.sin(tau * u)
        bob = 0.022 * abs(math.cos(tau * u))
        body_rot = quat_euler_xyz(0.05, 0.06 * s, 0.03 * s)
        head_rot = quat_euler_xyz(-0.03 * abs(s), -0.05 * s, -0.03 * s)
        arm_l = quat_euler_xyz(0.55 * s, 0.0, 0.10)
        arm_r = quat_euler_xyz(-0.55 * s, 0.0, -0.10)
        leg_l = quat_euler_xyz(-0.58 * s, 0.0, 0.0)
        leg_r = quat_euler_xyz(0.58 * s, 0.0, 0.0)
        return ((0.0, BODY_BASE_Y + bob, 0.0), body_rot, head_rot, arm_l, arm_r,
                (2.6 * VOX, BODY_BASE_Y + bob * 0.4, 0.0), leg_l, (-2.6 * VOX, BODY_BASE_Y + bob * 0.4, 0.0), leg_r)

    sample("Walk", 0.76, 20, walk_fn)

    # 5) Jump: heyecanlı zıplama
    def jump_fn(u):
        air = max(0.0, math.sin(math.pi * min(1.0, max(0.0, (u - 0.12) / 0.76))))
        h = 0.24 * air
        body_rot = quat_euler_xyz(-0.08 * air, 0.0, 0.0)
        head_rot = quat_euler_xyz(-0.12 * air, 0.0, 0.0)
        arm_l = quat_euler_xyz(-0.25 * air, 0.0, 2.2 * air + 0.1)
        arm_r = quat_euler_xyz(-0.25 * air, 0.0, -2.2 * air - 0.1)
        leg_l = quat_euler_xyz(0.22 * air, 0.0, 0.06 * air)
        leg_r = quat_euler_xyz(-0.18 * air, 0.0, -0.06 * air)
        return ((0.0, BODY_BASE_Y + h, 0.0), body_rot, head_rot, arm_l, arm_r,
                (2.6 * VOX, BODY_BASE_Y + h, 0.0), leg_l, (-2.6 * VOX, BODY_BASE_Y + h, 0.0), leg_r)

    sample("Jump", 0.95, 22, jump_fn)
    return anims


def write_glb(part_tris_map, anims, path):
    blob = bytearray()
    views, accessors, materials, meshes = [], [], [], []

    def add_view(data):
        while len(blob) % 4:
            blob.append(0)
        v = {"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)}
        views.append(v)
        blob.extend(data)
        return len(views) - 1

    def add_acc(fmt, values, typ, minmax=False):
        raw = b"".join(struct.pack(fmt, *v) if isinstance(v, tuple) else struct.pack(fmt, v) for v in values)
        a = {"bufferView": add_view(raw), "componentType": 5126, "count": len(values), "type": typ}
        if minmax:
            dims = len(values[0]) if isinstance(values[0], tuple) else 1
            if dims == 1:
                a["min"], a["max"] = [min(values)], [max(values)]
            else:
                a["min"] = [min(v[i] for v in values) for i in range(dims)]
                a["max"] = [max(v[i] for v in values) for i in range(dims)]
        accessors.append(a)
        return len(accessors) - 1

    mat_cache = {}

    def get_mat(col):
        if col not in mat_cache:
            rough = 0.28 if col in (C_FRAME, C_EYE_WHITE, C_EYE_BLUE, C_EYE_PUPIL) else 0.78
            materials.append({
                "name": "sami_mat_%d" % len(materials),
                "pbrMetallicRoughness": {
                    "baseColorFactor": [col[0] ** 2.2, col[1] ** 2.2, col[2] ** 2.2, 1.0],
                    "metallicFactor": 0.04 if col == C_FRAME else 0.0,
                    "roughnessFactor": rough,
                },
            })
            mat_cache[col] = len(materials) - 1
        return mat_cache[col]

    def add_mesh(tris_by_col, name):
        prims = []
        for col, tris in tris_by_col.items():
            pos, nrm = [], []
            for a, b, c, n in tris:
                pos.extend((a, b, c))
                nrm.extend((n, n, n))
            prims.append({
                "attributes": {
                    "POSITION": add_acc("<3f", pos, "VEC3", minmax=True),
                    "NORMAL": add_acc("<3f", nrm, "VEC3"),
                },
                "material": get_mat(col),
            })
        meshes.append({"name": name, "primitives": prims})
        return len(meshes) - 1

    m_body = add_mesh(part_tris_map["Body"], "BodyMesh")
    m_head = add_mesh(part_tris_map["Head"], "HeadMesh")
    m_arm_l = add_mesh(part_tris_map["ArmL"], "ArmLMesh")
    m_arm_r = add_mesh(part_tris_map["ArmR"], "ArmRMesh")
    m_leg_l = add_mesh(part_tris_map["LegL"], "LegLMesh")
    m_leg_r = add_mesh(part_tris_map["LegR"], "LegRMesh")

    nodes = [
        {"name": "Sami", "children": [1, 5, 6]},
        {"name": "Body", "mesh": m_body, "translation": [0.0, BODY_BASE_Y, 0.0], "children": [2, 3, 4]},
        {"name": "Head", "mesh": m_head, "translation": [0.0, 9.5 * VOX, 0.0]},
        {"name": "ArmL", "mesh": m_arm_l, "translation": [7.8 * VOX, 7.8 * VOX, 0.0]},
        {"name": "ArmR", "mesh": m_arm_r, "translation": [-7.8 * VOX, 7.8 * VOX, 0.0]},
        {"name": "LegL", "mesh": m_leg_l, "translation": [2.6 * VOX, BODY_BASE_Y, 0.0]},
        {"name": "LegR", "mesh": m_leg_r, "translation": [-2.6 * VOX, BODY_BASE_Y, 0.0]},
    ]

    gltf_anims = []
    for aname, (_dur, keys) in anims.items():
        t_acc = add_acc("<f", [k[0] for k in keys], "SCALAR", minmax=True)
        samplers, channels = [], []

        def chan(node_idx, prop, vals, typ, fmt):
            samplers.append({"input": t_acc, "output": add_acc(fmt, vals, typ), "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": node_idx, "path": prop}})

        chan(1, "translation", [k[1] for k in keys], "VEC3", "<3f")
        chan(1, "rotation", [k[2] for k in keys], "VEC4", "<4f")
        chan(2, "rotation", [k[3] for k in keys], "VEC4", "<4f")
        chan(3, "rotation", [k[4] for k in keys], "VEC4", "<4f")
        chan(4, "rotation", [k[5] for k in keys], "VEC4", "<4f")
        chan(5, "translation", [k[6] for k in keys], "VEC3", "<3f")
        chan(5, "rotation", [k[7] for k in keys], "VEC4", "<4f")
        chan(6, "translation", [k[8] for k in keys], "VEC3", "<3f")
        chan(6, "rotation", [k[9] for k in keys], "VEC4", "<4f")
        gltf_anims.append({"name": aname, "samplers": samplers, "channels": channels})

    while len(blob) % 4:
        blob.append(0)
    gltf = {
        "asset": {"version": "2.0", "generator": "unipet make_sami.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
        "animations": gltf_anims,
    }
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(blob), 0x004E4942) + bytes(blob))


def main():
    parts = {
        "Body": build_torso(),
        "Head": build_head(),
        "ArmL": build_arm(True),
        "ArmR": build_arm(False),
        "LegL": build_leg(),
        "LegR": build_leg(),
    }
    total_tris = sum(len(v) for p in parts.values() for v in p.values())
    write_glb(parts, build_animations(), OUT)
    print("OK sami: %d ucgen -> %s" % (total_tris, OUT))


if __name__ == "__main__":
    main()
