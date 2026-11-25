"""Ring/41AT duraklarını gerçek İETT duraklarıyla eşler (art/reference/osm/iett_stops.json).

1. Döngünün Camii → (B Kapısı, İİBF) → 41AT son durağı arasını gerçek 41AT güzergâhına çevirir (OSM araç yolları).
2. Her durak için döngü üzerindeki en yakın noktaya bir waypoint koyar; kabin sürüş yönünün sağına (5.2 m) gelir.

Kullanım: python tools/transit/real_stops.py   (game/data/transit_routes.json yerinde güncellenir)
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from road_graph import load_graph, nearest_node, shortest  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROUTES = os.path.join(ROOT, "game", "data", "transit_routes.json")
ZONE = os.path.join(ROOT, "game", "data", "zones", "davutpasa_campus.json")
STOPS = os.path.join(ROOT, "art", "reference", "osm", "iett_stops.json")
SHELTER_OFFSET_M = 5.2
MAX_SEG_M = 20.0


def cumlen(W):
    c = [0.0]
    for i in range(len(W)):
        c.append(c[-1] + math.dist(W[i], W[(i + 1) % len(W)]))
    return c


def project(W, p):
    best = None
    m = len(W)
    for i in range(m):
        a, b = W[i], W[(i + 1) % m]
        ab = (b[0] - a[0], b[1] - a[1])
        l2 = ab[0] ** 2 + ab[1] ** 2 or 1e-9
        t = max(0.0, min(1.0, ((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / l2))
        q = (a[0] + ab[0] * t, a[1] + ab[1] * t)
        d = math.dist(p, q)
        if best is None or d < best[0]:
            best = (d, i, t, q)
    return best


def densify(pts):
    out = [pts[0]]
    for a, b in zip(pts, pts[1:]):
        n = max(1, math.ceil(math.dist(a, b) / MAX_SEG_M))
        for k in range(1, n + 1):
            out.append((a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n))
    return out


def find_wp(W, p, lo, hi):
    return min(range(lo, hi), key=lambda i: math.dist(W[i], p))


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    routes = json.load(open(ROUTES, encoding="utf8"))
    cfg = json.load(open(STOPS, encoding="utf8"))
    W = [tuple(p) for p in routes["waypoints"]]
    st = {s["id"]: s for s in cfg["stops"]}

    # 1) Camii → B Kapısı → İİBF → son durak: gerçek 41AT yolu
    camii = (st["camii"]["x"], st["camii"]["z"])
    son = (st["ytu_son_durak"]["x"], st["ytu_son_durak"]["z"])
    i_a = project(W, camii)[1] + 1
    # son durağı geçen ilk yol düğümü (yol grafiğinde 1 m'den yakın) — oradan döngü aynen devam eder
    nodes, adj = load_graph(ZONE)
    i_b = project(W, son)[1] + 1
    while math.dist(nodes[nearest_node(nodes, adj, W[i_b])], W[i_b]) > 1.0:
        i_b += 1
    via = [W[i_a]] + [tuple(p) for p in cfg["reroute_via"]] + [W[i_b]]
    seg_nodes = []
    for a, b in zip(via, via[1:]):
        pth = shortest(nodes, adj, nearest_node(nodes, adj, a), nearest_node(nodes, adj, b))
        if not pth:
            raise SystemExit("yol bulunamadı: %s → %s" % (a, b))
        for n in pth:
            if not seg_nodes or seg_nodes[-1] != nodes[n]:
                seg_nodes.append(nodes[n])
    seg = densify([W[i_a]] + seg_nodes + [W[i_b]])
    # aynı noktadan geri dönüşleri (U) temizle
    clean = [seg[0]]
    for p in seg[1:]:
        if math.dist(p, clean[-1]) > 0.5:
            clean.append(p)
    W = W[: i_a] + clean[:-1] + W[i_b:]

    # 2) duraklar: döngü üzerinde sıralı izdüşüm, waypoint ekle
    out_stops = []
    for s in cfg["stops"]:
        p = (s["x"], s["z"])
        d, i, t, q = project(W, p)
        if math.dist(q, W[i]) < 1.0:
            wi = i
        elif math.dist(q, W[(i + 1) % len(W)]) < 1.0:
            wi = (i + 1) % len(W)
        else:
            W.insert(i + 1, q)
            wi = i + 1
            for o in out_stops:  # önceki indeksler kaydı
                if o["waypoint_index"] > i:
                    o["waypoint_index"] += 1
        out_stops.append({"id": s["id"], "name": s["name"], "desc": s["desc"], "iett": s["iett"],
                          "waypoint_index": wi, "_platform_d": round(d, 1)})
    # A Kapısı döngü başı olmalı (spawn ve tarife buna göre)
    a0 = out_stops[0]["waypoint_index"]
    W = W[a0:] + W[:a0]
    m = len(W)
    for o in out_stops:
        o["waypoint_index"] = (o["waypoint_index"] - a0) % m
    c = cumlen(W)
    order = [o["waypoint_index"] for o in out_stops]
    if order != sorted(order):
        raise SystemExit("durak sırası döngü yönüyle uyuşmuyor: %s" % order)
    for o in out_stops:
        i = o["waypoint_index"]
        a, b = W[i], W[(i + 1) % m]
        tyaw = math.atan2(b[0] - a[0], b[1] - a[1])
        yaw = tyaw + math.pi / 2
        off = (math.sin(yaw + math.pi) * SHELTER_OFFSET_M, math.cos(yaw + math.pi) * SHELTER_OFFSET_M)
        o["road_pos"] = [round(a[0], 2), round(a[1], 2)]
        o["shelter_pos"] = [round(a[0] + off[0], 2), round(a[1] + off[1], 2)]
        o["shelter_yaw"] = round(math.atan2(math.sin(yaw), math.cos(yaw)), 4)
        print("%-42s s=%7.1f platform→yol %.1f m" % (o["name"], c[i], o.pop("_platform_d")))
    routes["waypoints"] = [[round(p[0], 2), round(p[1], 2)] for p in W]
    routes["stops"] = out_stops
    routes["loop_length_m"] = round(c[-1], 1)
    routes["stops_source"] = "İETT (OpenStreetMap) — art/reference/osm/iett_stops.json"
    with open(ROUTES, "w", encoding="utf8", newline="\n") as f:
        json.dump(routes, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("döngü %.1f m, %d waypoint, %d durak" % (c[-1], m, len(out_stops)))


if __name__ == "__main__":
    main()
