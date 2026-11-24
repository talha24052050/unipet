"""Kampüs yeşil dokusu (Street View / drone referansı): ağaç konumları, çiçek tarhları, stadyum koşu pisti.

Kullanım:  python tools/assets/make_greenery.py
Girdi : game/data/zones/kampus_greybox.json, game/data/zones/kampus_props.json
Çıktı : game/data/zones/kampus_greenery.json  (oyun sadece okur; navmesh verisini değiştirmez)

Bölgeler:
  - Ortabahçe (Kışla avlusu): sık, fıstık çamı + çınar (drone: avlu ağaçla dolu)
  - Parklar (ör. Yıldızbahçe): yol kenarlarında sık, açık çimlerde seyrek (drone: kıvrımlı yollar boyunca ağaç sıraları)
  - Binalar arası çimler: seyrek
Kurallar: yollara/binalara/mevcut ağaçlara mesafe, sabit tohum (her üretimde aynı sonuç).
"""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_landmarks as L  # noqa: E402

ROOT = L.ROOT
KISLA = "Yıldız Teknik Üniversitesi Davutpaşa Kışlası"
ORTABAHCE = "Ortabahçe"
SEED = 24052050
GRID = 25.0

REGIONS = {
    #             aralık  yol-yakın kabul  uzak kabul  yol-yakın bandı (m)   türler (ağırlık)
    "courtyard": (9.0, 1.0, 1.0, (3.2, 99.0), {"tree_stonepine": 55, "tree_plane": 45}),
    # Sadece tek yüzeyli (script) ağaçlar: dış paket ağaçları 2-3 yüzey = 2-3 kat çizim çağrısı (telefon)
    "wood":      (9.5, 0.90, 0.60, (3.5, 18.0), {"tree_stonepine": 50, "tree_plane": 32, "tree_cypress": 18}),
    "park":      (11.0, 0.85, 0.3, (3.5, 13.0), {"tree_plane": 55, "tree_stonepine": 30, "tree_cypress": 15}),
    "grass":     (14.0, 0.55, 0.12, (3.5, 11.0), {"tree_plane": 60, "tree_cypress": 20, "tree_stonepine": 20}),
}
ROAD_KINDS = {"residential", "residential_oneway", "service", "parking_aisle"}
AVENUE_ROAD_KINDS = {"residential", "residential_oneway", "service"}
CLEAR_BY_TAG = {
    "road_main": 5.4,   # çift yönlü ana bulvar (6.2 m)
    "road": 4.4,        # tek yönlü bulvar / servis yolu (4.4-4.6 m)
    "aisle": 3.5,       # otopark geçiş yolu (3.6 m)
    "cycle": 2.4,       # bisiklet yolu (1.6 m)
    "path": 3.0,        # yaya yolu (1.5-4.0 m)
}
BUSH_CLEAR_BY_TAG = {
    "road_main": 4.8,
    "road": 3.9,
    "aisle": 3.1,
    "cycle": 2.1,
    "path": 2.2,
}
PATH_CLEAR = 3.0
ROAD_CLEAR = 4.4
BUILDING_CLEAR = 4.0
COURTYARD_WALL_CLEAR = 10.0
EXISTING_TREE_CLEAR = 5.0
BED_RADIUS = 3.2
# Kampüs içi araç yolları iki yanı sık ağaçlı (Street View 2025, Google aracı çekimi)
ROADSIDE_STEP = 11.5        # yol boyunca aralık
ROADSIDE_OFFSET = 4.8       # tek yön / servis yolu ekseninden
ROADSIDE_OFFSET_MAIN = 5.6  # çift yönlü ana yol (6.2 m) ekseninden
ROADSIDE_JITTER = 0.7
ROADSIDE_SPACING = 8.5      # diğer ağaçlara en az
ROADSIDE_SPECIES = {"tree_plane": 60, "tree_stonepine": 25, "tree_cypress": 15}
GROVE_SPECIES = {"tree_stonepine": 48, "tree_plane": 34, "tree_cypress": 18}
BUSH_SPECIES = {"bush_common": 68, "bush_berries": 32}
TRACK_WIDTH = 7.5

# İkonik meydanlar ve giriş önleri: ağaç/çalı buralara girmesin (x, z, yarıçap m)
PLAZA_NO_GO = [
    (0.0, 0.0, 8.0),          # başlangıç noktası
    (-2.1, 5.3, 8.0),         # Ortabahçe anıt meydanı
    (-92.0, -68.0, 24.0),     # Yemekhane önü meydanı
    (-124.0, -58.0, 17.0),    # Yıldız Store amfi & A101
    (38.0, -234.0, 22.0),     # EEF önü + totem + kafe
    (548.0, 247.0, 15.0),     # Kongre Merkezi protokol girişi
    (434.0, 268.0, 12.0),     # Otağ-ı Hümayun havuzlu avlu
    (376.0, 471.0, 15.0),     # İlhan Varank Kütüphanesi önü
    (-90.0, -148.0, 15.0),    # Merkez Kütüphanesi önü
    (150.0, -168.0, 14.0),    # Fen-Edebiyat önü
    (-234.0, -260.0, 14.0),   # Eğitim Fakültesi önü
    (169.0, 463.0, 14.0),     # Yabancı Diller önü
    (210.0, -95.0, 12.0),     # Ring Durağı
    (-80.0, 304.0, 14.0),     # İnşaat Fakültesi önü
    (235.0, -239.0, 14.0),    # Kimya-Metalurji önü
    (-17.0, 544.0, 14.0),     # Merkez Laboratuvarı önü
    (-164.0, 526.0, 15.0),    # Yıldız Teknopark önü
    (-275.0, -240.0, 15.0),   # Spor Kompleksi önü
    (-4.0, -65.0, 13.0),      # Büyük Ev kafe terası
]

# Davutpaşa koruluk / ağaçlık yamaç kümeleri (merkez x, z, yarıçap m, hedef yoğunluk aralığı m)
GROVE_ZONES = [
    (-205.0, 125.0, 62.0, 9.5),   # Stadyum kuzeydoğu yamacı
    (-355.0, 55.0, 58.0, 10.0),   # Stadyum batı sırtı
    (-215.0, -25.0, 48.0, 10.0),  # Stadyum - Kulüpler Vadisi arası tepe
    (-150.0, 85.0, 52.0, 9.5),    # Taşbina batı koruluğu
    (-135.0, 185.0, 55.0, 10.0),  # Sanat Tasarım - İnşaat arası ağaçlık
    (245.0, 290.0, 65.0, 10.0),   # Bilgelik Yolu - Otağ-ı Hümayun koruluğu
    (360.0, 215.0, 58.0, 10.0),   # Otağ-ı Hümayun batı yamacı
    (475.0, 190.0, 55.0, 10.5),   # Kongre Merkezi güney koruluğu
    (285.0, 395.0, 58.0, 10.5),   # Sancak Köşkü - Kütüphane arası ağaçlık
    (120.0, 195.0, 55.0, 10.5),   # Taşbina doğu sırtı
    (295.0, -85.0, 55.0, 10.5),   # Ring Durağı doğu koruluğu
    (-185.0, 365.0, 55.0, 10.5),  # İnşaat - Hidrodinamik arası tepe
]


class SegGrid:
    """Çizgi parçaları için ızgara: nokta → en yakın parça mesafesi hızlı."""

    def __init__(self, lines):
        self.cells = {}
        for line, tag in lines:
            for j in range(len(line) - 1):
                a, b = line[j], line[j + 1]
                x0, x1 = sorted((a[0], b[0]))
                z0, z1 = sorted((a[1], b[1]))
                for gx in range(int(math.floor(x0 / GRID)) - 1, int(math.floor(x1 / GRID)) + 2):
                    for gz in range(int(math.floor(z0 / GRID)) - 1, int(math.floor(z1 / GRID)) + 2):
                        self.cells.setdefault((gx, gz), []).append((a, b, tag))

    def nearest(self, p):
        """(mesafe, etiket) — 1 hücre komşuluğu (~25 m) içinde; yoksa (inf, None)."""
        best = (float("inf"), None)
        for a, b, tag in self.cells.get((int(math.floor(p[0] / GRID)), int(math.floor(p[1] / GRID))), ()):
            d = math.dist(p, L.seg_closest(p, a, b))
            if d < best[0]:
                best = (d, tag)
        return best


class PolyGrid:
    def __init__(self, polys):
        self.cells = {}
        self.polys = polys
        for i, poly in enumerate(polys):
            xs, zs = [q[0] for q in poly], [q[1] for q in poly]
            for gx in range(int(math.floor(min(xs) / GRID)), int(math.floor(max(xs) / GRID)) + 1):
                for gz in range(int(math.floor(min(zs) / GRID)), int(math.floor(max(zs) / GRID)) + 1):
                    self.cells.setdefault((gx, gz), []).append(i)

    def near(self, p, clear):
        """Nokta bir çokgenin içinde ya da 'clear' metreden yakın mı?"""
        for i in self.cells.get((int(math.floor(p[0] / GRID)), int(math.floor(p[1] / GRID))), ()):
            poly = self.polys[i]
            if L.inside(p, poly):
                return True
            n = len(poly)
            for k in range(n):
                if math.dist(p, L.seg_closest(p, poly[k], poly[(k + 1) % n])) < clear:
                    return True
        return False


class PointGrid:
    def __init__(self, cell):
        self.cell = cell
        self.cells = {}

    def add(self, p):
        self.cells.setdefault((int(p[0] // self.cell), int(p[1] // self.cell)), []).append(p)

    def any_within(self, p, r):
        cx, cz = int(p[0] // self.cell), int(p[1] // self.cell)
        for gx in (cx - 1, cx, cx + 1):
            for gz in (cz - 1, cz, cz + 1):
                for q in self.cells.get((gx, gz), ()):
                    if (q[0] - p[0]) ** 2 + (q[1] - p[1]) ** 2 < r * r:
                        return True
        return False


def convex_hull(pts):
    pts = sorted(set(pts))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def dist_to_poly(p, poly):
    n = len(poly)
    return min(math.dist(p, L.seg_closest(p, poly[k], poly[(k + 1) % n])) for k in range(n))


def pick(weights, rng):
    r = rng.uniform(0, sum(weights.values()))
    for k, w in weights.items():
        r -= w
        if r <= 0:
            return k
    return k


def min_area_rect(poly):
    """En küçük alanlı dönük dikdörtgen: (merkez, uzun eksen birim vektörü, yarı uzunluk, yarı genişlik)."""
    hull = convex_hull(poly)
    best = None
    for i in range(len(hull)):
        a, b = hull[i], hull[(i + 1) % len(hull)]
        L_ = math.dist(a, b) or 1.0
        u = ((b[0] - a[0]) / L_, (b[1] - a[1]) / L_)
        v = (-u[1], u[0])
        pu = [q[0] * u[0] + q[1] * u[1] for q in hull]
        pv = [q[0] * v[0] + q[1] * v[1] for q in hull]
        area = (max(pu) - min(pu)) * (max(pv) - min(pv))
        if best is None or area < best[0]:
            cu, cv = (max(pu) + min(pu)) / 2, (max(pv) + min(pv)) / 2
            best = (area, u, v, cu, cv, (max(pu) - min(pu)) / 2, (max(pv) - min(pv)) / 2)
    _, u, v, cu, cv, hu, hv = best
    if hv > hu:
        u, v, hu, hv = v, (-v[0], -v[1]), hv, hu
        cu, cv = cv, -cu
    c = (u[0] * cu + v[0] * cv, u[1] * cu + v[1] * cv)
    return c, u, hu, hv


def stadium_track(field, segs=20):
    """Gerçek pist gibi oval (iki düz + iki yarım daire); saha içte kalır. (iç, dış) aynı sayıda köşe."""
    c, u, hu, hv = min_area_rect(field)
    v = (-u[1], u[0])
    r_in = hv + 1.0
    straight = max(hu - math.sqrt(max(r_in * r_in - hv * hv, 0.0)), 0.0)  # saha köşeleri iç ovalde kalsın
    rings = []
    for r in (r_in, r_in + TRACK_WIDTH):
        pts = []
        for end, sign in ((straight, 1), (-straight, -1)):
            for k in range(segs + 1):
                a = -math.pi / 2 + math.pi * k / segs
                du, dv = end + sign * r * math.cos(a), sign * r * math.sin(a)
                pts.append((c[0] + u[0] * du + v[0] * dv, c[1] + u[1] * du + v[1] * dv))
        rings.append(pts)
    return rings[0], rings[1]


def main():
    grey = json.load(open(os.path.join(ROOT, "game/data/zones/kampus_greybox.json"), encoding="utf-8"))
    props = json.load(open(os.path.join(ROOT, "game/data/zones/kampus_props.json"), encoding="utf-8"))
    rng = random.Random(SEED)

    buildings = [L.clean([tuple(q) for q in b["points"]]) for b in grey["buildings"]]
    bgrid = PolyGrid([b for b in buildings if len(b) >= 3])
    kisla = L.clean([tuple(q) for q in next(b for b in grey["buildings"] if b.get("name") == KISLA)["points"]])
    hull = convex_hull(kisla)

    def in_courtyard(p, clear=COURTYARD_WALL_CLEAR):
        return L.inside(p, hull) and not L.inside(p, kisla) and dist_to_poly(p, kisla) > clear

    def tag_of(kind):
        if kind == "residential":
            return "road_main"
        if kind in ("residential_oneway", "service"):
            return "road"
        if kind == "parking_aisle":
            return "aisle"
        if kind == "cycleway":
            return "cycle"
        return "path"

    def path_clear_ok(p, table):
        # Komşu hücrelerdeki tüm yolları kontrol et (yakındaki geniş ana yol dar patikadan daha uzak mesafe ister)
        gx, gz = int(math.floor(p[0] / GRID)), int(math.floor(p[1] / GRID))
        for a, b, tag in sgrid.cells.get((gx, gz), ()):
            if math.dist(p, L.seg_closest(p, a, b)) < table.get(tag, PATH_CLEAR):
                return False
        return True

    lines = [([tuple(q) for q in p["points"]], tag_of(p.get("kind", "footway"))) for p in grey["paths"]]
    sgrid = SegGrid(lines)
    placed = PointGrid(15.0)  # en büyük aralıktan (14 m) büyük olmalı: komşu hücre taraması yeterli
    for it in props["props"]:
        if str(it.get("type", "")).startswith("tree_"):
            placed.add(tuple(it["pos"]))

    # Saha / oyun alanı / havuz / OTOPARK çokgenleri (hiçbir ağaç veya çalı buralara düşmesin!)
    no_go = []
    for a in grey["areas"]:
        if a.get("kind") in ("pitch", "playground", "parking") or "havuz" in str(a.get("name", "")).lower():
            q = L.clean([tuple(v) for v in a["points"]])
            if len(q) >= 3:
                no_go.append(L.offset(q, 1.5))

    areas = []
    for a in grey["areas"]:
        kind = a.get("kind")
        poly = L.clean([tuple(q) for q in a["points"]])
        if len(poly) < 3:
            continue
        if "havuz" in str(a.get("name", "")).lower() or kind == "parking":
            continue  # su veya otopark
        if kind == "wood" and a.get("name") != ORTABAHCE:
            areas.append(("wood", poly))
        elif kind in ("park", "garden") and a.get("name") != ORTABAHCE:
            areas.append(("park", poly))
        elif kind == "grass":
            areas.append(("grass", poly))
    xs, zs = [q[0] for q in hull], [q[1] for q in hull]
    areas.insert(0, ("courtyard", [(min(xs), min(zs)), (max(xs), min(zs)), (max(xs), max(zs)), (min(xs), max(zs))]))

    trees = []
    stats = {}
    for region, poly in areas:
        spacing, near_p, far_p, band, species = REGIONS[region]
        x0, x1 = min(q[0] for q in poly), max(q[0] for q in poly)
        z0, z1 = min(q[1] for q in poly), max(q[1] for q in poly)
        area = abs(L.signed_area(poly)) if region != "courtyard" else (x1 - x0) * (z1 - z0)
        attempts = int(area / (spacing * spacing) * 4) + 4
        for _ in range(attempts):
            p = (rng.uniform(x0, x1), rng.uniform(z0, z1))
            if region == "courtyard":
                if not in_courtyard(p):
                    continue
            elif not L.inside(p, poly) or in_courtyard(p, 0.0):
                continue
            if not path_clear_ok(p, CLEAR_BY_TAG):
                continue
            d, _ = sgrid.nearest(p)
            accept = near_p if band[0] <= d <= band[1] else far_p
            if rng.random() > accept:
                continue
            if placed.any_within(p, spacing) or placed.any_within(p, EXISTING_TREE_CLEAR):
                continue
            if bgrid.near(p, BUILDING_CLEAR) or any(L.inside(p, z) for z in no_go):
                continue
            kind = pick(species, rng)
            placed.add(p)
            trees.append([kind, round(p[0], 2), round(p[1], 2), round(rng.uniform(0, math.tau), 3), round(rng.uniform(0.85, 1.2), 3)])
            stats[region] = stats.get(region, 0) + 1

    # Kampüs kapıları (beton portal vb.) ve ikonik meydanlar çevresi açık kalsın
    GATE_CLEAR = 16.0
    gates = json.load(open(os.path.join(ROOT, "tools/assets/landmarks.json"), encoding="utf-8")).get("gates", [])
    clear_circles = [(g["pos"][0], g["pos"][1], GATE_CLEAR) for g in gates] + list(PLAZA_NO_GO)
    for cx, cz, rad in clear_circles:
        no_go.append([(cx + rad * math.cos(k * math.tau / 12), cz + rad * math.sin(k * math.tau / 12)) for k in range(12)])
    n_before = len(trees)
    trees = [t for t in trees if not any(math.hypot(t[1] - cx, t[2] - cz) < rad for cx, cz, rad in clear_circles)]
    stats["meydan/kapı çevresinden çıkarılan"] = n_before - len(trees)

    # Araç yollarının (ana bulvar + servis) iki yanına ağaç sırası (otopark içi yollar hariç)
    road_lines = [([tuple(q) for q in p["points"]], p.get("kind", "service")) for p in grey["paths"] if p.get("kind") in AVENUE_ROAD_KINDS]
    n_road = 0
    for line, rkind in road_lines:
        base_off = ROADSIDE_OFFSET_MAIN if rkind == "residential" else ROADSIDE_OFFSET
        acc = ROADSIDE_STEP / 2
        for j in range(len(line) - 1):
            a, c = line[j], line[j + 1]
            seg = math.dist(a, c)
            if seg < 1e-6:
                continue
            u = ((c[0] - a[0]) / seg, (c[1] - a[1]) / seg)
            nrm = (-u[1], u[0])
            t = acc
            while t < seg:
                for side in (-1, 1):
                    off = base_off + rng.uniform(-ROADSIDE_JITTER, ROADSIDE_JITTER)
                    p = (a[0] + u[0] * t + nrm[0] * side * off, a[1] + u[1] * t + nrm[1] * side * off)
                    if not path_clear_ok(p, CLEAR_BY_TAG):
                        continue  # karşı şerit / refüj / bisiklet yolu / kavşak
                    if placed.any_within(p, ROADSIDE_SPACING) or bgrid.near(p, BUILDING_CLEAR):
                        continue
                    if any(L.inside(p, z) for z in no_go):
                        continue
                    placed.add(p)
                    trees.append([pick(ROADSIDE_SPECIES, rng), round(p[0], 2), round(p[1], 2),
                                  round(rng.uniform(0, math.tau), 3), round(rng.uniform(0.9, 1.25), 3)])
                    n_road += 1
                t += ROADSIDE_STEP
            acc = t - seg
    stats["yol kenarı"] = n_road

    # Ortabahçe yol kavşakları → yuvarlak çiçek tarhı (≥3 yol ucu bir arada)
    ends = [line[i] for line, tag in lines if tag == "path" for i in range(len(line)) if in_courtyard(line[i], 15.0)]
    beds = []
    for v in ends:
        if sum(1 for w in ends if math.dist(v, w) < 1.5) >= 3 and all(math.dist(v, c) > BED_RADIUS * 3 for c in beds):
            beds.append(v)

    # Ortabahçe büfesi (Street View 2017: kavşaktaki çiçek tarhının arkasında, mavi çatılı küçük yapı + otomatlar)
    KIOSK_NEAR = (-23.0, 47.0)   # panorama konumundan kestirim (kampüs XZ)
    kiosks = []
    if beds:
        bed = min(beds, key=lambda b: math.dist(b, KIOSK_NEAR))
        best = None
        for k in range(24):
            ang = k * math.tau / 24
            for r in (7.0, 9.0, 11.0):
                q = (bed[0] + r * math.cos(ang), bed[1] + r * math.sin(ang))
                d, _ = sgrid.nearest(q)
                if d < 4.5 or bgrid.near(q, 4.0) or placed.any_within(q, 4.0):
                    continue
                if best is None or d > best[0]:
                    best = (d, q)
        if best:
            q = best[1]
            yaw = math.atan2(bed[0] - q[0], bed[1] - q[1])  # önü tarha baksın
            kiosks.append([round(q[0], 2), round(q[1], 2), round(yaw, 3)])

    # Stadyum (en büyük 'pitch'): çevresine kırmızı koşu pisti
    pitches = sorted((L.clean([tuple(q) for q in a["points"]]) for a in grey["areas"] if a.get("kind") == "pitch"),
                     key=lambda p: -abs(L.signed_area(p)) if len(p) > 2 else 0)
    tracks = []
    track_ring = None
    if pitches and abs(L.signed_area(pitches[0])) > 5000:
        inner, outer = stadium_track(pitches[0])
        tracks.append({"inner": [[round(x, 2), round(z, 2)] for x, z in inner],
                       "outer": [[round(x, 2), round(z, 2)] for x, z in outer]})
        track_ring = L.offset([tuple(q) for q in tracks[0]["outer"]], 4.5)
        no_go.append(track_ring)

    # Koruluk / ağaçlık yamaç kümeleri (Stadyum sırtları, Taşbina dışı, Bilgelik Yolu, Otağ-ı Hümayun)
    n_grove = 0
    for gx, gz, rad, sp in GROVE_ZONES:
        attempts = int((math.pi * rad * rad) / (sp * sp) * 1.8)
        for _ in range(attempts):
            ang = rng.uniform(0.0, math.tau)
            rr = rad * math.sqrt(rng.random())
            p = (gx + rr * math.cos(ang), gz + rr * math.sin(ang))
            if in_courtyard(p, 0.0):
                continue
            if not path_clear_ok(p, CLEAR_BY_TAG):
                continue
            if placed.any_within(p, sp) or bgrid.near(p, BUILDING_CLEAR + 0.5):
                continue
            if any(L.inside(p, z) for z in no_go):
                continue
            placed.add(p)
            trees.append([pick(GROVE_SPECIES, rng), round(p[0], 2), round(p[1], 2),
                          round(rng.uniform(0, math.tau), 3), round(rng.uniform(0.92, 1.32), 3)])
            n_grove += 1
    stats["koruluk"] = n_grove

    # Pist/saha üstüne ağaç düşmesin (çim alanları pistle örtüşebiliyor)
    if track_ring is not None:
        n0 = len(trees)
        trees = [t for t in trees if not L.inside((t[1], t[2]), track_ring)]
        print("pist üstünden çıkarılan ağaç:", n0 - len(trees))

    # Çalı alt-katmanı: ağaç dipleri, Ortabahçe çim kenarları ve koruluk içlerinde dekoratif kümeler
    bush_grid = PointGrid(8.0)
    bushes = []
    for idx, t in enumerate(trees):
        if idx % 4 != 0:
            continue  # her ~4 ağaçtan 1'inin dibinde 1-2 çalı kümesi (doğal orman altı)
        tx, tz = t[1], t[2]
        n_clump = 2 if rng.random() < 0.35 else 1
        for _ in range(n_clump):
            ang = rng.uniform(0.0, math.tau)
            dist = rng.uniform(1.6, 3.4)
            bp = (tx + math.cos(ang) * dist, tz + math.sin(ang) * dist)
            if not path_clear_ok(bp, BUSH_CLEAR_BY_TAG):
                continue
            if bush_grid.any_within(bp, 3.2) or bgrid.near(bp, 2.5):
                continue
            if any(L.inside(bp, z) for z in no_go):
                continue
            bush_grid.add(bp)
            bushes.append([pick(BUSH_SPECIES, rng), round(bp[0], 2), round(bp[1], 2),
                           round(rng.uniform(0, math.tau), 3), round(rng.uniform(0.75, 1.30), 3)])

    out = {"_note": "tools/assets/make_greenery.py üretir; elle düzenleme. trees/bushes: [tür, x, z, yaw, ölçek]",
           "trees": trees, "bushes": bushes, "beds": [[round(x, 2), round(z, 2)] for x, z in beds],
           "tracks": tracks, "kiosks": kiosks}
    with open(os.path.join(ROOT, "game/data/zones/kampus_greenery.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
        f.write("\n")
    print("ağaç:", len(trees), stats, "çalı:", len(bushes), "tarh:", len(beds), "pist:", len(tracks), "büfe:", kiosks)


if __name__ == "__main__":
    main()
