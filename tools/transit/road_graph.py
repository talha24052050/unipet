"""Kampüs araç yolu grafiği (OSM paths: residential / residential_oneway / service) ve en kısa yol."""
import heapq
import json
import math

CAR_KINDS = {"residential", "residential_oneway", "service"}
SNAP_M = 1.5


def load_graph(zone_json: str):
    d = json.load(open(zone_json, encoding="utf8"))
    nodes: list[tuple[float, float]] = []
    index: dict[tuple[int, int], int] = {}

    def nid(p) -> int:
        key = (round(p[0] / SNAP_M), round(p[1] / SNAP_M))
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                k = (key[0] + dx, key[1] + dz)
                if k in index and math.dist(nodes[index[k]], p) <= SNAP_M:
                    return index[k]
        nodes.append((float(p[0]), float(p[1])))
        index[key] = len(nodes) - 1
        return len(nodes) - 1

    adj: dict[int, list[tuple[int, float]]] = {}
    for path in d["paths"]:
        if path["kind"] not in CAR_KINDS:
            continue
        pts = path["points"]
        ids = [nid(p) for p in pts]
        for a, b in zip(ids, ids[1:]):
            if a == b:
                continue
            w = math.dist(nodes[a], nodes[b])
            adj.setdefault(a, []).append((b, w))
            adj.setdefault(b, []).append((a, w))  # tek yön kuralını yok say (kampüs içi servis)
    return nodes, adj


def nearest_node(nodes, adj, p) -> int:
    return min(adj.keys(), key=lambda i: math.dist(nodes[i], p))


def shortest(nodes, adj, a: int, b: int) -> list[int]:
    dist = {a: 0.0}
    prev: dict[int, int] = {}
    pq = [(0.0, a)]
    while pq:
        dd, u = heapq.heappop(pq)
        if u == b:
            break
        if dd > dist.get(u, 1e18):
            continue
        for v, w in adj.get(u, []):
            nd = dd + w
            if nd < dist.get(v, 1e18):
                dist[v] = nd
                prev[v] = u
                heapq.heappush(pq, (nd, v))
    if b not in dist:
        return []
    out = [b]
    while out[-1] != a:
        out.append(prev[out[-1]])
    return out[::-1]
